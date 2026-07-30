class_name BattleCommand
extends RefCounted

class CommandData extends RefCounted:
	var type: StringName = &""
	var unit_id: StringName = &""
	var target_id: StringName = &""
	var destination: Vector2i = Vector2i.ZERO
	var partner_id: StringName = &""


	func _init(
		initial_type: StringName = &"",
		initial_unit_id: StringName = &"",
		initial_target_id: StringName = &"",
		initial_destination: Vector2i = Vector2i.ZERO,
		initial_partner_id: StringName = &"",
	) -> void:
		type = initial_type
		unit_id = initial_unit_id
		target_id = initial_target_id
		destination = initial_destination
		partner_id = initial_partner_id


static func select_unit(id: StringName) -> CommandData:
	return CommandData.new(&"select_unit", id)


static func move_selected(to: Vector2i) -> CommandData:
	return CommandData.new(&"move_selected", &"", &"", to)


static func forecast_attack(target: StringName) -> CommandData:
	return CommandData.new(&"forecast_attack", &"", target)


static func confirm_attack(target: StringName) -> CommandData:
	return CommandData.new(&"confirm_attack", &"", target)


static func end_player_phase() -> CommandData:
	return CommandData.new(&"end_player_phase")


static func wait_selected() -> CommandData:
	return CommandData.new(&"wait_selected")


static func advance_enemy_phase() -> CommandData:
	return CommandData.new(&"advance_enemy_phase")

static func support_selected(target: StringName) -> CommandData:
	return CommandData.new(&"support_selected", &"", target)

static func use_resonance_selected(partner: StringName, target: StringName) -> CommandData:
	return CommandData.new(&"use_resonance_selected", &"", target, Vector2i.ZERO, partner)
