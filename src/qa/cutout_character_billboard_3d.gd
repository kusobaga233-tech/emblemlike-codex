class_name CutoutCharacterBillboard3D
extends Node3D

signal presentation_event(event_name: StringName, payload: Dictionary)

@export var foot_margin_px: float = 18.0
@export var auto_face_camera: bool = true

@onready var character_viewport: SubViewport = $CharacterViewport
@onready var cutout_character: CutoutCharacter2D = $CharacterViewport/CutoutCharacter2D
@onready var character_quad: MeshInstance3D = $CharacterQuad


func _ready() -> void:
	_anchor_character_to_feet()
	var material := character_quad.material_override as StandardMaterial3D
	if material != null:
		material.albedo_texture = character_viewport.get_texture()
	cutout_character.presentation_event.connect(_on_character_presentation_event)


func _process(_delta: float) -> void:
	if not auto_face_camera:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		face_camera(camera)


func play_animation(animation_name: StringName) -> bool:
	return cutout_character.play_animation(animation_name)


func face_camera(camera: Camera3D) -> void:
	var target := camera.global_position
	target.y = global_position.y
	if global_position.is_equal_approx(target):
		return
	look_at(target, Vector3.UP, false)


func _anchor_character_to_feet() -> void:
	cutout_character.position = Vector2(
		character_viewport.size.x * 0.5,
		character_viewport.size.y - foot_margin_px
	)


func _on_character_presentation_event(event_name: StringName, payload: Dictionary) -> void:
	var forwarded_payload := payload.duplicate()
	forwarded_payload["billboard_source"] = &"cutout_character_billboard_3d"
	presentation_event.emit(event_name, forwarded_payload)
