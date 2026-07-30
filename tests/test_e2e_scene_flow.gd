extends TestCase

const TITLE := "res://src/scenes/title/title.tscn"
const DEPLOYMENT := "res://src/scenes/deployment/deployment.tscn"
const BATTLE := "res://src/scenes/battle/battle_scene.tscn"
const RESULT := "res://src/scenes/result/result.tscn"


func run() -> void:
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_true(ResourceLoader.exists("res://src/scenes/flow_coordinator.gd"), "Persistent flow coordinator exists")
	var tree := Engine.get_main_loop() as SceneTree
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
	var selected_before: StringName = battle.session.selected_unit_id
	battle.get_node("BattleHud").command_selected.emit({"type": &"select", "unit_id": &"fenn-1"})
	assert_true(battle.session.selected_unit_id != selected_before, "HUD command changes session state")
	battle.session.events_flushed.emit(_terminal_events(&"victory"))
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


func _terminal_events(outcome: StringName) -> Array[Dictionary]:
	return [{"type": &"battle_status_changed", "actor_id": &"", "target_id": &"", "payload": {"from": &"ongoing", "to": outcome}}]


func _frames(count: int) -> void:
	for unused: int in count:
		await (Engine.get_main_loop() as SceneTree).process_frame
