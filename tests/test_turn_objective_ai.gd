extends TestCase

const AI_RULES_PATH := "res://src/core/ai_rules.gd"
const GRID_POINT_PATH := "res://src/core/grid_point.gd"
const OBJECTIVE_RULES_PATH := "res://src/core/objective_rules.gd"
const RESONANCE_STATE_PATH := "res://src/core/resonance_state.gd"
const TURN_STATE_PATH := "res://src/core/turn_state.gd"
const UNIT_DEFINITION_PATH := "res://src/core/unit_definition.gd"
const UNIT_STATE_PATH := "res://src/core/unit_state.gd"

var _ai_rules_script: Script
var _grid_point_script: Script
var _objective_rules_script: Script
var _resonance_state_script: Script
var _turn_state_script: Script
var _unit_definition_script: Script
var _unit_state_script: Script


func run() -> void:
	_ai_rules_script = load(AI_RULES_PATH) as Script
	_grid_point_script = load(GRID_POINT_PATH) as Script
	_objective_rules_script = load(OBJECTIVE_RULES_PATH) as Script
	_resonance_state_script = load(RESONANCE_STATE_PATH) as Script
	_turn_state_script = load(TURN_STATE_PATH) as Script
	_unit_definition_script = load(UNIT_DEFINITION_PATH) as Script
	_unit_state_script = load(UNIT_STATE_PATH) as Script
	assert_true(_ai_rules_script != null, "AiRules class exists")
	assert_true(_grid_point_script != null, "GridPoint class exists")
	assert_true(_objective_rules_script != null, "ObjectiveRules class exists")
	assert_true(_resonance_state_script != null, "ResonanceState class exists")
	assert_true(_turn_state_script != null, "TurnState class exists")
	assert_true(_unit_definition_script != null, "UnitDefinition class exists")
	assert_true(_unit_state_script != null, "UnitState class exists")
	if (
		_ai_rules_script == null
		or _grid_point_script == null
		or _objective_rules_script == null
		or _resonance_state_script == null
		or _turn_state_script == null
		or _unit_definition_script == null
		or _unit_state_script == null
	):
		return

	_test_turn_phase_transitions_round_increment_and_acted_reset()
	_test_objective_schema_reports_ongoing_victory_and_defeat()
	_test_objective_missing_targets_remain_ongoing()
	_test_resonance_gain_clamp_spend_and_illegal_no_op()
	_test_ai_prefers_guaranteed_defeat_over_raw_damage()
	_test_ai_prioritizes_protected_objective_pressure()
	_test_ai_uses_terrain_then_received_damage_risk()
	_test_ai_uses_stable_target_id_ties_and_repeats_exactly()
	_test_ai_returns_controlled_wait_when_no_target_is_legal()


func _test_turn_phase_transitions_round_increment_and_acted_reset() -> void:
	var player: Variant = _make_unit(&"aurelia", &"aurelia-1", &"player", 20, 8, 4, 3, 4, [1], Vector2i(0, 0))
	var enemy: Variant = _make_unit(&"guard", &"guard-1", &"enemy", 20, 7, 4, 3, 4, [1], Vector2i(1, 0))
	player.acted = true
	enemy.acted = true
	var state: Variant = _turn_state_script.new([player, enemy])

	assert_equal(state.phase, &"player", "Battle begins in the player phase")
	assert_equal(state.round, 1, "Battle begins in round one")
	state.end_player_phase()
	assert_equal(state.phase, &"enemy", "Ending player phase begins enemy phase")
	assert_equal(state.round, 1, "Enemy phase remains in the same round")
	assert_equal(enemy.acted, false, "Beginning enemy phase resets enemy acted flags")
	assert_equal(player.acted, true, "Player acted flags remain set during enemy phase")

	player.acted = true
	enemy.acted = true
	state.finish_round()
	assert_equal(state.phase, &"player", "Finishing the round begins player phase")
	assert_equal(state.round, 2, "Finishing the round increments the round")
	assert_equal(player.acted, false, "Beginning a new player phase resets player acted flags")
	assert_equal(enemy.acted, true, "Player phase does not reset enemy acted flags")

	player.acted = true
	state.begin_player_phase()
	assert_equal(player.acted, false, "Explicit player phase begin also resets player acted flags")
	state.begin_enemy_phase()
	assert_equal(state.phase, &"enemy", "Explicit enemy phase begin changes phase")


