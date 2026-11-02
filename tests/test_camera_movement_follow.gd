extends TestCase

const CAMERA = preload("res://src/presentation/tactical_camera.gd")

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera: Variant = CAMERA.new()
	var target := Node3D.new()
	target.position = Vector3(1.0, 0.7, 7.0)
	tree.root.add_child(target)
	tree.root.add_child(camera)
	camera.set_process(false)
	camera.configure_board(12, 12)
	camera.focus_target = target
	assert_true(camera.has_method("begin_movement_follow"), "movement follow entry point exists")
	if not camera.has_method("begin_movement_follow"):
		camera.free()
		target.free()
		return
	var start: Vector3 = camera.focus_point
	var radius: float = camera.distance
	var yaw: float = camera.yaw_degrees
	camera.begin_movement_follow(target)
	target.position.x += 0.5
	camera.advance_movement_follow(0.016)
	assert_true(camera.focus_point.is_equal_approx(start + Vector3(0.5, 0.0, 0.0)), "camera follows first movement frame without delay")
	target.position.x += 0.5
	camera.advance_movement_follow(0.016)
	assert_true(camera.focus_point.is_equal_approx(start + Vector3(1.0, 0.0, 0.0)), "camera matches current character displacement each frame")
	camera.advance_movement_follow(0.016)
	assert_true(camera.focus_point.is_equal_approx(start + Vector3(1.0, 0.0, 0.0)), "stationary character does not cause residual camera movement")
	assert_equal(camera.distance, radius, "follow preserves distance")
	assert_equal(camera.yaw_degrees, yaw, "follow preserves yaw")
	assert_equal(camera.pitch_degrees, 45.0, "follow preserves pitch")
	camera.begin_movement_follow(target)
	target.position.x += 1.0
	camera.pan_from_screen(Vector2(799, 300), Vector2(800, 600), 0.1)
	var manual: Vector3 = camera.focus_point
	camera.advance_movement_follow(1.0)
	assert_equal(camera.focus_point, manual, "manual edge pan cancels old follow")
	camera.begin_movement_follow(target)
	target.position.x += 1.0
	camera.rotate_steps(1)
	var orbit_center: Vector3 = camera.focus_point
	camera.advance_movement_follow(1.0)
	assert_equal(camera.focus_point, orbit_center, "wheel orbit cancels old follow")
	camera.begin_movement_follow(target)
	camera.focus_target = null
	target.position.x += 1.0
	var deselected: Vector3 = camera.focus_point
	camera.advance_movement_follow(1.0)
	assert_equal(camera.focus_point, deselected, "selection switch cancels follow")
	camera.focus_target = target
	camera.begin_movement_follow(target)
	target.free()
	camera.advance_movement_follow(1.0)
	assert_equal(camera.focus_point, deselected, "freed target cancels safely")
	camera.free()

	var battle: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	tree.root.add_child(battle)
	var battle_camera: Variant = battle.get_node("TacticalCamera")
	battle_camera.set_process(false)
	battle.session.select_unit(&"aurelia-1")
	var actor: Variant = battle.get_unit_node(&"aurelia-1")
	var initial_position: Vector3 = actor.global_position
	var initial_focus: Vector3 = battle_camera.focus_point
	var available: Array = battle.session.reachable_cells_for_selected()
	var destination: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in available:
		if cell != Vector2i(1, 7):
			destination = cell
			break
	assert_true(destination != Vector2i(-1, -1), "integration has a legal movement destination")
	if destination != Vector2i(-1, -1):
		var result: Dictionary = battle.session.move_selected(destination)
		assert_true(result.get("ok", false), "real move command accepted")
		assert_equal(battle_camera.focus_point, initial_focus, "move event does not instantly reposition camera")
		actor.position_animation.custom_step(0.09)
		battle_camera.advance_movement_follow(0.09)
		assert_true(not actor.global_position.is_equal_approx(initial_position), "character moved in first half of tween")
		assert_true(battle_camera.focus_point.is_equal_approx(initial_focus + actor.global_position - initial_position), "camera follows character synchronously at tween midpoint")
		actor.position_animation.custom_step(0.09)
		battle_camera.advance_movement_follow(0.09)
		assert_true(battle_camera.focus_point.is_equal_approx(initial_focus + actor.global_position - initial_position), "camera reaches destination with character at 180ms")
		assert_equal(battle.session.selected_unit_id, &"aurelia-1", "follow does not change selection")
	battle.free()
