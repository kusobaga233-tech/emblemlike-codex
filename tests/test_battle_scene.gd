extends TestCase

const BOARD_PATH := "res://src/presentation/greybox_board.gd"
const UNIT_PATH := "res://src/presentation/greybox_unit.gd"
const CAMERA_PATH := "res://src/presentation/tactical_camera.gd"
const BATTLE_SCENE_PATH := "res://src/scenes/battle/battle_scene.tscn"
const CHAPTER_ONE_PATH := "res://src/content/chapter_one.gd"
const BATTLE_SESSION_PATH := "res://src/tactics/battle_session.gd"

var _board_script: Script
var _unit_script: Script
var _camera_script: Script
var _chapter_one_script: Script
var _battle_session_script: Script


func run() -> void:
	_board_script = load(BOARD_PATH) as Script
	_unit_script = load(UNIT_PATH) as Script
	_camera_script = load(CAMERA_PATH) as Script
	_chapter_one_script = load(CHAPTER_ONE_PATH) as Script
	_battle_session_script = load(BATTLE_SESSION_PATH) as Script
	assert_true(_board_script != null, "GreyboxBoard script loads")
	assert_true(_unit_script != null, "GreyboxUnit script loads")
	assert_true(_camera_script != null, "TacticalCamera script loads")
	assert_true(_chapter_one_script != null, "ChapterOne script loads")
	assert_true(_battle_session_script != null, "BattleSession script loads")
	assert_true(ResourceLoader.exists(BATTLE_SCENE_PATH), "Battle scene exists")
	if (
		_board_script == null
		or _unit_script == null
		or _camera_script == null
		or _chapter_one_script == null
		or _battle_session_script == null
		or not ResourceLoader.exists(BATTLE_SCENE_PATH)
	):
		return

	_test_board_build_palette_rebuild_and_overlays()
	_test_unit_primitives_selection_hp_and_event_playback()
	_test_tactical_camera_reset_focus_orbit_and_zoom_clamps()
	_test_tactical_camera_projects_every_board_corner_at_clamp_extremes()
	await _test_battle_scene_smoke_signal_isolation_ownership_and_cleanup()


func _test_board_build_palette_rebuild_and_overlays() -> void:
	var chapter: Variant = _chapter_one_script.build()
	var board: Node3D = _board_script.new()
	board.build(chapter)
	var terrain_root := board.get_node_or_null("Terrain")
	assert_true(terrain_root != null, "Board creates a terrain root")
	if terrain_root == null:
		board.free()
		return
	assert_equal(terrain_root.get_child_count(), 80, "Chapter one builds exactly eighty cells")
	for child: Node in terrain_root.get_children():
		assert_true(child is MeshInstance3D, "Every terrain cell is a MeshInstance3D")
		assert_true(not ((child as MeshInstance3D).mesh is BoxMesh), "Every terrain cell uses an imported environment mesh")
		assert_true(child.get_node_or_null("PickArea/CollisionShape3D") is CollisionShape3D, "Every terrain cell owns a physics pick shape")

	assert_true(board.get_node("EnvironmentDecor").get_child_count() > 0, "Board builds collision-free observatory decor")

	var old_cell_weak: WeakRef = weakref(terrain_root.get_child(0))
	board.build(chapter)
	terrain_root = board.get_node("Terrain")
	assert_equal(terrain_root.get_child_count(), 80, "Repeated board build does not accumulate cells")
	assert_true(old_cell_weak.get_ref() == null, "Repeated board build frees old cells")

	board.show_move_cells([Vector2i(1, 2), Vector2i(2, 2)])
	assert_equal(board.get_node("MoveOverlay").get_child_count(), 2, "Move overlay shows requested cells")
	board.show_move_cells([Vector2i(3, 4)])
	assert_equal(board.get_node("MoveOverlay").get_child_count(), 1, "Move overlay replacement is stable")
	board.show_move_cells([])
	assert_equal(board.get_node("MoveOverlay").get_child_count(), 0, "Empty move overlay clears nodes")
	board.show_attack_cells([Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)])
	assert_equal(board.get_node("AttackOverlay").get_child_count(), 3, "Attack overlay shows requested cells")
	board.show_attack_cells([])
	assert_equal(board.get_node("AttackOverlay").get_child_count(), 0, "Empty attack overlay clears nodes")
	board.free()


