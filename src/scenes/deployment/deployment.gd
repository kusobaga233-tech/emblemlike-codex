class_name DeploymentScreen
extends Control

signal deployment_confirmed(path: String, deployment: Array)
signal navigation_requested(path: String)

const BATTLE_PATH := "res://src/scenes/battle/battle_scene.tscn"
const TITLE_PATH := "res://src/scenes/title/title.tscn"

var last_navigation_request: String = ""
var _chapter: Variant
var _defaults: Array[Dictionary] = []
var _deployment: Array[Dictionary] = []
var _selected_slot: int = -1


func _ready() -> void:
	$Layout/Actions/Reset.pressed.connect(reset_defaults)
	$Layout/Actions/Confirm.pressed.connect(_confirm)
	_rebuild_cards()
	$Layout/Actions/Confirm.call_deferred("grab_focus")


func configure(chapter: Variant) -> void:
	_clear_selection()
	_chapter = chapter
	_defaults.clear()
	if chapter != null:
		for row: Dictionary in chapter.deployments:
			if StringName(row.get("team", &"")) == &"player":
				_defaults.append(row.duplicate(true))
	_defaults.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["instance_id"]) < String(b["instance_id"]))
	reset_defaults()


func get_deployment() -> Array:
	return _deployment.duplicate(true)


func swap_slots(first: int, second: int) -> bool:
	if first < 0 or second < 0 or first >= _deployment.size() or second >= _deployment.size() or first == second:
		return false
	var position: Vector2i = _deployment[first]["position"]
	_deployment[first]["position"] = _deployment[second]["position"]
	_deployment[second]["position"] = position
	_refresh_card_texts()
	return true


func reset_defaults() -> void:
	_clear_selection()
	_deployment = _defaults.duplicate(true)
	_rebuild_cards()


func _rebuild_cards() -> void:
	if not is_node_ready():
		return
	for child: Node in $Layout/UnitCards.get_children():
		child.free()
	for index: int in _deployment.size():
		var row: Dictionary = _deployment[index]
		var card := Button.new()
		card.name = "Unit%d" % (index + 1)
		card.text = "%s  (%d, %d)" % [row.get("instance_id", "Unit"), row["position"].x, row["position"].y]
		card.focus_mode = Control.FOCUS_ALL
		card.toggle_mode = true
		card.pressed.connect(_select_slot.bind(index))
		$Layout/UnitCards.add_child(card)


func _select_slot(index: int) -> void:
	if _selected_slot < 0:
		_selected_slot = index
		_set_selection_visual(index)
		return
	var first := _selected_slot
	_clear_selection()
	swap_slots(first, index)


func _clear_selection() -> void:
	_selected_slot = -1
	if not is_node_ready():
		return
	for child: Node in $Layout/UnitCards.get_children():
		if child is Button:
			(child as Button).button_pressed = false


func _set_selection_visual(index: int) -> void:
	for child_index: int in $Layout/UnitCards.get_child_count():
		var card := $Layout/UnitCards.get_child(child_index) as Button
		if card != null:
			card.button_pressed = child_index == index


func _refresh_card_texts() -> void:
	for index: int in mini(_deployment.size(), $Layout/UnitCards.get_child_count()):
		var row: Dictionary = _deployment[index]
		var card := $Layout/UnitCards.get_child(index) as Button
		if card != null:
			card.text = "%s  (%d, %d)" % [row.get("instance_id", "Unit"), row["position"].x, row["position"].y]


func _confirm() -> void:
	deployment_confirmed.emit(BATTLE_PATH, get_deployment())


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		last_navigation_request = TITLE_PATH
		navigation_requested.emit(TITLE_PATH)
		get_viewport().set_input_as_handled()
