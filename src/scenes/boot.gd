extends Node

const TITLE_SCENE_PATH := "res://src/scenes/title/title.tscn"


func _ready() -> void:
	if not ResourceLoader.exists(TITLE_SCENE_PATH):
		return
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
