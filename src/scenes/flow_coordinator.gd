class_name FlowCoordinatorNode
extends Node

const TITLE := "res://src/scenes/title/title.tscn"
const DEPLOYMENT := "res://src/scenes/deployment/deployment.tscn"
const BATTLE := "res://src/scenes/battle/battle_scene.tscn"
const RESULT := "res://src/scenes/result/result.tscn"

var chapter: ChapterDefinition
var confirmed_deployment: Array = []
var battle_session: BattleSession
var result_summary: Dictionary = {}
var _transitioning: bool = false


func start_flow() -> void:
	chapter = ChapterOne.build()
	confirmed_deployment.clear()
	result_summary.clear()
	_request_scene(TITLE)


func show_result(summary: Dictionary) -> void:
	result_summary = summary.duplicate(true)
	_request_scene(RESULT)


func _request_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_switch_scene.call_deferred(path)


func _switch_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_transitioning = false
		return
	await get_tree().scene_changed
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != path:
		_transitioning = false
		return
	_configure_scene(scene, path)
	_transitioning = false


func _configure_scene(scene: Node, path: String) -> void:
	match path:
		TITLE:
			_connect_once(scene.start_pressed, _on_start_pressed)
		DEPLOYMENT:
			scene.configure(chapter)
			_connect_once(scene.deployment_confirmed, _on_deployment_confirmed)
			_connect_once(scene.navigation_requested, _on_deployment_navigation_requested)
		BATTLE:
			if battle_session == null:
				battle_session = BattleSession.new(_deployed_chapter())
			scene.setup_battle(battle_session.chapter, battle_session)
			_connect_once(scene.result_requested, _on_battle_result_requested)
		RESULT:
			scene.configure(result_summary)
			_connect_once(scene.result_closed, _on_result_closed)


func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)


func _on_start_pressed(_path: String) -> void:
	_request_scene(DEPLOYMENT)


func _on_deployment_confirmed(_path: String, rows: Array) -> void:
	confirmed_deployment = rows.duplicate(true)
	battle_session = BattleSession.new(_deployed_chapter())
	_request_scene(BATTLE)


func _on_deployment_navigation_requested(path: String) -> void:
	if path == TITLE:
		_request_scene(TITLE)


func _on_battle_result_requested(_path: String, summary: Dictionary) -> void:
	show_result(summary)


func _on_result_closed(action: StringName, _path: String) -> void:
	match action:
		&"retry":
			battle_session = BattleSession.new(_deployed_chapter())
			_request_scene(BATTLE)
		&"redeploy":
			_request_scene(DEPLOYMENT)
		&"title":
			start_flow()


func _deployed_chapter() -> ChapterDefinition:
	var deployed := chapter.deep_duplicate()
	for replacement: Dictionary in confirmed_deployment:
		for row: Dictionary in deployed.deployments:
			if row.get("instance_id") == replacement.get("instance_id"):
				row["position"] = replacement.get("position")
	return deployed
