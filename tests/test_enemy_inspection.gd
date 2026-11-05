extends TestCase

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.physics_object_picking = true
	tree.root.add_child(viewport)
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var panel: Variant = scene.get_node_or_null("EnemyInspectionPanel")
	assert_true(panel != null, "battle has read-only enemy inspection card")
	if panel == null:
		viewport.free()
		return
	assert_true(not panel.visible, "card hidden before enemy hover")
	var session: Variant = scene.session
	var blade: Variant = session._find_unit(&"blade-1")
	var bow: Variant = session._find_unit(&"bow-1")
	session.select_unit(&"aurelia-1")
	session.move_selected(Vector2i(2, 6))
	scene.get_unit_node(&"aurelia-1").position_animation.custom_step(1.0)
	var before := _snapshot(session)
	scene._on_unit_hovered(&"blade-1")
	assert_true(panel.visible, "idle enemy hover opens attributes")
	assert_equal(panel.get_node("Layout/Title").text, "空誓剑士 · 敌军", "card identifies enemy name and team")
	assert_true(panel.get_node("Layout/Role").text.contains(blade.definition.role), "role comes from definition")
	assert_equal(panel.get_node("Layout/Health").text, "生命：18 / 18", "visible HP and maximum displayed")
	assert_true(panel.get_node("Layout/Offense").text.contains("8") and panel.get_node("Layout/Offense").text.contains("物理"), "attack and damage type displayed")
	assert_equal(panel.get_node("Layout/Defense").text, "防御：3    抗性：2", "defense and resistance displayed")
	assert_equal(panel.get_node("Layout/Mobility").text, "移动：3 格    射程：1 格", "melee movement and range displayed")
	assert_equal(_snapshot(session), before, "inspection never changes selection/action/grid/HP/resonance/events")
	assert_true(session.can_undo_selected_move(), "inspection preserves pending movement")
	scene._on_unit_hovered(&"bow-1")
	scene._on_unit_hover_exited(&"blade-1")
	assert_true(panel.visible and panel.get_node("Layout/Title").text.contains("弓手"), "late previous enemy exit cannot close new enemy card")
	assert_true(panel.get_node("Layout/Mobility").text.contains("2、3"), "discrete bow ranges preserved rather than continuous invented range")
	assert_equal(panel.get_node("Layout/Accuracy").text, "基础命中：82%    暴击：3%", "accuracy shows base definition values")
	bow.acted = true
	scene._on_unit_hovered(&"bow-1")
	assert_true(panel.get_node("Layout/Action").text.contains("已行动"), "spent enemy state displayed")
	bow.acted = false
	scene._on_unit_hovered(&"fenn-1")
	assert_true(not panel.visible, "friendly hover clears enemy card")
	scene._on_unit_hovered(&"blade-1")
	scene._on_cell_hovered(Vector2i(3, 6))
	assert_true(not panel.visible, "empty terrain clears enemy card")
	scene._on_unit_hovered(&"blade-1")
	scene._on_unit_hover_exited(&"blade-1")
	assert_true(not panel.visible, "leaving current enemy closes card")
	# Inspection can coexist with movement destination selection, not action confirmation.
	assert_true(scene.handle_board_right_click(&"unit"), "inspection never intercepts right-click undo")
	scene.get_unit_node(&"aurelia-1").position_animation.custom_step(1.0)
	scene._on_hud_command(&"move")
	var overlays: int = scene.get_node("GreyboxBoard/MoveOverlay").get_child_count()
	scene._on_unit_hovered(&"blade-1")
	assert_true(panel.visible and scene.interaction_mode == &"move", "hover while choosing destination retains move mode")
	assert_equal(scene.get_node("GreyboxBoard/MoveOverlay").get_child_count(), overlays, "hover does not replace move overlays")
	assert_equal(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "inspection is noninteractive")
	scene._on_hud_command(&"attack")
	scene._on_unit_hovered(&"blade-1")
	assert_true(not panel.visible, "attack mode owns prediction slot")
	scene.cancel_interaction()
	scene.session.select_unit(&"elio-1")
	scene._on_hud_command(&"support")
	scene._on_unit_hovered(&"blade-1")
	assert_true(not panel.visible and scene.interaction_mode == &"support", "enemy inspection cannot replace healing interaction")
	scene.cancel_interaction()
	# A clicked attack target owns the side slot until explicit cancel/confirm.
	session.select_unit(&"fenn-1")
	blade.grid_position.x = 0
	blade.grid_position.y = 6
	scene._on_hud_command(&"attack")
	scene.handle_board_pick(&"unit", &"blade-1")
	scene._on_unit_hovered(&"bow-1")
	assert_true(not panel.visible and scene.get_node("CombatForecastPanel").visible, "locked attack confirmation wins over inspection")
	assert_equal(scene.pending_target_id, &"blade-1", "enemy hover does not replace locked attack target")
	scene._on_hud_command(&"cancel")
	blade.grid_position.x = 5
	blade.grid_position.y = 5
	# A selected healing preview also owns the side slot.
	session.select_unit(&"elio-1")
	var friend: Variant = session._find_unit(&"aurelia-1")
	friend.grid_position.x = 3
	friend.grid_position.y = 7
	friend.current_hp -= 3
	scene._on_hud_command(&"support")
	scene.handle_board_pick(&"unit", &"aurelia-1")
	scene._on_unit_hovered(&"bow-1")
	assert_true(not panel.visible and scene.get_node("CombatForecastPanel").visible, "healing confirmation wins over enemy card")
	assert_equal(scene.pending_target_id, &"aurelia-1", "inspection preserves healing target")
	scene.cancel_interaction()
	# Use visible HP, not future rule HP, and keep values read-only.
	blade.current_hp = 5
	scene._on_unit_hovered(&"blade-1")
	assert_true(panel.get_node("Layout/Health").text.contains("18 / 18"), "card reads presented HP rather than future rule HP")
	var presenter: Variant = scene.get_node("SpriteCombatPresentation")
	presenter.set_process(false)
	scene.session.events_flushed.emit([
		{"type": &"attack_started", "actor_id": &"blade-1", "target_id": &"aurelia-1"},
		{"type": &"attack_finished", "actor_id": &"blade-1", "target_id": &"aurelia-1"},
	] as Array[Dictionary])
	assert_true(not panel.visible, "starting timeline clears inspection immediately")
	scene._on_unit_hovered(&"bow-1")
	assert_true(not panel.visible, "timeline suppresses hover card")
	presenter.advance(2.0)
	blade.current_hp = 18
	scene._on_unit_hovered(&"blade-1")
	scene._present_event({"type": &"damage_applied", "actor_id": &"fenn-1", "target_id": &"blade-1", "payload": {"remaining_hp": 10, "amount": 8}})
	assert_equal(panel.get_node("Layout/Health").text, "生命：10 / 18", "visible damage event refreshes hovered attributes")
	scene._present_event({"type": &"unit_defeated", "actor_id": &"fenn-1", "target_id": &"blade-1", "payload": {"remaining_hp": 0}})
	assert_true(not panel.visible, "defeated visual immediately clears card")
	scene._on_unit_hovered(&"bow-1")
	scene._on_inspection_window_exited()
	assert_true(not panel.visible, "leaving game window hides inspection")
	scene._on_unit_hovered(&"bow-1")
	scene.setup_battle(scene.chapter)
	assert_true(not panel.visible, "battle rebuild removes stale inspection data")
	await _test_pointer(tree, scene, viewport)
	viewport.free()

