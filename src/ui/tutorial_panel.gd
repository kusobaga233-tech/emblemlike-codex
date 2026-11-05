class_name TutorialPanel
extends Control

signal skip_requested

const CARD_MAX_WIDTH := 520.0
const SCREEN_MARGIN := 16.0
const BOTTOM_MARGIN := 20.0


func _ready() -> void:
	$Card/Layout/Header/Skip.pressed.connect(func() -> void: skip_requested.emit())
	get_viewport().size_changed.connect(_place)
	_place()


func show_step(step: Dictionary, number: int, total: int, extra: String = "") -> void:
	if step.is_empty():
		clear()
		return
	$Card/Layout/Header/Step.text = "教学 %d / %d" % [number, total]
	$Card/Layout/Header/Title.text = String(step.get("title", ""))
	$Card/Layout/Instruction.text = String(step.get("instruction", ""))
	$Card/Layout/Hint.text = "提示：" + String(step.get("hint", "")) if not String(step.get("hint", "")).is_empty() else ""
	$Card/Layout/Extra.text = extra
	$Card/Layout/Extra.visible = not extra.is_empty()
	visible = true
	$Card.reset_size()
	_place.call_deferred()


func clear() -> void:
	visible = false
	$Card/Layout/Extra.visible = false


func _place() -> void:
	if not is_node_ready() or not visible:
		return
	var viewport_size := get_viewport_rect().size
	var card_width := minf(CARD_MAX_WIDTH, maxf(240.0, viewport_size.x - SCREEN_MARGIN * 2.0))
	$Card.custom_minimum_size.x = card_width
	$Card.reset_size()
	var card_size: Vector2 = ($Card as Control).size
	$Card.position = Vector2(
		maxf(SCREEN_MARGIN, (viewport_size.x - card_size.x) * 0.5),
		maxf(SCREEN_MARGIN, viewport_size.y - card_size.y - BOTTOM_MARGIN),
	)
