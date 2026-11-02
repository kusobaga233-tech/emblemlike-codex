extends TestCase

const MODEL_PATH := "res://assets/test/models/bb_test_character.glb"
const PREVIEW_PATH := "res://src/qa/bb_test_character_preview.tscn"
const REQUIRED_ANIMATIONS := [
	&"idle",
	&"locomotion",
	&"attack_primary",
	&"attack_secondary",
	&"hit",
	&"defeat",
	&"select",
	&"victory",
]


func run() -> void:
	assert_true(ResourceLoader.exists(MODEL_PATH), "diagnostic BB model exists")
	var packed := load(MODEL_PATH) as PackedScene
	assert_true(packed != null, "diagnostic BB model imports as PackedScene")
	if packed == null:
		return

	var instance := packed.instantiate()
	assert_true(_find_node_of_type(instance, Skeleton3D) != null, "diagnostic BB model contains Skeleton3D")
	assert_true(_has_skinned_mesh(instance), "diagnostic BB model contains a mesh with skin")
	assert_true(_has_material(instance), "diagnostic BB model contains a material")
	var names := _collect_animation_names(instance)
	for animation_name in REQUIRED_ANIMATIONS:
		assert_true(names.has(animation_name), "diagnostic BB model contains %s; found=%s" % [animation_name, names])
	assert_equal(names.size(), REQUIRED_ANIMATIONS.size(), "diagnostic BB model imports exactly eight clips")
	instance.free()

	assert_true(ResourceLoader.exists(PREVIEW_PATH), "isolated diagnostic preview scene exists")
	var preview_packed := load(PREVIEW_PATH) as PackedScene
	assert_true(preview_packed != null, "isolated diagnostic preview scene loads")
	if preview_packed != null:
		var preview := preview_packed.instantiate()
		preview.auto_cycle = false
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(preview)
		await tree.process_frame
		for animation_name in REQUIRED_ANIMATIONS:
			assert_true(preview.seek_clip(animation_name, 0.5), "preview can seek %s for deterministic evidence" % animation_name)
		preview.free()


func _find_node_of_type(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found := _find_node_of_type(child, type)
		if found != null:
			return found
	return null


func _has_skinned_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh != null and node.skin != null:
		return true
	for child in node.get_children():
		if _has_skinned_mesh(child):
			return true
	return false


func _has_material(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for surface_index in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(surface_index) != null:
				return true
	for child in node.get_children():
		if _has_material(child):
			return true
	return false


func _collect_animation_names(node: Node) -> Array[StringName]:
	var names: Array[StringName] = []
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var library: AnimationLibrary = node.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				var canonical := StringName(animation_name.get_file())
				if not names.has(canonical):
					names.append(canonical)
	for child in node.get_children():
		for child_name in _collect_animation_names(child):
			if not names.has(child_name):
				names.append(child_name)
	return names
