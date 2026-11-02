extends TestCase

const CAMERA = preload("res://src/presentation/tactical_camera.gd")

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera: Variant = CAMERA.new()
	tree.root.add_child(camera)
	camera.set_process(false)
	camera.configure_board(8, 10)
	assert_equal(camera.pitch_degrees, 45.0, "fixed tactical pitch")
	var center: Vector3 = camera.focus_point
	var radius: float = camera.distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera._unhandled_input(wheel)
	assert_true(camera.has_method("rotate_steps"), "camera supports discrete rotation")
	assert_true(camera.has_method("advance_rotation"), "camera supports deterministic smooth rotation")
	assert_true(camera.has_method("pan_from_screen"), "camera supports screen-edge panning")
	if not camera.has_method("rotate_steps") or not camera.has_method("advance_rotation") or not camera.has_method("pan_from_screen"):
		camera.free()
		return
	camera.advance_rotation(10.0)
	assert_true(absf(wrapf(camera.yaw_degrees + 30.0, -180.0, 180.0)) < 0.01, "wheel forward rotates clockwise 30 degrees from above")
	assert_equal(camera.focus_point, center, "orbit preserves current focus")
	assert_equal(camera.distance, radius, "wheel does not zoom")
	assert_true(camera.position.x < center.x, "clockwise orbit moves from south toward west")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	camera._unhandled_input(wheel)
	camera.advance_rotation(10.0)
	assert_true(absf(camera.yaw_degrees) < 0.01, "reverse wheel cancels one step")
	camera.rotate_steps(3)
	camera.advance_rotation(0.01)
	assert_true(absf(camera.yaw_degrees) > 0.0 and absf(camera.yaw_degrees) < 90.0, "orbit transitions rather than teleporting")
	camera.advance_rotation(10.0)
	assert_true(absf(camera.yaw_degrees + 90.0) < 0.01, "rapid input accumulates three steps")
	camera.rotate_steps(12)
	camera.advance_rotation(10.0)
	assert_true(absf(wrapf(camera.yaw_degrees + 90.0, -180.0, 180.0)) < 0.01, "twelve steps completes a circle")
	assert_equal(camera.pitch_degrees, 45.0, "rotation never changes pitch")
	var orbit_target := Node3D.new()
	orbit_target.position = Vector3(1.0, 0.7, 8.0)
	tree.root.add_child(orbit_target)
	camera.focus_target = orbit_target
	camera.reset_view()
	camera.rotate_steps(1)
	camera.advance_rotation(10.0)
	assert_equal(camera.focus_point, Vector3(1.0, 0.0, 8.0), "selected character becomes orbit focus")
	assert_true(camera.position.distance_to(Vector3(1.0, 0.0, 8.0)) > 0.0, "camera orbits around selected character")
	orbit_target.free()
	camera.focus_target = null
	camera.reset_view()
	camera.pan_from_screen(Vector2(799, 300), Vector2(800, 600), 0.1)
	assert_true(camera.focus_point.x > center.x, "screen-right pans right at initial yaw")
	assert_equal(camera.distance, radius, "panning does not change zoom")
	camera.focus(center)
	camera.rotate_steps(-3)
	camera.advance_rotation(10.0)
	camera.pan_from_screen(Vector2(799, 300), Vector2(800, 600), 0.1)
	assert_true(camera.focus_point.z < center.z, "screen-right follows rotated camera axes")
	assert_true(camera.edge_direction(Vector2(400, 300), Vector2(800, 600)).is_zero_approx(), "interior is not a pan zone")
	assert_true(camera.edge_direction(Vector2(-1, 300), Vector2(800, 600)).is_zero_approx(), "outside viewport does not pan")
	assert_true(absf(camera.edge_direction(Vector2(799, 599), Vector2(800, 600)).length() - 1.0) < 0.001, "diagonals normalized")
	camera.pan_from_screen(Vector2(799, 599), Vector2(800, 600), 100.0)
	assert_true(camera.focus_point.x >= 0.0 and camera.focus_point.x <= 7.0 and camera.focus_point.z >= 0.0 and camera.focus_point.z <= 9.0, "pan focus clamped to board")
	camera.controls_enabled = false
	var stopped: Vector3 = camera.focus_point
	var yaw: float = camera.yaw_degrees
	camera._unhandled_input(wheel)
	camera.advance_rotation(10.0)
	camera.pan_from_screen(Vector2(0, 0), Vector2(800, 600), 1.0)
	assert_equal(camera.focus_point, stopped, "disabled controls suppress panning")
	assert_equal(camera.yaw_degrees, yaw, "disabled controls suppress wheel")
	camera.free()

	var battle: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(battle)
	var battle_camera: Variant = battle.get_node("TacticalCamera")
	battle_camera.set_process(false)
	battle.session.select_unit(&"aurelia-1")
	var before_id: StringName = battle.session.selected_unit_id
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	battle_camera._unhandled_input(wheel)
	battle_camera.advance_rotation(10.0)
	assert_equal(battle.session.selected_unit_id, before_id, "camera orbit preserves selected unit")
	assert_true(battle.get_unit_node(before_id).get_node("SelectionOutline").visible, "orbit preserves selection marker")
	assert_true(battle_camera.has_method("_on_pointer_left_window"), "window-leave guard is available")
	if battle_camera.has_method("_on_pointer_left_window"):
		battle_camera._on_pointer_left_window()
		var held_yaw: float = battle_camera.yaw_degrees
		battle_camera._unhandled_input(wheel)
		battle_camera.advance_rotation(10.0)
		assert_equal(battle_camera.yaw_degrees, held_yaw, "pointer leaving window blocks wheel input")

	battle.free()
