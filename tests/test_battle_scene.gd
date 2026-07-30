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
	_test_battle_scene_smoke_signal_isolation_ownership_and_cleanup()


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
		assert_true((child as MeshInstance3D).mesh is BoxMesh, "Every terrain cell uses BoxMesh")

	_assert_terrain_color(terrain_root, &"bridge", Color("586579"))
	_assert_terrain_color(terrain_root, &"forest", Color("377a4a"))
	_assert_terrain_color(terrain_root, &"water", Color("286aa6"))
	_assert_terrain_color(terrain_root, &"crystal", Color("7952b3"))

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
	player.configure(player_state)
	enemy.configure(enemy_state)

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

	var before_state: Dictionary = _session_snapshot(session)
	player.play_event({
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(1, 8), "to": Vector2i(4, 5)},
	})
	assert_equal(player.position, Vector3(4.0, 0.7, 5.0), "Move event updates only the presentation position")
	player.play_event({
		"type": &"damage_applied",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"amount": 6, "remaining_hp": 12},
	})
	assert_equal(player.visual_hp, 12, "Damage event updates visual HP")
	assert_true(player.get_node("HpBar/Fill").scale.x > 0.0, "Damage event keeps a visible proportional HP fill")
	player.play_event({
		"type": &"phase_changed",
		"actor_id": &"",
		"target_id": &"",
		"payload": {"from": &"player", "to": &"enemy"},
	})
	assert_equal(player.last_phase, &"enemy", "Phase event is handled visually")
	player.play_event({
		"type": &"unit_defeated",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"remaining_hp": 0},
	})
	assert_true(not player.visible, "Defeat event hides the defeated presentation node")
	assert_equal(_session_snapshot(session), before_state, "Direct event playback cannot mutate BattleSession")
	player.free()
	enemy.free()


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


func _test_battle_scene_smoke_signal_isolation_ownership_and_cleanup() -> void:
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

	assert_equal(scene.get_node("GreyboxBoard/Terrain").get_child_count(), 80, "Battle scene owns eighty board cells")
	assert_equal(scene.get_node("Units").get_child_count(), 7, "Battle scene owns seven unit nodes")
	assert_equal(_count_type(scene, Camera3D), 1, "Battle scene has exactly one Camera3D")
	assert_equal(_count_type(scene, DirectionalLight3D), 1, "Battle scene has exactly one DirectionalLight3D")
	assert_true(scene.get_node("TacticalCamera").current, "Battle camera is active")
	_assert_descendant_owners(scene, scene)

	var fenn: Node3D = scene.get_unit_node(&"fenn-1")
	var before_state := _session_snapshot(session)
	var events: Array[Dictionary] = [{
		"type": &"unit_moved",
		"actor_id": &"fenn-1",
		"target_id": &"",
		"payload": {"from": Vector2i(1, 8), "to": Vector2i(2, 5)},
	}, {
		"type": &"damage_applied",
		"actor_id": &"blade-1",
		"target_id": &"fenn-1",
		"payload": {"amount": 4, "remaining_hp": 20},
	}, {
		"type": &"phase_changed",
		"actor_id": &"",
		"target_id": &"",
		"payload": {"from": &"player", "to": &"enemy"},
	}]
	session.events_flushed.emit(events)
	assert_equal(fenn.position, Vector3(2.0, 0.7, 5.0), "Scene consumes flushed move events")
	assert_equal(fenn.visual_hp, 20, "Scene consumes flushed damage events")
	assert_equal(fenn.last_phase, &"enemy", "Scene consumes flushed phase events")
	assert_equal(_session_snapshot(session), before_state, "Scene event consumption leaves the session snapshot identical")

	var scene_weak: WeakRef = weakref(scene)
	scene.free()
	assert_true(scene_weak.get_ref() == null, "Freeing the scene releases the scene root immediately")


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
