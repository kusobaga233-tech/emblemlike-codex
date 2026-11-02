extends Node3D

const CLIPS: Array[StringName] = [
	&"idle",
	&"locomotion",
	&"attack_primary",
	&"attack_secondary",
	&"hit",
	&"defeat",
	&"select",
	&"victory",
]

@export var auto_cycle := true
@export_range(0.5, 10.0, 0.1) var clip_preview_seconds := 2.5

var _players: Array[AnimationPlayer] = []
var _clip_index := 0
var _elapsed := 0.0


func _ready() -> void:
	_collect_animation_players($Character)
	_frame_character()
	if not _players.is_empty():
		_play_clip(CLIPS[_clip_index])


func _process(delta: float) -> void:
	if not auto_cycle or _players.is_empty():
		return
	_elapsed += delta
	if _elapsed < clip_preview_seconds:
		return
	_elapsed = 0.0
	_clip_index = (_clip_index + 1) % CLIPS.size()
	_play_clip(CLIPS[_clip_index])


func play_clip(animation_name: StringName) -> bool:
	return _play_clip(animation_name)


func seek_clip(animation_name: StringName, normalized_time: float) -> bool:
	var sought := false
	for player in _players:
		var resolved := _resolve_animation_name(player, animation_name)
		if resolved.is_empty():
			continue
		player.play(resolved)
		var animation := player.get_animation(resolved)
		if animation != null:
			player.seek(animation.length * clampf(normalized_time, 0.0, 1.0), true)
			player.advance(0.0)
			sought = true
	return sought


func current_clip() -> StringName:
	return CLIPS[_clip_index]


func _play_clip(animation_name: StringName) -> bool:
	var played := false
	for player in _players:
		var resolved := _resolve_animation_name(player, animation_name)
		if not resolved.is_empty():
			player.play(resolved)
			played = true
	return played


func _resolve_animation_name(player: AnimationPlayer, wanted: StringName) -> StringName:
	for library_name in player.get_animation_library_list():
		var library: AnimationLibrary = player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			if StringName(animation_name.get_file()) == wanted:
				return animation_name if library_name.is_empty() else StringName("%s/%s" % [library_name, animation_name])
	return &""


func _collect_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		_players.append(node)
	for child in node.get_children():
		_collect_animation_players(child)


func _frame_character() -> void:
	var bounds := _collect_bounds($Character)
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.6, 1.0)
	$Camera3D.position = center + Vector3(0.0, bounds.size.y * 0.02, radius * 2.15)
	$Camera3D.look_at(center)
	$Ground.position.y = bounds.position.y - 0.02
	$Ground.scale = Vector3(radius * 1.35, 1.0, radius * 1.35)


func _collect_bounds(root_node: Node3D) -> AABB:
	var bounds := AABB()
	var initialized := false
	for mesh in _find_meshes(root_node):
		var local_bounds := mesh.get_aabb()
		var relative_transform := root_node.global_transform.affine_inverse() * mesh.global_transform
		var transformed := relative_transform * local_bounds
		bounds = transformed if not initialized else bounds.merge(transformed)
		initialized = true
	return bounds


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_find_meshes(child))
	return meshes
