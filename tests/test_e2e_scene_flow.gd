extends TestCase

const TITLE := "res://src/scenes/title/title.tscn"
const DEPLOYMENT := "res://src/scenes/deployment/deployment.tscn"
const BATTLE := "res://src/scenes/battle/battle_scene.tscn"
const RESULT := "res://src/scenes/result/result.tscn"


func run() -> void:
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_true(ResourceLoader.exists("res://src/scenes/flow_coordinator.gd"), "Persistent flow coordinator exists")
	var tree := Engine.get_main_loop() as SceneTree
	var original_viewport_size: Vector2i = tree.root.size
	var coordinator := tree.root.get_node_or_null("FlowCoordinator")
	assert_true(coordinator != null, "Flow coordinator is an autoload")
	if coordinator == null:
		return
	coordinator.start_flow()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, TITLE, "Boot flow starts at title")
	(tree.current_scene.get_node("Layout/Start") as Button).pressed.emit()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, DEPLOYMENT, "Start advances to deployment")
	Input.parse_input_event(_escape_event())
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, TITLE, "Deployment Escape returns through coordinator")
	(tree.current_scene.get_node("Layout/Start") as Button).pressed.emit()
	await _frames(3)
	var deployment := tree.current_scene
	var rows: Array = deployment.get_deployment()
	deployment.swap_slots(0, 1)
	var expected: Array = deployment.get_deployment()
	(deployment.get_node("Layout/Actions/Confirm") as Button).pressed.emit()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, BATTLE, "Confirm advances to battle")
	var battle := tree.current_scene
	assert_true(battle.session != null, "Battle receives a session")
	assert_equal(_player_deployment(battle.session), expected, "Confirmed deployment reaches BattleSession")
	assert_true(battle.get_node_or_null("BattleHud") != null, "Battle owns its HUD")
	assert_true(battle.get_node_or_null("CombatForecastPanel") != null, "Battle owns its forecast panel")
	tree.root.size = Vector2i(1280, 720)
	await _frames(2)
	var pointer_before: int = battle.pointer_input_count
	await _click_world(battle.get_unit_node(&"fenn-1").global_position)
	assert_true(battle.pointer_input_count > pointer_before, "Viewport mouse click reaches unit input_event")
	assert_equal(battle.session.selected_unit_id, &"fenn-1", "Clicking a player unit selects it")
	(battle.get_node("BattleHud/Layout/Commands/Move") as Button).pressed.emit()
	assert_equal(battle.interaction_mode, &"move", "Move button enters destination mode")
	var move_overlay_count: int = battle.get_node("GreyboxBoard/MoveOverlay").get_child_count()
	await _click_world(battle.get_unit_node(&"brann-1").global_position)
	assert_equal(battle.session.selected_unit_id, &"fenn-1", "Move mode rejects clicking another unit")
	assert_equal(battle.interaction_mode, &"move", "Rejected unit click preserves move mode")
	assert_equal(battle.get_node("GreyboxBoard/MoveOverlay").get_child_count(), move_overlay_count, "Rejected unit click preserves move overlay")
	await _click_world(Vector3(0.0, 0.1, 8.0))
	var moved_fenn: Variant = _unit(battle.session, &"fenn-1")
	assert_equal(Vector2i(moved_fenn.grid_position.x, moved_fenn.grid_position.y), Vector2i(0, 8), "Board move reaches the session")
	await _click_world(battle.get_unit_node(&"fenn-1").global_position)
	assert_equal(battle.session.selected_unit_id, &"fenn-1", "Moved unit can be reselected")
	(battle.get_node("BattleHud/Layout/Commands/Wait") as Button).pressed.emit()
	assert_true(_unit(battle.session, &"fenn-1").acted, "Wait button uses legal session wait")
	var round_before: int = battle.session.turn_state.round
	(battle.get_node("BattleHud/Layout/Commands/EndPhase") as Button).pressed.emit()
	await _frames(4)
	assert_equal(battle.session.turn_state.phase, &"player", "End Phase completes deferred enemy AI")
	assert_equal(battle.session.turn_state.round, round_before + 1, "End Phase returns on the next round")
	var captain: Variant = _unit(battle.session, &"captain-1")
	captain.current_hp = 1
	captain.grid_position.x = 0
	captain.grid_position.y = 6
	_unit(battle.session, &"fenn-1").definition.hit = 100
	tree.root.size = Vector2i(720, 1280)
	await _frames(2)
	var portrait_hud_width := (battle.get_node("BattleHud/Backdrop") as Control).size.x
	assert_true(portrait_hud_width <= 324.0, "Portrait HUD uses no more than 45 percent of viewport width")
	assert_true((battle.get_node("BattleHud/Layout") as Control).size.x <= portrait_hud_width, "Portrait HUD content stays inside its compact backdrop")
	var portrait_camera := battle.get_node("TacticalCamera") as Camera3D
	assert_true(portrait_camera.get("framing_mode") == &"overview", "Portrait play exposes the interaction-safe overview")
	var captain_screen := portrait_camera.unproject_position(battle.get_unit_node(&"captain-1").global_position)
	assert_true(captain_screen.x > portrait_hud_width and captain_screen.x < 720.0, "Portrait enemy target projects into usable play area outside HUD")
	var reset_key := InputEventKey.new()
	reset_key.keycode = KEY_R
	reset_key.pressed = true
	Input.parse_input_event(reset_key)
	await _frames(1)
	assert_true(portrait_camera.get("framing_mode") == &"overview", "Portrait keyboard reset remains interactive")
	await _click_world(battle.get_unit_node(&"fenn-1").global_position)
	(battle.get_node("BattleHud/Layout/Commands/Attack") as Button).pressed.emit()
	await _move_pointer_world(battle.get_unit_node(&"captain-1").global_position)
	assert_true(battle.get_node("CombatForecastPanel").visible, "Forecast panel is visible for legal target")
	await _move_pointer_world(Vector3(7.0, 0.1, 9.0))
	assert_true(not battle.get_node("CombatForecastPanel").visible, "Hovering empty terrain clears stale forecast")
	assert_equal(battle.pending_target_id, &"", "Hovering empty terrain clears pending target")
	assert_equal(battle.get_node("CombatForecastPanel/Layout/Damage").text, "", "Cleared forecast has no stale labels")
	await _move_pointer_world(battle.get_unit_node(&"captain-1").global_position)
	assert_true(battle.get_node("CombatForecastPanel").visible, "Returning hover restores legal forecast")
	await _click_world(battle.get_unit_node(&"captain-1").global_position)
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, RESULT, "Terminal battle advances to result")
	assert_equal(coordinator.result_summary["outcome"], &"victory", "Coordinator retains result summary")
	(tree.current_scene.get_node("Layout/Actions/Retry") as Button).pressed.emit()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, BATTLE, "Retry creates a fresh battle")
	coordinator.show_result({"outcome": &"defeat", "turns_used": 2, "surviving_units": 0, "experience_gained": 0})
	await _frames(3)
	(tree.current_scene.get_node("Layout/Actions/Redeploy") as Button).pressed.emit()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, DEPLOYMENT, "Redeploy returns to deployment")
	coordinator.show_result({"outcome": &"defeat"})
	await _frames(3)
	(tree.current_scene.get_node("Layout/Actions/Title") as Button).pressed.emit()
	await _frames(3)
	assert_equal(tree.current_scene.scene_file_path, TITLE, "Title action returns to title")
	tree.root.size = original_viewport_size
	tree.current_scene.queue_free()
	await _frames(3)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphan_baseline, "E2E cleanup returns orphan nodes to baseline")


func _player_deployment(session: Variant) -> Array:
	var rows: Array = []
	for unit: Variant in session.units:
		if unit.definition.team == &"player":
			rows.append({"instance_id": unit.instance_id, "position": Vector2i(unit.grid_position.x, unit.grid_position.y), "team": &"player", "unit_id": unit.definition.id})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["instance_id"]) < String(b["instance_id"]))
	return rows


func _unit(session: Variant, id: StringName) -> Variant:
	for unit: Variant in session.units:
		if unit.instance_id == id:
			return unit
	return null


func _escape_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for unused: int in count:
		await (Engine.get_main_loop() as SceneTree).process_frame


func _click_world(world_position: Vector3) -> void:
	var camera := ((Engine.get_main_loop() as SceneTree).current_scene.get_node("TacticalCamera") as Camera3D)
	var screen := camera.unproject_position(world_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	Input.parse_input_event(press)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await (Engine.get_main_loop() as SceneTree).process_frame


func _move_pointer_world(world_position: Vector3) -> void:
	var camera := ((Engine.get_main_loop() as SceneTree).current_scene.get_node("TacticalCamera") as Camera3D)
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(world_position)
	Input.parse_input_event(motion)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
