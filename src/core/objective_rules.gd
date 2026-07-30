class_name ObjectiveRules
extends RefCounted

const STATUS_ONGOING := &"ongoing"
const STATUS_VICTORY := &"victory"
const STATUS_DEFEAT := &"defeat"
const CONDITION_UNIT_DEFEATED := &"unit_defeated"


static func evaluate(units: Array, objective: Dictionary) -> StringName:
	if _group_is_satisfied(units, objective.get("defeat", [])):
		return STATUS_DEFEAT
	if _group_is_satisfied(units, objective.get("victory", [])):
		return STATUS_VICTORY
	return STATUS_ONGOING


static func _group_is_satisfied(units: Array, conditions_value: Variant) -> bool:
	if not conditions_value is Array:
		return false
	var conditions: Array = conditions_value
	if conditions.is_empty():
		return false
	for condition_value: Variant in conditions:
		if not condition_value is Dictionary:
			return false
		if not _condition_is_satisfied(units, condition_value):
			return false
	return true


static func _condition_is_satisfied(units: Array, condition: Dictionary) -> bool:
	if StringName(condition.get("type", &"")) != CONDITION_UNIT_DEFEATED:
		return false
	var target_id := StringName(condition.get("target_id", &""))
	if target_id == &"":
		return false
	var target: Variant = _find_target(units, target_id)
	return target != null and target.current_hp <= 0


static func _find_target(units: Array, target_id: StringName) -> Variant:
	for unit: Variant in units:
		if unit == null:
			continue
		if unit.instance_id == target_id:
			return unit
		if unit.definition != null and unit.definition.id == target_id:
			return unit
	return null
