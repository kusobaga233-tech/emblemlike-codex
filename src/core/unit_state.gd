class_name UnitState
extends RefCounted

const GridPointScript = preload("res://src/core/grid_point.gd")
const UnitDefinitionScript = preload("res://src/core/unit_definition.gd")

var definition: UnitDefinitionScript
var instance_id: StringName
var grid_position: GridPointScript
var current_hp: int
var acted: bool
var has_moved: bool
var experience: int
var level: int


func _init(
	initial_definition: UnitDefinitionScript = null,
	initial_instance_id: StringName = &"",
	initial_grid_position: GridPointScript = null,
) -> void:
	definition = initial_definition
	instance_id = initial_instance_id
	if initial_grid_position == null:
		grid_position = GridPointScript.new()
	else:
		grid_position = GridPointScript.new(initial_grid_position.x, initial_grid_position.y)
	current_hp = definition.max_hp if definition != null else 0
	acted = false
	has_moved = false
	experience = 0
	level = 1
