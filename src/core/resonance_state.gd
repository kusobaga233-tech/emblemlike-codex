class_name ResonanceState
extends RefCounted

const GridRulesScript = preload("res://src/core/grid_rules.gd")
const MAX_VALUE := 100
const SUPPORT_GAIN := 25
const PAIR_COST := 100

var value: int = 0


func _init(initial_value: int = 0) -> void:
	value = clampi(initial_value, 0, MAX_VALUE)


func gain_support_action(actor: Variant, supporter: Variant, is_support_action: bool) -> bool:
	if not is_support_action or not _is_legal_pair(actor, supporter):
		return false
	value = mini(MAX_VALUE, value + SUPPORT_GAIN)
	return true


func try_spend_pair(first: Variant, second: Variant) -> bool:
	if value != PAIR_COST or not _is_legal_pair(first, second):
		return false
	value -= PAIR_COST
	return true


static func pair_damage(first: Variant, second: Variant, target: Variant) -> int:
	if first == null or second == null or target == null:
		return 0
	if first.definition == null or second.definition == null or target.definition == null:
		return 0
	return maxi(1, first.definition.attack + second.definition.attack - target.definition.defense)


static func _is_legal_pair(first: Variant, second: Variant) -> bool:
	if first == null or second == null or first == second:
		return false
	if first.definition == null or second.definition == null:
		return false
	if first.grid_position == null or second.grid_position == null:
		return false
	if first.current_hp <= 0 or second.current_hp <= 0:
		return false
	if first.instance_id == second.instance_id:
		return false
	if first.definition.team != second.definition.team:
		return false
	return GridRulesScript.manhattan(first.grid_position, second.grid_position) == 1