func _test_unit_primitives_selection_hp_and_event_playback() -> void:
	var session: Variant = _battle_session_script.new(_chapter_one_script.build(), 71)
	var player_state: Variant = _unit_state(session, &"fenn-1")
	var enemy_state: Variant = _unit_state(session, &"blade-1")
	var player: Node3D = _unit_script.new()
	var enemy: Node3D = _unit_script.new()
	var animation_root := Node3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(animation_root)
	animation_root.add_child(player)
	animation_root.add_child(enemy)
	player.configure(player_state)
	enemy.configure(enemy_state)
	assert_true(player.get_node_or_null("PickArea/CollisionShape3D") is CollisionShape3D, "Player unit owns a physics pick shape")

	assert_true(player.get_node("Body").mesh is CapsuleMesh, "Player unit uses CapsuleMesh")
	assert_true(enemy.get_node("Body").mesh is CylinderMesh, "Enemy unit uses CylinderMesh")
	assert_equal(_material_color(player.get_node("Body")), Color("245fa8"), "Player body uses blue palette")
	assert_equal(_material_color(player.get_node("SelectionOutline")), Color("d5ad38"), "Player outline uses gold palette")
	assert_equal(_material_color(enemy.get_node("Body")), Color("9f2942"), "Enemy body uses crimson palette")
	assert_true(player.get_node("HpBar/Fill").material_override.albedo_texture == null, "HP bar uses no texture")
	assert_true(player.get_node("SelectionOutline").material_override.albedo_texture == null, "Selection outline uses no texture")

	player.set_selected(true)
	assert_true(player.get_node("SelectionOutline").visible, "Selection outline can be shown")
	player.set_selected(false)
	assert_true(not player.get_node("SelectionOutline").visible, "Selection outline can be hidden")
	var supports_deterministic_animation := (
		_has_property(player, &"active_animation")
		and _has_property(player, &"animation_kind")
		and _has_property(player, &"phase_visual_energy")
		and _has_property(player, &"position_animation")
		and _has_property(player, &"body_animation")
		and _has_property(player, &"phase_animation")
		and _has_property(player, &"defeat_animation")
	)
	assert_true(
		supports_deterministic_animation,
		"GreyboxUnit exposes deterministic Tween animation state",
	)
	if not supports_deterministic_animation:
		animation_root.free()
		return

	var before_state: Dictionary = _session_snapshot(session)
	var move_origin := player.position
	player.play_event({
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(1, 8), "to": Vector2i(4, 5)},
	})
	assert_equal(player.get("animation_kind"), &"move", "Move event starts the move Tween")
	assert_equal(player.position, move_origin, "Move Tween begins at the current presentation position")
	var move_tween := _animation_tween(player, &"position_animation")
	assert_true(move_tween != null and move_tween.is_valid(), "Move event owns a valid headless Tween")
	if move_tween != null:
		move_tween.custom_step(1.0)
	assert_equal(player.position, Vector3(4.0, 0.7, 5.0), "Move event updates only the presentation position")
	player.play_event({
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(4, 5), "to": Vector2i(5, 5)},
	})
	player.play_event({
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(5, 5), "to": Vector2i(6, 5)},
	})
	assert_equal(player.position, Vector3(5.0, 0.7, 5.0), "Replacing a move Tween commits its prior target first")
	move_tween = _animation_tween(player, &"position_animation")
	if move_tween != null:
		move_tween.custom_step(1.0)
	assert_equal(player.position, Vector3(6.0, 0.7, 5.0), "Repeated move events finish at the newest target")
	player.play_event({
		"type": &"damage_applied",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"amount": 6, "remaining_hp": 12},
	})
	assert_equal(player.visual_hp, 12, "Damage event updates visual HP")
	assert_true(player.get_node("HpBar/Fill").scale.x > 0.0, "Damage event keeps a visible proportional HP fill")
	assert_equal(player.get("animation_kind"), &"damage", "Damage event starts the damage Tween")
	var body := player.get_node("Body") as MeshInstance3D
	assert_true(body.scale != Vector3.ONE, "Damage Tween begins from a visible squash pose")
	var damage_tween := _animation_tween(player, &"body_animation")
	assert_true(damage_tween != null and damage_tween.is_valid(), "Damage event owns a valid headless Tween")
	if damage_tween != null:
		damage_tween.custom_step(1.0)
	assert_equal(body.scale, Vector3.ONE, "Damage Tween deterministically restores body scale")
	player.play_event({
		"type": &"phase_changed",
		"actor_id": &"",
		"target_id": &"",
		"payload": {"from": &"player", "to": &"enemy"},
	})
	assert_equal(player.last_phase, &"enemy", "Phase event is handled visually")
	assert_equal(player.get("animation_kind"), &"phase_visual_changed", "Phase event starts its visual Tween")
	var phase_tween := _animation_tween(player, &"phase_animation")
	assert_true(phase_tween != null and phase_tween.is_valid(), "Phase event owns a valid headless Tween")
	if phase_tween != null:
		phase_tween.custom_step(1.0)
	assert_true(float(player.get("phase_visual_energy")) > 0.0, "Phase Tween reaches a visible emission energy")
	player.play_event({
		"type": &"unit_defeated",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"remaining_hp": 0},
	})
	assert_equal(player.get("animation_kind"), &"defeat", "Defeat event starts the defeat Tween")
	assert_true(player.visible, "Defeat Tween keeps the unit visible at animation start")
	var defeat_tween := _animation_tween(player, &"defeat_animation")
	assert_true(defeat_tween != null and defeat_tween.is_valid(), "Defeat event owns a valid headless Tween")
	if defeat_tween != null:
		defeat_tween.custom_step(1.0)
	assert_true(not player.visible, "Defeat event hides the defeated presentation node")
	assert_equal(_session_snapshot(session), before_state, "Direct event playback cannot mutate BattleSession")
	animation_root.free()


