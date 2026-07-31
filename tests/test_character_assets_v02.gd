extends TestCase

const CHARACTER_PATHS := {
	&"brann": "res://assets/production/models/hero_ash_vanguard.glb",
	&"elio": "res://assets/production/models/hero_starbound_mender.glb",
	&"fenn": "res://assets/production/models/hero_cinder_seer.glb",
	&"hollow-blade": "res://assets/production/models/enemy_ember_husk.glb",
	&"hollow-bow": "res://assets/production/models/enemy_void_lancer.glb",
}
const WEAPON_PATHS := [
	"res://assets/production/weapons/oathblade.glb",
	"res://assets/production/weapons/ash_lance.glb",
	"res://assets/production/weapons/cinder_focus.glb",
	"res://assets/production/weapons/mender_staff.glb",
	"res://assets/production/weapons/star_eater_core.glb",
]
const REQUIRED_ANIMATIONS := [&"idle", &"locomotion", &"attack_primary", &"attack_secondary", &"hit", &"defeat", &"select", &"victory"]


func run() -> void:
	var unit_script := FileAccess.get_file_as_string("res://src/presentation/greybox_unit.gd")
	for unit_id in CHARACTER_PATHS:
		var path: String = CHARACTER_PATHS[unit_id]
		assert_true(unit_script.contains('&"%s": "%s"' % [unit_id, path]), "%s maps to %s" % [unit_id, path])
		_validate_character(path)
	for path in WEAPON_PATHS:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		assert_true(load(path) is PackedScene, "%s imports as PackedScene" % path)


func _validate_character(path: String) -> void:
	assert_true(ResourceLoader.exists(path), "%s exists" % path)
	var packed := load(path) as PackedScene
	assert_true(packed != null, "%s imports as PackedScene" % path)
	if packed == null:
		return
	var instance := packed.instantiate()
	var skeleton := _find_skeleton(instance)
	assert_true(skeleton != null, "%s contains Skeleton3D" % path)
	if skeleton != null:
		assert_true(skeleton.find_bone("hand_r_weapon") >= 0, "%s has hand_r_weapon" % path)
	var names := _collect_animation_names(instance)
	for animation_name in REQUIRED_ANIMATIONS:
		assert_true(names.has(animation_name), "%s contains animation %s; found=%s" % [path, animation_name, names])
	instance.free()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _collect_animation_names(node: Node) -> Array[StringName]:
	var names: Array[StringName] = []
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var library: AnimationLibrary = node.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				names.append(StringName(animation_name))
	for child in node.get_children():
		for child_name in _collect_animation_names(child):
			if not names.has(child_name):
				names.append(child_name)
	return names
