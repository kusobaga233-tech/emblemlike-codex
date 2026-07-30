class_name ChapterDefinition
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var subtitle: String = ""
@export var width: int = 0
@export var height: int = 0
@export var terrain: PackedStringArray = PackedStringArray()
@export var deployments: Array[Dictionary] = []
@export var objectives: Array[Dictionary] = []
@export var failure_conditions: Array[Dictionary] = []
@export var protected_unit_ids: Array[StringName] = []
@export var events: Array[Dictionary] = []
@export var dialogue: Dictionary = {}
@export var turn_limit: int = 0
