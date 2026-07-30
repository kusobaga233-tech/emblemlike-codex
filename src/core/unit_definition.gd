class_name UnitDefinition
extends Resource

var id: StringName
var display_name: String
var team: StringName
var role: StringName
var max_hp: int
var attack: int
var defense: int
var resistance: int
var move: int
var ranges: PackedInt32Array


func _init(
	initial_id: StringName = &"",
	initial_display_name: String = "",
	initial_team: StringName = &"",
	initial_role: StringName = &"",
	initial_max_hp: int = 0,
	initial_attack: int = 0,
	initial_defense: int = 0,
	initial_resistance: int = 0,
	initial_move: int = 0,
	initial_ranges: PackedInt32Array = PackedInt32Array(),
) -> void:
	id = initial_id
	display_name = initial_display_name
	team = initial_team
	role = initial_role
	max_hp = initial_max_hp
	attack = initial_attack
	defense = initial_defense
	resistance = initial_resistance
	move = initial_move
	ranges = initial_ranges.duplicate()
