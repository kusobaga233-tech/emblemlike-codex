class_name AiRules
extends RefCounted

const CombatRulesScript = preload("res://src/core/combat_rules.gd")
const GridPointScript = preload("res://src/core/grid_point.gd")
const GridRulesScript = preload("res://src/core/grid_rules.gd")
const UnitStateScript = preload("res://src/core/unit_state.gd")

const GUARANTEED_DEFEAT_WEIGHT := 1_000_000_000_000_000
const PROTECTED_OBJECTIVE_WEIGHT := 1_000_000_000_000
const EXPECTED_DAMAGE_WEIGHT := 1_000_000
const TERRAIN_BENEFIT_WEIGHT := 1_000


static func choose_action(enemy: Variant, units: Array, board: Dictionary) -> Dictionary:
	if not _has_unit_state(enemy):
		return _wait_action(enemy)

	var best: Dictionary = {}
	var destinations := _candidate_destinations(enemy, units, board)
	for target: Variant in units:
		if not _is_living_opponent(enemy, target):
			continue
		for destination: Vector2i in destinations:
			var candidate := _attack_candidate(enemy, target, destination, board)
			if candidate.is_empty():
				continue
			if best.is_empty() or _is_better(candidate, best):
				best = candidate

	if best.is_empty():
		return _wait_action(enemy)
	return {
		"type": &"attack",
		"unit_id": best["unit_id"],
		"target_id": best["target_id"],
		"destination": best["destination"],
		"score": best["score"],
	}


static func _candidate_destinations(enemy: Variant, units: Array, board: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := Vector2i(enemy.grid_position.x, enemy.grid_position.y)
	var width := int(board.get("width", 0))
	var height := int(board.get("height", 0))
	if width <= 0 or height <= 0:
		result.append(origin)
		return result

	var blocked: Dictionary = {}
	var board_blocked: Variant = board.get("blocked", {})
	if board_blocked is Dictionary:
		blocked = board_blocked.duplicate()
	for unit: Variant in units:
		if not _has_unit_state(unit) or unit == enemy or unit.current_hp <= 0:
			continue
		blocked[Vector2i(unit.grid_position.x, unit.grid_position.y)] = true
	blocked.erase(origin)

	var reachable: Array = GridRulesScript.reachable(
		enemy.grid_position,
		maxi(0, enemy.definition.move),
		width,
		height,
		blocked,
	)
	for point: Variant in reachable:
		result.append(Vector2i(point.x, point.y))
	return result


static func _attack_candidate(
	enemy: Variant,
	target: Variant,
	destination: Vector2i,
	board: Dictionary,
) -> Dictionary:
	var positioned_enemy: Variant = _copy_at(enemy, destination)
	var forecast: Variant = CombatRulesScript.forecast(positioned_enemy, target)
	if not forecast.legal:
		return {}

	var expected_damage: int = mini(int(forecast.damage), int(target.current_hp)) * int(forecast.hit_rate)
	var guaranteed_defeat: int = int(forecast.hit_rate == 100 and forecast.defender_remaining_hp == 0)
	var protected_objective: int = int(_is_protected(target.instance_id, board))
	var terrain_benefit: int = _terrain_benefit(destination, board)
	var received_damage_risk: int = _received_damage_risk(target, positioned_enemy)
	var score: int = (
		guaranteed_defeat * GUARANTEED_DEFEAT_WEIGHT
		+ protected_objective * PROTECTED_OBJECTIVE_WEIGHT
		+ clampi(expected_damage, 0, 999_999) * EXPECTED_DAMAGE_WEIGHT
		+ clampi(terrain_benefit, -999, 999) * TERRAIN_BENEFIT_WEIGHT
		- clampi(received_damage_risk, 0, 999)
	)
	return {
		"unit_id": enemy.instance_id,
		"target_id": target.instance_id,
		"destination": destination,
		"score": score,
		"guaranteed_defeat": guaranteed_defeat,
		"protected_objective": protected_objective,
		"expected_damage": expected_damage,
		"terrain_benefit": terrain_benefit,
		"received_damage_risk": received_damage_risk,
	}


static func _is_better(candidate: Dictionary, current: Dictionary) -> bool:
	for key: StringName in [
		&"guaranteed_defeat",
		&"protected_objective",
		&"expected_damage",
		&"terrain_benefit",
	]:
		if candidate[key] != current[key]:
			return candidate[key] > current[key]
	if candidate["received_damage_risk"] != current["received_damage_risk"]:
		return candidate["received_damage_risk"] < current["received_damage_risk"]
	var candidate_target := String(candidate["target_id"])
	var current_target := String(current["target_id"])
	if candidate_target != current_target:
		return candidate_target < current_target
	var candidate_destination: Vector2i = candidate["destination"]
	var current_destination: Vector2i = current["destination"]
	if candidate_destination.y != current_destination.y:
		return candidate_destination.y < current_destination.y
	return candidate_destination.x < current_destination.x


static func _received_damage_risk(target: Variant, positioned_enemy: Variant) -> int:
	var counter_forecast: Variant = CombatRulesScript.forecast(target, positioned_enemy)
	if not counter_forecast.legal:
		return 0
	return mini(counter_forecast.damage, positioned_enemy.current_hp) * counter_forecast.hit_rate


static func _is_protected(target_id: StringName, board: Dictionary) -> bool:
	var protected_ids: Variant = board.get("protected_unit_ids", [])
	if not protected_ids is Array:
		return false
	for protected_id: Variant in protected_ids:
		if StringName(protected_id) == target_id:
			return true
	return false


static func _terrain_benefit(destination: Vector2i, board: Dictionary) -> int:
	var terrain_benefits: Variant = board.get("terrain_benefits", {})
	if not terrain_benefits is Dictionary:
		return 0
	return int(terrain_benefits.get(destination, 0))


static func _copy_at(unit: Variant, destination: Vector2i) -> Variant:
	var copy: Variant = UnitStateScript.new(
		unit.definition,
		unit.instance_id,
		GridPointScript.new(destination.x, destination.y),
	)
	copy.current_hp = unit.current_hp
	copy.acted = unit.acted
	copy.experience = unit.experience
	copy.level = unit.level
	return copy


static func _is_living_opponent(enemy: Variant, target: Variant) -> bool:
	return (
		_has_unit_state(target)
		and target != enemy
		and target.current_hp > 0
		and target.definition.team != enemy.definition.team
	)


static func _has_unit_state(unit: Variant) -> bool:
	return unit != null and unit.definition != null and unit.grid_position != null


static func _wait_action(enemy: Variant) -> Dictionary:
	var unit_id := &""
	var destination := Vector2i.ZERO
	if _has_unit_state(enemy):
		unit_id = enemy.instance_id
		destination = Vector2i(enemy.grid_position.x, enemy.grid_position.y)
	return {
		"type": &"wait",
		"unit_id": unit_id,
		"target_id": &"",
		"destination": destination,
		"score": 0,
	}
