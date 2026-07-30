class_name BattleSession
extends RefCounted

signal events_flushed(events: Array[Dictionary])

const AiRulesScript = preload("res://src/core/ai_rules.gd")
const BattleCommandScript = preload("res://src/tactics/battle_command.gd")
const BattleEventScript = preload("res://src/events/battle_event.gd")
const CombatRulesScript = preload("res://src/core/combat_rules.gd")
const GridPointScript = preload("res://src/core/grid_point.gd")
const GridRulesScript = preload("res://src/core/grid_rules.gd")
const ObjectiveRulesScript = preload("res://src/core/objective_rules.gd")
const TurnStateScript = preload("res://src/core/turn_state.gd")
const UnitCatalogScript = preload("res://src/content/unit_catalog.gd")
const UnitStateScript = preload("res://src/core/unit_state.gd")

var chapter: Variant
var units: Array = []
var turn_state: Variant
var selected_unit_id: StringName = &""
var battle_status: StringName = &"ongoing"
var event_queue: Array[Dictionary] = []

var _base_seed: int = 1
var _combat_index: int = 0
var _board: Dictionary = {}


func _init(initial_chapter: Variant = null, initial_seed: int = 1) -> void:
	_base_seed = initial_seed
	chapter = _validated_chapter_copy(initial_chapter)
	units = _build_units(chapter)
	turn_state = TurnStateScript.new(units)
	_board = _build_board(chapter)
	battle_status = _evaluate_objective()


func select_unit(id: StringName) -> Dictionary:
	return _execute(BattleCommandScript.select_unit(id))


func move_selected(destination: Vector2i) -> Dictionary:
	return _execute(BattleCommandScript.move_selected(destination))


func forecast_attack(target_id: StringName) -> Dictionary:
	return _execute(BattleCommandScript.forecast_attack(target_id))


func confirm_attack(target_id: StringName) -> Dictionary:
	return _execute(BattleCommandScript.confirm_attack(target_id))


func end_player_phase() -> Dictionary:
	return _execute(BattleCommandScript.end_player_phase())


func advance_enemy_phase() -> Dictionary:
	return _execute(BattleCommandScript.advance_enemy_phase())


func _execute(command: Variant) -> Dictionary:
	match command.type:
		&"select_unit":
			return _select_unit(command.unit_id)
		&"move_selected":
			return _move_selected(command.destination)
		&"forecast_attack":
			return _forecast_attack(command.target_id)
		&"confirm_attack":
			return _confirm_attack(command.target_id)
		&"end_player_phase":
			return _end_player_phase()
		&"advance_enemy_phase":
			return _advance_enemy_phase()
	return _reject(&"invalid_target")


func _select_unit(id: StringName) -> Dictionary:
	if turn_state.phase != &"player":
		return _reject(&"wrong_phase")
	var unit: Variant = _find_unit(id)
	if unit == null or unit.current_hp <= 0:
		return _reject(&"invalid_target")
	if unit.definition.team != &"player":
		return _reject(&"not_friendly")
	if unit.acted:
		return _reject(&"unit_acted")
	if selected_unit_id == id:
		return _accept([])

	var previous_id := selected_unit_id
	selected_unit_id = id
	return _accept([BattleEventScript.state_changed(
		&"unit_selected",
		id,
		&"",
		{"previous_unit_id": previous_id},
	)])


func _move_selected(destination: Vector2i) -> Dictionary:
	var selected_result := _selected_player_unit()
	if not selected_result["ok"]:
		return selected_result
	var unit: Variant = selected_result["unit"]
	if _living_unit_at(destination, unit) != null:
		return _reject(&"occupied")

	var reachable: Array = GridRulesScript.reachable(
		unit.grid_position,
		maxi(0, unit.definition.move),
		int(_board.get("width", 0)),
		int(_board.get("height", 0)),
		_movement_blocked(unit),
	)
	if not _contains_position(reachable, destination):
		return _reject(&"out_of_range")

	var origin := Vector2i(unit.grid_position.x, unit.grid_position.y)
	if origin == destination:
		return _accept([])
	unit.grid_position.x = destination.x
	unit.grid_position.y = destination.y
	return _accept([BattleEventScript.state_changed(
		&"unit_moved",
		unit.instance_id,
		&"",
		{"from": origin, "to": destination},
	)])


func _forecast_attack(target_id: StringName) -> Dictionary:
	var validation := _attack_validation(target_id)
	if not validation["ok"]:
		return validation
	return _accept([], {"forecast": validation["forecast"]})


