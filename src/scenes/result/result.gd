class_name ResultScreen
extends Control

signal result_closed(action: StringName, path: String)

const BATTLE_PATH := "res://src/scenes/battle/battle_scene.tscn"
const DEPLOYMENT_PATH := "res://src/scenes/deployment/deployment.tscn"
const TITLE_PATH := "res://src/scenes/title/title.tscn"

var _summary: Dictionary = {}


func _ready() -> void:
	$Layout/Actions/Retry.pressed.connect(_close.bind(&"retry", BATTLE_PATH))
	$Layout/Actions/Redeploy.pressed.connect(_close.bind(&"redeploy", DEPLOYMENT_PATH))
	$Layout/Actions/Title.pressed.connect(_close.bind(&"title", TITLE_PATH))
	_refresh()
	$Layout/Actions/Retry.call_deferred("grab_focus")


func configure(summary: Dictionary) -> void:
	_summary = summary.duplicate(true)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var outcome := StringName(_summary.get("outcome", &"defeat"))
	$Layout/Outcome.text = "胜利" if outcome == &"victory" else "战斗失败"
	$Layout/Summary.text = "使用回合：%d\n存活单位：%d\n获得经验：%d" % [int(_summary.get("turns_used", 0)), int(_summary.get("surviving_units", 0)), int(_summary.get("experience_gained", 0))]


func _close(action: StringName, path: String) -> void:
	result_closed.emit(action, path)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_close(&"title", TITLE_PATH)