func _snapshot(session: Variant) -> String:
	return str([session.selected_unit_id, session.turn_state.phase, session.turn_state.round, session.resonance_value(), session.event_queue, session.units.map(func(u: Variant): return [u.instance_id, u.current_hp, u.acted, u.has_moved, u.grid_position.x, u.grid_position.y])])

func _test_pointer(tree: SceneTree, scene: Node3D, viewport: SubViewport) -> void:
	var camera: Variant = scene.get_node("TacticalCamera")
	camera.controls_enabled = false
	camera.set_process(false)
	camera.focus_point = Vector3(3.5, 0, 4.5)
	camera.yaw_degrees = 0.0
	camera._target_yaw_degrees = 0.0
	camera.distance = 13.0
	camera._apply_transform()
	viewport.notify_mouse_entered()
	await tree.physics_frame
	await tree.process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(scene.get_unit_node(&"blade-1").global_position)
	viewport.push_input(motion, true)
	await tree.physics_frame
	await tree.process_frame
	assert_true(scene.get_node("EnemyInspectionPanel").visible, "actual mouse motion enters enemy PickArea and opens card")
	assert_true(scene.get_node("EnemyInspectionPanel").position.x >= scene.get_node("BattleHud/Backdrop").size.x + 10, "inspection positioned outside HUD")
	motion = InputEventMouseMotion.new()
	motion.position = camera.unproject_position(Vector3(7, 0.1, 9))
	viewport.push_input(motion, true)
	await tree.physics_frame
	await tree.process_frame
	assert_true(not scene.get_node("EnemyInspectionPanel").visible, "actual mouse motion to terrain closes card")