func _confirm_attack(target_id: StringName) -> Dictionary:
	var validation := _attack_validation(target_id)
	if not validation["ok"]:
		return validation
	var attacker: Variant = validation["attacker"]
	var target: Variant = validation["target"]
	var events: Array[Dictionary] = CombatRulesScript.resolve(attacker, target, _next_combat_seed())
	attacker.acted = true
	events.append(BattleEventScript.state_changed(
		&"unit_acted",
		attacker.instance_id,
		target.instance_id,
		{"action": &"attack"},
	))
	_append_objective_event(events)
	return _accept(events)


func _end_player_phase() -> Dictionary:
	if turn_state.phase != &"player":
		return _reject(&"wrong_phase")
	var enemy_acted_before := _acted_ids(&"enemy")
	var round_before: int = turn_state.round
	turn_state.end_player_phase()
	var events: Array[Dictionary] = _ready_events(enemy_acted_before)
	events.append(BattleEventScript.state_changed(
		&"phase_changed",
		&"",
		&"",
		{
			"from": &"player",
			"to": &"enemy",
			"from_round": round_before,
			"round": turn_state.round,
		},
	))
	return _accept(events)


func _advance_enemy_phase() -> Dictionary:
	if turn_state.phase != &"enemy":
		return _reject(&"wrong_phase")
	var events: Array[Dictionary] = []
	for enemy: Variant in units:
		if not _is_living_team_unit(enemy, &"enemy") or enemy.acted:
			continue
		var action: Dictionary = AiRulesScript.choose_action(enemy, units, _board)
		var action_type := StringName(action.get("type", &"wait"))
		var target_id := StringName(action.get("target_id", &""))
		if action_type == &"attack":
			var destination: Vector2i = action.get(
				"destination",
				Vector2i(enemy.grid_position.x, enemy.grid_position.y),
			)
			_append_enemy_move(events, enemy, destination)
			var target: Variant = _find_unit(target_id)
			if _is_living_opponent(enemy, target):
				var forecast: Variant = CombatRulesScript.forecast(enemy, target)
				if forecast.legal:
					events.append_array(CombatRulesScript.resolve(
						enemy,
						target,
						_next_combat_seed(),
					))
		enemy.acted = true
		events.append(BattleEventScript.state_changed(
			&"unit_acted",
			enemy.instance_id,
			target_id,
			{"action": action_type},
		))
		_append_objective_event(events)
		if battle_status != &"ongoing":
			break

	var player_acted_before := _acted_ids(&"player")
	var round_before: int = turn_state.round
	turn_state.finish_round()
	events.append_array(_ready_events(player_acted_before))
	events.append(BattleEventScript.state_changed(
		&"phase_changed",
		&"",
		&"",
		{
			"from": &"enemy",
			"to": &"player",
			"from_round": round_before,
			"round": turn_state.round,
		},
	))
	return _accept(events)


func _selected_player_unit() -> Dictionary:
	if turn_state.phase != &"player":
		return _reject(&"wrong_phase")
	if selected_unit_id == &"":
		return _reject(&"no_selection")
	var unit: Variant = _find_unit(selected_unit_id)
	if unit == null or unit.current_hp <= 0:
		return _reject(&"invalid_target")
	if unit.definition.team != &"player":
		return _reject(&"not_friendly")
	if unit.acted:
		return _reject(&"unit_acted")
	return {"ok": true, "unit": unit}


func _attack_validation(target_id: StringName) -> Dictionary:
	var selected_result := _selected_player_unit()
	if not selected_result["ok"]:
		return selected_result
	var attacker: Variant = selected_result["unit"]
	var target: Variant = _find_unit(target_id)
	if target == null or target.current_hp <= 0:
		return _reject(&"invalid_target")
	if target.definition.team == attacker.definition.team:
		return _reject(&"not_enemy")
	var forecast: Variant = CombatRulesScript.forecast(attacker, target)
	if not forecast.legal:
		return _reject(&"out_of_range")
	return {
		"ok": true,
		"attacker": attacker,
		"target": target,
		"forecast": forecast,
	}


func _accept(events: Array, extras: Dictionary = {}) -> Dictionary:
	for event_value: Variant in events:
		event_queue.append(event_value)
	var flushed: Array[Dictionary] = []
	for event: Dictionary in event_queue:
		flushed.append(event.duplicate(true))
	event_queue.clear()
	var result := {"ok": true, "events": flushed}
	for key: Variant in extras:
		result[key] = extras[key]
	if not flushed.is_empty():
		events_flushed.emit(flushed.duplicate(true))
	return result


func _reject(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason}


