extends TestCase

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var camera: Variant = scene.get_node("TacticalCamera")
	camera.set_process(false)
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera.focus_point = Vector3(3.5, 0, 4.5)
	camera.distance = 13.0
	camera._apply_transform()
	assert_true(scene.has_method("board_hit_kind"), "right-click identifies actual pointer hit")
	if not scene.has_method("board_hit_kind"):
		viewport.free()
		return
	var actor: Variant = scene.get_unit_node(&"aurelia-1")
	scene.session.select_unit(&"aurelia-1")
	# Pointer resolution must not depend on team (neutral is a visual fixture).
	scene.get_unit_node(&"brann-1").team = &"neutral"
	for target_id: StringName in [&"fenn-1", &"blade-1", &"brann-1"]:
		scene.session.move_selected(Vector2i(2, 6))
		actor.position_animation.custom_step(1.0)
		await tree.physics_frame
		await tree.process_frame
		var pointer: Vector2 = camera.unproject_position(scene.get_unit_node(target_id).global_position)
		assert_equal(scene.board_hit_kind(pointer), &"unit", "friend/enemy/neutral collider identified as character")
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.pressed = true
		right.position = pointer
		viewport.push_input(right, true)
		await _frames(tree, 3)
		assert_true(scene.last_command_result.get("ok", false), "real right mouse event on character undoes selected mover")
		actor.position_animation.custom_step(1.0)
		assert_equal(actor.position, Vector3(1, 0.7, 7), "character right-click restores current actor rather than clicked unit")
		assert_equal(scene.session.selected_unit_id, &"aurelia-1", "right-click keeps mover selected")
	# Ray hits empty terrain and respects out-of-scene clicks.
	scene.session.move_selected(Vector2i(2, 6))
	actor.position_animation.custom_step(1.0)
	await tree.physics_frame
	await tree.process_frame
	var empty_pointer: Vector2 = camera.unproject_position(Vector3(4, 0.1, 7))
	assert_equal(scene.board_hit_kind(empty_pointer), &"cell", "empty terrain resolves to cell")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_RIGHT
	outside.pressed = true
	outside.position = Vector2(-1000, -1000)
	scene._unhandled_input(outside)
	assert_true(scene.session.can_undo_selected_move(), "outside click leaves pending move intact")
	var hud: Variant = scene.get_node("BattleHud")
	assert_true(hud.get_node("Layout/MoveStatus").text.contains("未提交"), "HUD explicitly identifies tentative move")
	scene._on_hud_command(&"attack")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = empty_pointer
	scene._unhandled_input(right)
	assert_equal(scene.interaction_mode, &"idle", "right-click both undoes and clears attack preview")
	actor.position_animation.custom_step(1.0)
	assert_equal(actor.position, Vector3(1, 0.7, 7), "terrain pointer returns mover")
	# Cancelling before movement finishes must still end at the original grid anchor.
	scene.session.move_selected(Vector2i(2, 6))
	assert_true(scene.handle_board_right_click(&"unit"), "in-flight movement can be cancelled")
	actor.position_animation.custom_step(1.0)
	assert_equal(actor.position, Vector3(1, 0.7, 7), "in-flight cancellation finishes at original anchor")
	# Occupied-origin refusal must not deselect or partially consume pending move.
	scene.session.move_selected(Vector2i(2, 6))
	actor.position_animation.custom_step(1.0)
	var blocker: Variant = scene.session._find_unit(&"brann-1")
	var old_cell := Vector2i(blocker.grid_position.x, blocker.grid_position.y)
	blocker.grid_position.x = 1
	blocker.grid_position.y = 7
	assert_true(not scene.handle_board_right_click(&"cell"), "occupied original cell rejects undo")
	assert_equal(scene.last_command_result.get("reason"), &"origin_occupied", "occupied origin reports refusal")
	assert_equal(scene.session.selected_unit_id, &"aurelia-1", "rejected undo preserves selection")
	assert_true(scene.session.can_undo_selected_move(), "rejected undo keeps pending state")
	blocker.grid_position.x = old_cell.x
	blocker.grid_position.y = old_cell.y
	assert_true(scene.handle_board_right_click(&"cell"), "undo works once original cell clears")
	actor.position_animation.custom_step(1.0)
	# The visible Wait button is the commit action; completion of travel alone is not.
	scene.session.move_selected(Vector2i(2, 6))
	actor.position_animation.custom_step(1.0)
	assert_true(not scene.session._find_unit(&"aurelia-1").acted, "travel completion never auto-waits")
	var wait_button: Button = hud.get_node("Layout/Commands/Wait")
	var wait_click := InputEventMouseButton.new()
	wait_click.button_index = MOUSE_BUTTON_LEFT
	wait_click.position = wait_button.get_global_rect().get_center()
	wait_click.pressed = true
	viewport.push_input(wait_click, true)
	await _frames(tree, 2)
	wait_click = wait_click.duplicate()
	wait_click.pressed = false
	viewport.push_input(wait_click, true)
	await _frames(tree, 2)
	assert_true(scene.session._find_unit(&"aurelia-1").acted, "clicking Wait commits unit")
	assert_true(hud.get_node("Layout/MoveStatus").text.contains("已完成"), "HUD identifies committed action before deselection")
	scene._unhandled_input(right)
	assert_equal(actor.position, Vector3(2, 0.7, 6), "committed move cannot be rolled back by terrain right-click")
	assert_true(not scene.session.can_undo_selected_move(), "committed move has no undo allowance")
	assert_true(hud.get_node_or_null("Layout/Commands/UndoMove") == null, "no duplicate undo button")
	viewport.free()


func _frames(tree: SceneTree, count: int) -> void:
	for i in count: await tree.process_frame
