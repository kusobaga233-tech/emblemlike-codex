extends TestCase

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(scene)
	var timeline: Variant = scene.get_node("SpriteCombatPresentation")
	var camera: Camera3D = scene.get_node("TacticalCamera")
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera._apply_transform()
	assert_true(timeline.has_method("screen_attack_direction"), "presentation computes camera-relative attack direction")
	if not timeline.has_method("screen_attack_direction"):
		scene.free()
		return
	var east: Vector2 = timeline.call("screen_attack_direction", camera, Vector3.ZERO, Vector3(1.0, 0.0, 0.0))
	var north: Vector2 = timeline.call("screen_attack_direction", camera, Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	assert_true(east.x > 0.99 and absf(east.y) < 0.01, "east target maps to screen right from front view")
	assert_true(north.y > 0.5, "north target maps toward screen top")
	camera.yaw_degrees = 90.0
	camera._apply_transform()
	var rotated: Vector2 = timeline.call("screen_attack_direction", camera, Vector3.ZERO, Vector3(1.0, 0.0, 0.0))
	assert_true(rotated.length() > 0.99 and not rotated.is_equal_approx(east), "attack direction follows rotated camera")
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera._apply_transform()
	var actor: Variant = scene.get_unit_node(&"aurelia-1")
	var target: Variant = scene.get_unit_node(&"blade-1")
	actor.position = Vector3(1.0, 0.7, 5.0)
	target.position = Vector3(2.0, 0.7, 5.0)
	scene.session.events_flushed.emit([
		{"type": &"attack_started", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {"distance": 1}},
		{"type": &"attack_finished", "actor_id": &"aurelia-1", "target_id": &"blade-1", "payload": {}},
	] as Array[Dictionary])
	var slash: Dictionary = timeline._effects.filter(func(e: Dictionary) -> bool: return e["kind"] == &"slash")[0]
	assert_true(slash.has("screen_direction"), "slash stores camera-projected source-to-target direction")
	assert_true(slash["node"].position.is_equal_approx((slash["origin"] + slash["target"]) * 0.5), "slash node is centered between attacker and target")
	if slash.has("screen_direction"):
		assert_true((slash["screen_direction"] as Vector2).x > 0.0, "eastbound melee slash travels toward right side of screen")
		timeline.advance(0.2)
		var mesh: ImmediateMesh = slash["node"].mesh
		var before: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_true(before.size() >= 120, "melee cut uses a segmented tapered arc rather than a straight rectangular strip")
		var attack_vector: Vector3 = slash["target"] - slash["origin"]
		assert_true(slash["node"].position.is_equal_approx((slash["origin"] + slash["target"]) * 0.5), "slash anchor uses attacker-target midpoint")
		var vertex_center := Vector3.ZERO
		for vertex in before:
			vertex_center += vertex
		vertex_center /= before.size()
		assert_true(vertex_center.distance_to(Vector3.ZERO) < attack_vector.length(), "slash mesh vertices are local to centered anchor")
		camera.yaw_degrees = 90.0
		camera._apply_transform()
		timeline.advance(0.01)
		var after: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_true(before != after, "slash sweep geometry updates with camera orbit")
	scene.free()