func _test_objective_schema_reports_ongoing_victory_and_defeat() -> void:
	var captain: Variant = _make_unit(&"bridge-captain", &"captain-1", &"enemy", 24, 9, 4, 3, 3, [1], Vector2i(2, 0))
	var aurelia: Variant = _make_unit(&"aurelia", &"aurelia-1", &"player", 20, 8, 4, 3, 4, [1], Vector2i(0, 0))
	var objective := {
		"victory": [{"type": &"unit_defeated", "target_id": &"bridge-captain"}],
		"defeat": [{"type": &"unit_defeated", "target_id": &"aurelia-1"}],
	}

	assert_equal(_objective_rules_script.evaluate([captain, aurelia], objective), &"ongoing", "Living targets keep the battle ongoing")
	captain.current_hp = 0
	assert_equal(_objective_rules_script.evaluate([captain, aurelia], objective), &"victory", "Definition id targets support chapter-one victory")
	captain.current_hp = 24
	aurelia.current_hp = 0
	assert_equal(_objective_rules_script.evaluate([captain, aurelia], objective), &"defeat", "Instance id targets support chapter-one defeat")
	captain.current_hp = 0
	assert_equal(_objective_rules_script.evaluate([captain, aurelia], objective), &"defeat", "Defeat takes precedence when both groups are satisfied")


func _test_objective_missing_targets_remain_ongoing() -> void:
	var aurelia: Variant = _make_unit(&"aurelia", &"aurelia-1", &"player", 20, 8, 4, 3, 4, [1], Vector2i(0, 0))
	var missing_victory := {
		"victory": [{"type": &"unit_defeated", "target_id": &"missing-boss"}],
		"defeat": [{"type": &"unit_defeated", "target_id": &"aurelia-1"}],
	}
	var missing_defeat := {
		"victory": [{"type": &"unit_defeated", "target_id": &"aurelia"}],
		"defeat": [{"type": &"unit_defeated", "target_id": &"missing-hero"}],
	}

	assert_equal(_objective_rules_script.evaluate([aurelia], missing_victory), &"ongoing", "A missing victory target does not create a false victory")
	assert_equal(_objective_rules_script.evaluate([], missing_defeat), &"ongoing", "Missing targets do not create false defeat or victory")
	assert_equal(_objective_rules_script.evaluate([aurelia], {}), &"ongoing", "An empty objective remains ongoing")


func _test_resonance_gain_clamp_spend_and_illegal_no_op() -> void:
	var actor: Variant = _make_unit(&"aurelia", &"aurelia-1", &"player", 20, 8, 4, 3, 4, [1], Vector2i(0, 0))
	var supporter: Variant = _make_unit(&"elio", &"elio-1", &"player", 18, 5, 3, 5, 4, [1], Vector2i(1, 0))
	var enemy: Variant = _make_unit(&"guard", &"guard-1", &"enemy", 20, 7, 4, 3, 4, [1], Vector2i(0, 1))
	var resonance: Variant = _resonance_state_script.new()

	assert_true(resonance.gain_support_action(actor, supporter, true), "Adjacent friendly support action qualifies")
	assert_equal(resonance.value, 25, "A qualifying support action gains exactly 25")
	assert_equal(resonance.gain_support_action(actor, supporter, false), false, "A non-support action does not qualify")
	assert_equal(resonance.value, 25, "A non-qualifying gain does not mutate resonance")

	resonance.value = 90
	assert_true(resonance.gain_support_action(actor, supporter, true), "Qualifying gain succeeds near the cap")
	assert_equal(resonance.value, 100, "Resonance clamps at 100")
	assert_equal(resonance.try_spend_pair(actor, enemy), false, "Opposing teams are not a legal resonance pair")
	assert_equal(resonance.value, 100, "Illegal spend leaves full resonance unchanged")
	assert_true(resonance.try_spend_pair(actor, supporter), "Adjacent friendly pair can spend full resonance")
	assert_equal(resonance.value, 0, "A legal pair spends exactly 100")
	assert_equal(resonance.try_spend_pair(actor, supporter), false, "A legal pair cannot spend without 100 resonance")
	assert_equal(resonance.value, 0, "Insufficient spend does not mutate resonance")

	supporter.grid_position.x = 3
	assert_equal(resonance.gain_support_action(actor, supporter, true), false, "Non-adjacent support does not qualify")
	assert_equal(resonance.value, 0, "Illegal gain does not mutate resonance")


func _test_ai_prefers_guaranteed_defeat_over_raw_damage() -> void:
	var enemy: Variant = _make_unit(&"captain", &"enemy-1", &"enemy", 20, 10, 2, 2, 0, [1], Vector2i(1, 1))
	var fragile: Variant = _make_unit(&"mage", &"mage-1", &"player", 12, 7, 8, 2, 0, [1], Vector2i(1, 0))
	var tank: Variant = _make_unit(&"tank", &"tank-1", &"player", 30, 7, 0, 2, 0, [1], Vector2i(2, 1))
	fragile.current_hp = 2

	var action: Dictionary = _ai_rules_script.choose_action(enemy, [enemy, tank, fragile], _board(3, 3))
	assert_equal(action["type"], &"attack", "AI chooses an attack when one is legal")
	assert_equal(action["target_id"], &"mage-1", "Guaranteed defeat outranks higher raw damage")


