class_name CutoutCharacter2D
extends Node2D

signal presentation_event(event_name: StringName, payload: Dictionary)

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.play(&"idle")


func play_animation(animation_name: StringName) -> bool:
	if not animation_player.has_animation(animation_name):
		return false
	animation_player.play(animation_name)
	return true


func _emit_presentation_event(event_name: StringName) -> void:
	presentation_event.emit(event_name, {"source": &"aurelia_cutout_v01"})