func _test_tactical_camera_reset_focus_orbit_and_zoom_clamps() -> void:
	var camera: Camera3D = _camera_script.new()
	camera.configure_board(8, 10)
	assert_equal(camera.pitch_degrees, 40.0, "Camera starts at a forty degree tactical angle")
	assert_equal(camera.focus_point, Vector3(3.5, 0.0, 4.5), "Camera resets to the board center")
	var reset_distance: float = camera.distance
	assert_true(reset_distance >= camera.min_distance and reset_distance <= camera.max_distance, "Reset frames the board inside zoom clamps")

	camera.focus(Vector3(-20.0, 0.0, 50.0))
	assert_equal(camera.focus_point, Vector3(0.0, 0.0, 9.0), "Focus clamps to board bounds")
	camera.orbit(Vector2(10000.0, 10000.0))
	assert_true(camera.pitch_degrees >= camera.min_pitch_degrees, "Orbit cannot invert below the board")
	assert_true(camera.pitch_degrees <= camera.max_pitch_degrees, "Orbit cannot invert above the board")
	camera.zoom(10000.0)
	assert_equal(camera.distance, camera.max_distance, "Zoom out cannot lose the board")
	camera.zoom(-10000.0)
	assert_equal(camera.distance, camera.min_distance, "Zoom in respects the near clamp")
	camera.reset_view()
	assert_equal(camera.pitch_degrees, 40.0, "Reset restores tactical pitch")
	assert_equal(camera.focus_point, Vector3(3.5, 0.0, 4.5), "Reset restores board center")
	camera.free()


func _test_tactical_camera_projects_every_board_corner_at_clamp_extremes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		tree.root.add_child(viewport)
		var camera: Camera3D = _camera_script.new()
		viewport.add_child(camera)
		camera.current = true
		camera.configure_board(8, 10)
		var configured_min_distance: float = camera.min_distance
		assert_true(configured_min_distance > 6.0, "Safe minimum distance is derived from board projection")
		for yaw: float in [-180.0, -90.0, -45.0, 0.0, 45.0, 90.0, 180.0]:
			for pitch: float in [camera.min_pitch_degrees, camera.max_pitch_degrees]:
				_set_camera_angles(camera, yaw, pitch)
				camera.zoom(-10000.0)
				_assert_board_corners_visible(camera, viewport_size, "center yaw %.0f pitch %.0f" % [yaw, pitch])
		camera.focus(Vector3(0.0, 0.0, 0.0))
		assert_true(camera.min_distance > configured_min_distance, "Corner focus expands the safe minimum distance")
		for yaw: float in [-135.0, 45.0]:
			for pitch: float in [camera.min_pitch_degrees, camera.max_pitch_degrees]:
				_set_camera_angles(camera, yaw, pitch)
				camera.zoom(-10000.0)
				_assert_board_corners_visible(camera, viewport_size, "corner yaw %.0f pitch %.0f" % [yaw, pitch])
		camera.fov = 42.0
		camera.configure_board(8, 10)
		assert_true(camera.min_distance > configured_min_distance, "Narrower FOV expands the safe minimum distance")
		_set_camera_angles(camera, 45.0, camera.max_pitch_degrees)
		camera.zoom(-10000.0)
		_assert_board_corners_visible(camera, viewport_size, "narrow FOV clamp extreme")
		viewport.free()


