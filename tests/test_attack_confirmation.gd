extends TestCase

func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var scene: Variant = load("res://src/scenes/battle/battle_scene.tscn").instantiate()
	viewport.add_child(scene)
	var panel: Variant = scene.get_node("CombatForecastPanel")
	assert_true(panel.has_signal("attack_confirmed"), "panel exposes explicit attack confirmation")
	if not panel.has_signal("attack_confirmed"):
		viewport.free()
		return
	var session: Variant = scene.session
	var actor: Variant = session._find_unit(&"fenn-1")
	var target: Variant = session._find_unit(&"blade-1")
	var other: Variant = session._find_unit(&"bow-1")
	target.grid_position.x = 2
	target.grid_position.y = 7
	other.grid_position.x = 1
	other.grid_position.y = 6
	actor.definition.hit = 100
	actor.definition.critical = 0
	var old_hp: int = target.current_hp
	var timeline: Variant = scene.get_node("SpriteCombatPresentation")
	timeline.set_process(false)
	session.select_unit(&"fenn-1")
	session.move_selected(Vector2i(0, 7))
	scene.get_unit_node(&"fenn-1").position_animation.custom_step(1.0)
	scene._on_hud_command(&"attack")
	assert_true(scene.handle_board_hover(&"blade-1"), "hover previews a legal enemy")
	assert_true(not panel.get_node("Layout/Actions").visible, "hover alone cannot confirm an attack")
	assert_equal(target.current_hp, old_hp, "hover does not damage enemy")
	scene.handle_board_pick(&"unit", &"blade-1")
	assert_true(panel.get_node("Layout/Actions").visible, "click locks enemy and exposes confirmation")
	assert_equal(panel.get_node("Layout/Actions/Confirm").text, "确认攻击", "attack confirmation clearly distinguished from heal")
	assert_true(panel.get_node("Layout/Title").text.contains(target.definition.display_name), "selected enemy named in confirmation")
	assert_true(panel.get_node("Layout/Notice").text.contains("命中"), "prediction explains outcome uncertainty")
	scene.handle_board_pick(&"unit", &"blade-1")
	assert_equal(target.current_hp, old_hp, "repeat target click never commits damage")
	assert_true(not actor.acted and not timeline.is_busy(), "double click neither spends action nor starts presentation")
	scene._on_cell_hovered(Vector2i(4, 4))
	scene._on_unit_hover_exited(&"blade-1")
	scene.handle_board_hover(&"bow-1")
	assert_true(panel.visible and scene.pending_target_id == &"blade-1", "locked target survives pointer travel over other objects")
	# Stale selected target must be rejected on confirm, never consume action.
	target.grid_position.x = 7
	panel.get_node("Layout/Actions/Confirm").pressed.emit()
	assert_equal(scene.last_command_result.get("reason"), &"out_of_range", "explicit confirm revalidates changed distance")
	assert_true(not actor.acted and target.current_hp == old_hp, "stale confirmation is a rule-state no-op")
	assert_true(not panel.visible, "rejected confirmation clears stale target UI")
	target.grid_position.x = 2
	scene.handle_board_pick(&"unit", &"blade-1")
	scene.handle_board_pick(&"unit", &"bow-1")
	assert_equal(scene.pending_target_id, &"bow-1", "explicit click switches locked target")
	panel.get_node("Layout/Actions/Cancel").pressed.emit()
	assert_true(not panel.visible and not actor.acted, "cancel keeps action available")
	assert_equal(session.selected_unit_id, &"fenn-1", "cancel retains attacker selection")
	# Right-click retains precedence over locked previews while move is pending.
	scene._on_hud_command(&"attack")
	scene.handle_board_pick(&"unit", &"blade-1")
	assert_true(scene.handle_board_right_click(&"unit"), "right click undoes pending move during locked confirmation")
	scene.get_unit_node(&"fenn-1").position_animation.custom_step(1.0)
	assert_true(not actor.has_moved and not panel.visible, "undo clears selected target and restores move allowance")
	session.move_selected(Vector2i(0, 7))
	scene.get_unit_node(&"fenn-1").position_animation.custom_step(1.0)
	scene._on_hud_command(&"attack")
	scene.handle_board_pick(&"unit", &"blade-1")
	await tree.process_frame
	await _click(viewport, panel.get_node("Layout/Actions/Confirm"))
	assert_true(target.current_hp < old_hp and actor.acted and timeline.is_busy(), "actual mouse confirm commits exactly one attack")
	var after_hp: int = target.current_hp
	assert_equal(scene.get_unit_node(&"blade-1").visual_hp, old_hp, "logical damage not shown until impact cue")
	panel.get_node("Layout/Actions/Confirm").pressed.emit()
	assert_equal(target.current_hp, after_hp, "duplicate confirm cannot deal extra damage")
	assert_true(scene.get_node("BattleHud/Layout/Commands/Attack").disabled, "attack playback disables HUD")
	timeline.advance(2.0)
	assert_equal(scene.get_unit_node(&"blade-1").visual_hp, after_hp, "confirmed attack uses impact-time visible HP")
	assert_true(not scene.handle_board_right_click(&"cell") and target.current_hp == after_hp, "right click never rolls back resolved damage")
	# Shared confirmation panel must not retain its previous action route.
	var healer: Variant = session._find_unit(&"elio-1")
	var friend: Variant = session._find_unit(&"aurelia-1")
	friend.grid_position.x = 3
	friend.grid_position.y = 7
	friend.current_hp -= 2
	session.select_unit(&"elio-1")
	scene._on_hud_command(&"support")
	scene.handle_board_pick(&"unit", &"aurelia-1")
	assert_equal(panel.get_node("Layout/Actions/Confirm").text, "确认治疗", "attack-to-heal switch resets button type")
	var friend_hp: int = friend.current_hp
	panel.get_node("Layout/Actions/Cancel").pressed.emit()
	panel.get_node("Layout/Actions/Confirm").pressed.emit()
	assert_equal(friend.current_hp, friend_hp, "hidden confirmation cannot heal stale target")
	assert_true(not healer.acted, "cancelling switched preview does not consume healer")
	viewport.free()

func _click(viewport: SubViewport, button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)
	await (Engine.get_main_loop() as SceneTree).process_frame