func _append_enemy_move(events: Array[Dictionary], enemy: Variant, destination: Vector2i) -> void:
	var origin := Vector2i(enemy.grid_position.x, enemy.grid_position.y)
	if origin == destination:
		return
	enemy.grid_position.x = destination.x
	enemy.grid_position.y = destination.y
	events.append(BattleEventScript.state_changed(
		&"unit_moved",
		enemy.instance_id,
		&"",
		{"from": origin, "to": destination},
	))


func _append_objective_event(events: Array[Dictionary]) -> void:
	var next_status := _evaluate_objective()
	if next_status == battle_status:
		return
	var previous_status := battle_status
	battle_status = next_status
	events.append(BattleEventScript.state_changed(
		&"battle_status_changed",
		&"",
		&"",
		{"from": previous_status, "to": battle_status},
	))


func _evaluate_objective() -> StringName:
	if chapter == null:
		return &"ongoing"
	return ObjectiveRulesScript.evaluate(units, {
		"victory": chapter.objectives,
		"defeat": chapter.failure_conditions,
	})


func _next_combat_seed() -> int:
	var result := _base_seed + _combat_index
	_combat_index += 1
	return result


func _acted_ids(team: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for unit: Variant in units:
		if _is_living_team_unit(unit, team) and unit.acted:
			result.append(unit.instance_id)
	return result


func _ready_events(previously_acted: Array[StringName]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in previously_acted:
		var unit: Variant = _find_unit(id)
		if unit == null or unit.acted:
			continue
		result.append(BattleEventScript.state_changed(
			&"unit_ready",
			id,
			&"",
			{"round": turn_state.round, "phase": turn_state.phase},
		))
	return result


func _movement_blocked(moving_unit: Variant) -> Dictionary:
	var blocked: Dictionary = _board.get("blocked", {}).duplicate()
	for unit: Variant in units:
		if unit == moving_unit or unit == null or unit.current_hp <= 0 or unit.grid_position == null:
			continue
		blocked[Vector2i(unit.grid_position.x, unit.grid_position.y)] = true
	blocked.erase(Vector2i(moving_unit.grid_position.x, moving_unit.grid_position.y))
	return blocked


func _living_unit_at(position: Vector2i, except_unit: Variant = null) -> Variant:
	for unit: Variant in units:
		if unit == except_unit or unit == null or unit.current_hp <= 0 or unit.grid_position == null:
			continue
		if Vector2i(unit.grid_position.x, unit.grid_position.y) == position:
			return unit
	return null


func _find_unit(id: StringName) -> Variant:
	for unit: Variant in units:
		if unit != null and unit.instance_id == id:
			return unit
	return null


func _contains_position(points: Array, destination: Vector2i) -> bool:
	for point: Variant in points:
		if Vector2i(point.x, point.y) == destination:
			return true
	return false


func _is_living_team_unit(unit: Variant, team: StringName) -> bool:
	return (
		unit != null
		and unit.definition != null
		and unit.grid_position != null
		and unit.current_hp > 0
		and unit.definition.team == team
	)


func _is_living_opponent(actor: Variant, target: Variant) -> bool:
	return (
		_is_living_team_unit(actor, actor.definition.team)
		and target != null
		and target.definition != null
		and target.current_hp > 0
		and target.definition.team != actor.definition.team
	)


func _validated_chapter_copy(source: Variant) -> Variant:
	if source == null or not source.has_method("validated_deep_duplicate"):
		return null
	return source.validated_deep_duplicate()


func _build_units(source_chapter: Variant) -> Array:
	var result: Array = []
	if source_chapter == null:
		return result
	for deployment: Dictionary in source_chapter.deployments:
		var definition: Variant = UnitCatalogScript.get_definition(
			StringName(deployment.get("unit_id", &"")),
		)
		var position: Vector2i = deployment.get("position", Vector2i.ZERO)
		result.append(UnitStateScript.new(
			definition,
			StringName(deployment.get("instance_id", &"")),
			GridPointScript.new(position.x, position.y),
		))
	return result


func _build_board(source_chapter: Variant) -> Dictionary:
	if source_chapter == null:
		return {"width": 0, "height": 0, "blocked": {}}
	var blocked: Dictionary = {}
	for index: int in source_chapter.terrain.size():
		if source_chapter.terrain[index] != "water":
			continue
		blocked[Vector2i(index % source_chapter.width, index / source_chapter.width)] = true
	return {
		"width": source_chapter.width,
		"height": source_chapter.height,
		"blocked": blocked,
		"protected_unit_ids": source_chapter.protected_unit_ids.duplicate(),
	}