func _test_battle_scene_smoke_signal_isolation_ownership_and_cleanup() -> void:
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var packed_scene := load(BATTLE_SCENE_PATH) as PackedScene
	assert_true(packed_scene != null, "Battle scene parses and loads")
	if packed_scene == null:
		return
	var chapter: Variant = _chapter_one_script.build()
	var session: Variant = _battle_session_script.new(chapter, 97)
	var scene: Node3D = packed_scene.instantiate()
	scene.setup_battle(chapter, session)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame

	assert_equal(scene.get_node("GreyboxBoard/Terrain").get_child_count(), 80, "Battle scene owns eighty board cells")
	assert_equal(scene.get_node("Units").get_child_count(), 7, "Battle scene owns seven unit nodes")
	assert_true(scene.get_node("Units/aurelia-1/ProductionVisual") != null, "Aurelia uses the imported hero production visual")
	assert_true(scene.get_node("Units/captain-1/ProductionVisual") != null, "Bridge captain uses the imported boss production visual")
	var aurelia_visual := scene.get_node("Units/aurelia-1")
	assert_true(aurelia_visual.get("production_animation_player") is AnimationPlayer, "Aurelia exposes its imported AnimationPlayer")
	if aurelia_visual.get("production_animation_player") is AnimationPlayer:
		assert_equal(aurelia_visual.get("production_animation_player").current_animation, "idle", "Production visual starts in idle")
	assert_equal(_count_type(scene, Camera3D), 1, "Battle scene has exactly one Camera3D")
	assert_equal(_count_type(scene, DirectionalLight3D), 1, "Battle scene has exactly one DirectionalLight3D")
	var world_environment := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert_true(world_environment != null, "Battle scene has a production WorldEnvironment")
	if world_environment != null:
		assert_true(world_environment.environment != null, "Production WorldEnvironment owns an Environment resource")
		assert_true(world_environment.environment.ambient_light_energy > 0.0, "Production environment supplies ambient fill light")
	assert_true(scene.get_node("TacticalCamera").current, "Battle camera is active")
	assert_true(scene.get_node_or_null("BattleHud/Backdrop") is Panel, "Battle HUD uses a production panel backdrop")
	assert_true(scene.get_node("BattleHud/Layout/Commands/Move").custom_minimum_size.y >= 44.0, "Battle commands meet the minimum pointer target height")
	assert_equal(scene.get_node("BattleHud/Layout/Commands/Move").text, "移动", "Move command is localized")
	assert_equal(scene.get_node("BattleHud/Layout/Commands/Attack").text, "攻击", "Attack command is localized")
	assert_true(scene.get_node_or_null("CombatForecastPanel/Layout/Title") is Label, "Combat forecast has a production title")
	var battle_audio := scene.get_node_or_null("BattleAudio")
	assert_true(battle_audio != null, "Battle scene has an event-driven audio layer")
	if battle_audio != null:
		assert_equal(battle_audio.cue_for_event(&"unit_selected"), &"ui_select", "Selection maps to a stable audio cue")
	_assert_descendant_owners(scene, scene)

	var fenn: Node3D = scene.get_unit_node(&"fenn-1")
	var before_state := _session_snapshot(session)
	var move_phase_events: Array[Dictionary] = [{
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(1, 8), "to": Vector2i(2, 5)},
	}, {
		"type": &"phase_changed",
		"actor_id": &"",
		"target_id": &"",
		"payload": {"from": &"player", "to": &"enemy"},
	}]
	session.events_flushed.emit(move_phase_events)
	assert_true(_has_property(fenn, &"position_animation"), "Move and phase use independent Tween channels")
	assert_true(_has_property(fenn, &"phase_animation"), "Phase visual has its own Tween channel")
	_step_animation_channels(fenn, [&"position_animation", &"phase_animation"])
	assert_equal(fenn.position, Vector3(2.0, 0.7, 5.0), "Same-batch move and phase finish at the move target")
	assert_equal(fenn.last_phase, &"enemy", "Same-batch move and phase keep the phase visual")

	var damage_events: Array[Dictionary] = [{
		"type": &"damage_applied",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"amount": 4, "remaining_hp": 20},
	}]
	session.events_flushed.emit(damage_events)
	_step_animation_channels(fenn, [&"body_animation"])
	assert_equal(fenn.visual_hp, 20, "Scene consumes flushed damage events")

	var blade: Node3D = scene.get_unit_node(&"blade-1")
	var defeat_phase_events: Array[Dictionary] = [{
		"type": &"unit_defeated",
		"actor_id": &"fenn-1",
		"target_id": &"blade-1",
		"payload": {"remaining_hp": 0},
	}, {
		"type": &"phase_changed",
		"actor_id": &"",
		"target_id": &"",
		"payload": {"from": &"enemy", "to": &"player"},
	}]
	session.events_flushed.emit(defeat_phase_events)
	assert_true(_has_property(blade, &"defeat_animation"), "Defeat has an independent Tween channel")
	_step_animation_channels(blade, [&"defeat_animation", &"phase_animation"])
	assert_equal(blade.visual_hp, 0, "Same-batch defeat commits zero visual HP")
	assert_true(not blade.visible, "Same-batch defeat and phase finish hidden")
	assert_equal(blade.scale, Vector3(1.08, 0.08, 1.08), "Defeat Tween commits its terminal scale")
	assert_equal(blade.last_phase, &"player", "Same-batch defeat and phase keep the phase visual")
	assert_equal(_session_snapshot(session), before_state, "Scene event consumption leaves the session snapshot identical")

	var scene_weak: WeakRef = weakref(scene)
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	assert_true(scene_weak.get_ref() == null, "Queued scene cleanup releases the scene root")
	assert_equal(
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		orphan_baseline,
		"Battle scene cleanup returns orphan node count to baseline",
	)


