extends TestCase

const REQUIRED_ANIMATIONS := [
	"idle",
	"locomotion",
	"attack_primary",
	"attack_secondary",
	"hit",
	"defeat",
	"select",
	"victory",
]


func run() -> void:
	for path in [
		"res://assets/production/models/hero_ember_warden.glb",
		"res://assets/production/models/boss_star_eater.glb",
	]:
		var scene := load(path) as PackedScene
		assert_true(scene != null, "%s imports as PackedScene" % path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		assert_true(_contains_skeleton(instance), "%s contains a Skeleton3D" % path)
		var animation_names := _collect_animation_names(instance)
		for required in REQUIRED_ANIMATIONS:
			assert_true(animation_names.has(required), "%s contains animation %s; found=%s" % [path, required, animation_names])
		instance.free()


func _contains_skeleton(node: Node) -> bool:
	if node is Skeleton3D:
		return true
	for child in node.get_children():
		if _contains_skeleton(child):
			return true
	return false


func _collect_animation_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var library: AnimationLibrary = node.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				if not names.has(animation_name):
					names.append(animation_name)
	for child in node.get_children():
		for child_name in _collect_animation_names(child):
			if not names.has(child_name):
				names.append(child_name)
	return names
