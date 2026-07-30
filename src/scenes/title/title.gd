class_name TitleScreen
extends Control

signal start_pressed(path: String)

const DEPLOYMENT_PATH := "res://src/scenes/deployment/deployment.tscn"


func _ready() -> void:
	$Layout/Start.pressed.connect(_on_start_pressed)
	$Layout/Start.call_deferred("grab_focus")


func _on_start_pressed() -> void:
	start_pressed.emit(DEPLOYMENT_PATH)
