class_name BattleHud
extends Control

signal command_selected(command: StringName)
signal result_requested(path: String, summary: Dictionary)

const RESULT_PATH := "res://src/scenes/result/result.tscn"
const DEFAULT_WIDTH := 388.0
const PORTRAIT_WIDTH_RATIO := 0.42
const COMPACT_MAX_WIDTH := 300.0

var _session: Variant
var _result_was_requested: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_update_responsive_layout)
	for button: Button in [$Layout/Commands/Move, $Layout/Commands/Attack, $Layout/Commands/Wait, $Layout/Commands/EndPhase]:
		button.pressed.connect(_emit_command.bind(StringName(button.name.to_snake_case())))
	$Layout/Commands/Move.call_deferred("grab_focus")
	_refresh()
	_update_responsive_layout()


func configure(session: Variant) -> void:
	var session_changed: bool = _session != session
	if _session != null and _session.events_flushed.is_connected(_on_events_flushed):
		_session.events_flushed.disconnect(_on_events_flushed)
	_session = session
	if session_changed:
		_result_was_requested = false
	if _session != null and not _session.events_flushed.is_connected(_on_events_flushed):
		_session.events_flushed.connect(_on_events_flushed)
	_refresh()


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_update_responsive_layout):
		get_viewport().size_changed.disconnect(_update_responsive_layout)
	if _session != null and _session.events_flushed.is_connected(_on_events_flushed):
		_session.events_flushed.disconnect(_on_events_flushed)


func _update_responsive_layout() -> void:
	if not is_node_ready():
		return
	var viewport_width := get_viewport_rect().size.x
	var compact := viewport_width < 900.0
	var panel_width := minf(DEFAULT_WIDTH, minf(COMPACT_MAX_WIDTH, viewport_width * PORTRAIT_WIDTH_RATIO)) if compact else DEFAULT_WIDTH
	$Backdrop.offset_right = panel_width
	$Layout.offset_right = panel_width - 18.0
	$Layout/Objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Layout/SelectedUnit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _emit_command(command: StringName) -> void:
	command_selected.emit(command)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		command_selected.emit(&"cancel")
		get_viewport().set_input_as_handled()


func _on_events_flushed(events: Array[Dictionary]) -> void:
	_refresh()
	for event: Dictionary in events:
		if StringName(event.get("type", &"")) != &"battle_status_changed":
			continue
		var outcome_value: Variant = event.get("payload", {}).get("to", &"")
		if not outcome_value is String and not outcome_value is StringName:
			continue
		var outcome: StringName = outcome_value
		if outcome in [&"victory", &"defeat"] and not _result_was_requested:
			_result_was_requested = true
			result_requested.emit(RESULT_PATH, _build_summary(outcome))


func _refresh() -> void:
	if not is_node_ready() or _session == null:
		return
	var chapter: Variant = _session.chapter
	$Layout/Objective.text = "胜利条件：%s" % _objective_text(chapter)
	$Layout/Turn.text = "回合：%d" % _session.turn_state.round
	$Layout/Phase.text = "阶段：%s" % _phase_text(_session.turn_state.phase)
	$Layout/Resonance.text = "星誓共鸣：%d%%" % _resonance_value()
	var selected: Variant = _find_unit(_session.selected_unit_id)
	$Layout/SelectedUnit.text = "当前单位：未选择" if selected == null else "当前单位：%s  生命 %d/%d" % [selected.definition.display_name, selected.current_hp, selected.definition.max_hp]


func _objective_text(chapter: Variant) -> String:
	if chapter == null or chapter.objectives.is_empty():
		return "击败所有敌人"
	var objective: Dictionary = chapter.objectives[0]
	if StringName(objective.get("type", &"")) == &"unit_defeated":
		var target: Variant = _find_unit(StringName(objective.get("target_id", &"")))
		if target != null:
			return "击败%s" % target.definition.display_name
	return String(objective.get("description", "完成本章目标"))


func _phase_text(phase: StringName) -> String:
	return "我方行动" if phase == &"player" else "敌方行动"


func _resonance_value() -> int:
	if _session.has_method("resonance_value"):
		return int(_session.resonance_value())
	return 0


func _find_unit(id: StringName) -> Variant:
	for unit: Variant in _session.units:
		if unit.instance_id == id:
			return unit
	return null


func _build_summary(outcome: StringName) -> Dictionary:
	var survivors := 0
	for unit: Variant in _session.units:
		if unit.definition.team == &"player" and unit.current_hp > 0:
			survivors += 1
	return {"outcome": outcome, "turns_used": _session.turn_state.round, "surviving_units": survivors, "experience_gained": 0}
