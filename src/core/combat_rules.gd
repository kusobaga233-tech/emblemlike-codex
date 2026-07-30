class_name CombatRules
extends RefCounted

const BattleEventScript = preload("res://src/events/battle_event.gd")
const CombatForecastScript = preload("res://src/core/combat_forecast.gd")
const GridRulesScript = preload("res://src/core/grid_rules.gd")
const UnitStateScript = preload("res://src/core/unit_state.gd")


static func forecast(
	attacker: UnitStateScript,
	defender: UnitStateScript,
) -> CombatForecastScript:
	var result := CombatForecastScript.new()
	if not _has_combat_state(attacker) or not _has_combat_state(defender):
		return result

	result.defender_remaining_hp = maxi(0, defender.current_hp)
	result.hit_rate = clampi(attacker.definition.hit, 0, 100)
	result.critical_rate = clampi(attacker.definition.critical, 0, 100)
	if attacker.current_hp <= 0 or defender.current_hp <= 0:
		return result

	var distance := GridRulesScript.manhattan(attacker.grid_position, defender.grid_position)
	if not attacker.definition.ranges.has(distance):
		return result

	result.legal = true
	result.strike_count = 1
	var mitigation: int = defender.definition.defense
	if attacker.definition.damage_type == &"magical":
		mitigation = defender.definition.resistance
	result.damage = maxi(0, attacker.definition.attack - mitigation)
	result.defender_remaining_hp = maxi(0, defender.current_hp - result.damage)
	result.can_counter = (
		result.defender_remaining_hp > 0
		and defender.definition.ranges.has(distance)
	)
	return result


static func resolve(
	attacker: UnitStateScript,
	defender: UnitStateScript,
	seed: int,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var combat_forecast := forecast(attacker, defender)
	if not combat_forecast.legal:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var distance := GridRulesScript.manhattan(attacker.grid_position, defender.grid_position)
	result.append(BattleEventScript.attack_started(attacker.instance_id, defender.instance_id, distance))

	if rng.randi_range(1, 100) > combat_forecast.hit_rate:
		result.append(BattleEventScript.attack_missed(
			attacker.instance_id,
			defender.instance_id,
			combat_forecast.hit_rate,
		))
		result.append(BattleEventScript.attack_finished(
			attacker.instance_id,
			defender.instance_id,
			defender.current_hp,
		))
		return result

	var is_critical := rng.randi_range(1, 100) <= combat_forecast.critical_rate
	result.append(BattleEventScript.hit_confirmed(
		attacker.instance_id,
		defender.instance_id,
		combat_forecast.hit_rate,
		is_critical,
		combat_forecast.critical_rate,
	))
	var damage := combat_forecast.damage * (2 if is_critical else 1)
	defender.current_hp = maxi(0, defender.current_hp - damage)
	result.append(BattleEventScript.damage_applied(
		attacker.instance_id,
		defender.instance_id,
		damage,
		defender.current_hp,
	))
	if defender.current_hp == 0:
		result.append(BattleEventScript.unit_defeated(
			attacker.instance_id,
			defender.instance_id,
			defender.current_hp,
		))
	result.append(BattleEventScript.attack_finished(
		attacker.instance_id,
		defender.instance_id,
		defender.current_hp,
	))
	return result


static func _has_combat_state(unit: UnitStateScript) -> bool:
	return unit != null and unit.definition != null and unit.grid_position != null