func _test_ai_prioritizes_protected_objective_pressure() -> void:
	var enemy: Variant = _make_unit(&"captain", &"enemy-1", &"enemy", 20, 10, 2, 2, 0, [1], Vector2i(1, 1))
	var protected: Variant = _make_unit(&"aurelia", &"aurelia-1", &"player", 30, 7, 7, 2, 0, [1], Vector2i(1, 0))
	var exposed: Variant = _make_unit(&"archer", &"archer-1", &"player", 30, 7, 0, 2, 0, [1], Vector2i(2, 1))
	var board := _board(3, 3)
	board["protected_unit_ids"] = [&"aurelia-1"]

	var action: Dictionary = _ai_rules_script.choose_action(enemy, [enemy, exposed, protected], board)
	assert_equal(action["target_id"], &"aurelia-1", "Protected-objective pressure outranks expected damage")


func _test_ai_uses_terrain_then_received_damage_risk() -> void:
	var mobile_enemy: Variant = _make_unit(&"captain", &"enemy-1", &"enemy", 20, 8, 2, 2, 3, [1], Vector2i(0, 0))
	var target: Variant = _make_unit(&"target", &"target-1", &"player", 30, 6, 3, 2, 0, [1], Vector2i(2, 0))
	var terrain_board := _board(4, 3)
	terrain_board["terrain_benefits"] = {Vector2i(2, 1): 4}
	var terrain_action: Dictionary = _ai_rules_script.choose_action(mobile_enemy, [mobile_enemy, target], terrain_board)
	assert_equal(terrain_action["destination"], Vector2i(2, 1), "Terrain benefit breaks otherwise equal action ties")

	var risk_enemy: Variant = _make_unit(&"captain", &"enemy-2", &"enemy", 20, 8, 2, 2, 0, [1], Vector2i(1, 1))
	var risky: Variant = _make_unit(&"risky", &"risky-1", &"player", 30, 12, 3, 2, 0, [1], Vector2i(1, 0))
	var safe: Variant = _make_unit(&"safe", &"safe-1", &"player", 30, 4, 3, 2, 0, [1], Vector2i(2, 1))
	var risk_action: Dictionary = _ai_rules_script.choose_action(risk_enemy, [risk_enemy, risky, safe], _board(3, 3))
	assert_equal(risk_action["target_id"], &"safe-1", "Lower received-damage risk wins after earlier score terms tie")


func _test_ai_uses_stable_target_id_ties_and_repeats_exactly() -> void:
	var enemy: Variant = _make_unit(&"captain", &"enemy-1", &"enemy", 20, 8, 2, 2, 0, [1], Vector2i(1, 1))
	var zeta: Variant = _make_unit(&"target", &"zeta-1", &"player", 30, 5, 3, 2, 0, [1], Vector2i(1, 0))
	var alpha: Variant = _make_unit(&"target", &"alpha-1", &"player", 30, 5, 3, 2, 0, [1], Vector2i(2, 1))
	var board := _board(3, 3)

	var first: Dictionary = _ai_rules_script.choose_action(enemy, [enemy, zeta, alpha], board)
	var second: Dictionary = _ai_rules_script.choose_action(enemy, [alpha, enemy, zeta], board)
	assert_equal(first["target_id"], &"alpha-1", "Stable target instance id is the final target tie-break")
	assert_equal(second, first, "Repeated equivalent input produces an identical action dictionary")
	assert_true(first.has("unit_id"), "Action schema includes unit_id")
	assert_true(first.has("destination"), "Action schema includes destination")
	assert_true(first.has("score"), "Action schema includes score")
	assert_equal(typeof(first["score"]), TYPE_INT, "Action score is an integer")


func _test_ai_returns_controlled_wait_when_no_target_is_legal() -> void:
	var enemy: Variant = _make_unit(&"captain", &"enemy-1", &"enemy", 20, 8, 2, 2, 0, [1], Vector2i(0, 0))
	var distant: Variant = _make_unit(&"target", &"target-1", &"player", 30, 5, 3, 2, 0, [1], Vector2i(4, 4))

	var action: Dictionary = _ai_rules_script.choose_action(enemy, [distant, enemy], _board(5, 5))
	assert_equal(action["type"], &"wait", "No legal attack produces a controlled wait")
	assert_equal(action["unit_id"], &"enemy-1", "Wait action retains the acting unit id")
	assert_equal(action["target_id"], &"", "Wait action has no target")
	assert_equal(action["destination"], Vector2i(0, 0), "Wait action retains the current destination")
	assert_equal(action["score"], 0, "Wait action has neutral score")


func _make_unit(
	definition_id: StringName,
	instance_id: StringName,
	team: StringName,
	max_hp: int,
	attack: int,
	defense: int,
	resistance: int,
	move: int,
	ranges: Array,
	position: Vector2i,
) -> Variant:
	var definition: Variant = _unit_definition_script.new(
		definition_id,
		String(definition_id),
		team,
		&"test_role",
		max_hp,
		attack,
		defense,
		resistance,
		move,
		PackedInt32Array(ranges),
		&"physical",
		100,
		0,
	)
	return _unit_state_script.new(definition, instance_id, _grid_point_script.new(position.x, position.y))


func _board(width: int, height: int) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"blocked": {},
		"terrain_benefits": {},
		"protected_unit_ids": [],
	}