func _assert_terrain_color(terrain_root: Node, terrain_id: StringName, expected: Color) -> void:
	for child: Node in terrain_root.get_children():
		if child.get_meta("terrain_id", &"") != terrain_id:
			continue
		assert_equal(_material_color(child), expected, "%s terrain palette" % terrain_id)
		return
	assert_true(false, "%s terrain exists" % terrain_id)


func _material_color(mesh_instance: MeshInstance3D) -> Color:
	var material := mesh_instance.material_override as StandardMaterial3D
	return material.albedo_color if material != null else Color.TRANSPARENT


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


func _animation_tween(unit: Node3D, property_name: StringName) -> Tween:
	if _has_property(unit, property_name):
		return unit.get(property_name) as Tween
	return unit.get("active_animation") as Tween


func _step_animation_channels(unit: Node3D, channel_names: Array[StringName]) -> void:
	var stepped: Dictionary = {}
	for channel_name: StringName in channel_names:
		var tween := _animation_tween(unit, channel_name)
		if tween == null or not tween.is_valid():
			continue
		var tween_id := tween.get_instance_id()
		if stepped.has(tween_id):
			continue
		stepped[tween_id] = true
		tween.custom_step(1.0)


func _set_camera_angles(camera: Camera3D, yaw: float, pitch: float) -> void:
	camera.orbit(Vector2(
		(yaw - camera.yaw_degrees) / camera.orbit_sensitivity,
		(pitch - camera.pitch_degrees) / camera.orbit_sensitivity,
	))


func _assert_board_corners_visible(camera: Camera3D, viewport_size: Vector2i, label: String) -> void:
	var corners := [
		Vector3(-0.5, 0.0, -0.5),
		Vector3(7.5, 0.0, -0.5),
		Vector3(-0.5, 0.0, 9.5),
		Vector3(7.5, 0.0, 9.5),
	]
	for corner: Vector3 in corners:
		assert_true(not camera.is_position_behind(corner), "%s keeps corner in front" % label)
		var screen := camera.unproject_position(corner)
		assert_true(screen.x >= 0.0 and screen.x <= viewport_size.x, "%s keeps corner inside viewport width" % label)
		assert_true(screen.y >= 0.0 and screen.y <= viewport_size.y, "%s keeps corner inside viewport height" % label)


func _unit_state(session: Variant, instance_id: StringName) -> Variant:
	for unit_value: Variant in session.units:
		if unit_value.instance_id == instance_id:
			return unit_value
	return null


func _session_snapshot(session: Variant) -> Dictionary:
	var unit_rows: Array = []
	for unit_value: Variant in session.units:
		unit_rows.append({
			"id": unit_value.instance_id,
			"position": Vector2i(unit_value.grid_position.x, unit_value.grid_position.y),
			"hp": unit_value.current_hp,
			"acted": unit_value.acted,
		})
	return {
		"units": unit_rows,
		"selected": session.selected_unit_id,
		"phase": session.turn_state.phase,
		"round": session.turn_state.round,
		"status": session.battle_status,
		"queue": session.event_queue.duplicate(true),
	}


func _count_type(root: Node, expected_type: Variant) -> int:
	var result := 1 if is_instance_of(root, expected_type) else 0
	for child: Node in root.get_children():
		result += _count_type(child, expected_type)
	return result


func _assert_descendant_owners(root: Node, expected_owner: Node) -> void:
	for child: Node in root.get_children():
		assert_equal(child.owner, expected_owner, "%s is owned by the battle scene" % child.name)
		_assert_descendant_owners(child, expected_owner)
