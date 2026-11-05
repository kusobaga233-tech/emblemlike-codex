class_name BattleHud
extends Control

signal command_selected(command: StringName)
signal result_requested(path: String, summary: Dictionary)
signal threat_toggled(enabled: bool)

const RESULT_PATH := "res://src/scenes/result/result.tscn"
const DEFAULT_WIDTH := 388.0
const PORTRAIT_WIDTH_RATIO := 0.42
const COMPACT_MAX_WIDTH := 300.0

var presentation_driven := false
var _input_locked := false
var _displayed_hp: Dictionary = {}
var _session: Variant
var _result_was_requested: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_update_responsive_layout)
	for button: Button in [$Layout/Commands/Move, $Layout/Commands/Attack, $Layout/Commands/Support, $Layout/Commands/Resonance, $Layout/Commands/Wait, $Layout/Commands/EndPhase]:
		button.pressed.connect(_emit_command.bind(StringName(button.name.to_snake_case())))
	$Layout/Threat.toggled.connect(_on_threat_toggled)
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
		_displayed_hp.clear()
		_input_locked = false
		if is_node_ready(): $Layout/Feedback.text = ""
		for unit: Variant in session.units:
			_displayed_hp[unit.instance_id] = unit.current_hp
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
	var forecast := get_parent().get_node_or_null("CombatForecastPanel")
	if forecast is Control:
		forecast.position.x = panel_width + 12.0
	var inspection := get_parent().get_node_or_null("EnemyInspectionPanel")
	if inspection is Control:
		inspection.position.x = panel_width + 12.0
	$Layout/Feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Layout/MoveStatus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _emit_command(command: StringName) -> void:
	command_selected.emit(command)


func _on_threat_toggled(enabled: bool) -> void:
	_update_threat_text(enabled)
	threat_toggled.emit(enabled)


func set_threat_enabled(enabled: bool) -> void:
	if is_node_ready():
		$Layout/Threat.set_pressed_no_signal(enabled)
		_update_threat_text(enabled)


func _update_threat_text(enabled: bool) -> void:
	if is_node_ready():
		$Layout/Threat.text = "威胁范围：开" if enabled else "威胁范围：关"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		command_selected.emit(&"cancel")
		get_viewport().set_input_as_handled()


func _on_events_flushed(events: Array[Dictionary]) -> void:
	if not presentation_driven:
		present_events(events)


func present_events(events: Array[Dictionary]) -> void:
	for event in events:
		if StringName(event.get("type", &"")) in [&"damage_applied", &"unit_healed", &"unit_defeated"]:
			_displayed_hp[StringName(event.get("target_id", &""))] = event.get("payload", {}).get("remaining_hp", 0)
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
	$Layout/Objective.text = _objective_text(chapter)
	$Layout/Turn.text = _turn_text(chapter)
	$Layout/Phase.text = "阶段：%s" % _phase_text(_session.turn_state.phase)
	$Layout/Resonance.text = "星誓共鸣：%d%%" % _resonance_value()
	var selected: Variant = _find_unit(_session.selected_unit_id)
	$Layout/SelectedUnit.text = "当前单位：未选择" if selected == null else "当前单位：%s  生命 %d/%d" % [selected.definition.display_name, int(_displayed_hp.get(selected.instance_id, selected.current_hp)), selected.definition.max_hp]
	if selected == null:
		$Layout/MoveStatus.text = "选择角色后移动；右键取消未提交移动"
	elif selected.acted:
		$Layout/MoveStatus.text = "行动已完成，本回合不可撤销"
	elif _session.can_undo_selected_move():
		$Layout/MoveStatus.text = "移动未提交：右键取消，点击待机提交"
	else:
		$Layout/MoveStatus.text = "尚未行动：选择移动或攻击"

	var ready: bool = selected != null and selected.current_hp > 0 and selected.definition.team == &"player" and not selected.acted and _session.battle_status == &"ongoing" and _session.turn_state.phase == &"player" and not _input_locked
	$Layout/Commands/Move.disabled = not ready or (selected != null and selected.has_moved)
	$Layout/Commands/Attack.disabled = not ready
	$Layout/Commands/Wait.disabled = not ready
	$Layout/Commands/Support.visible = selected != null and selected.definition.id == &"elio"
	$Layout/Commands/Support.disabled = not ready
	$Layout/Commands/Resonance.visible = selected != null and selected.definition.id == &"aurelia"
	$Layout/Commands/Resonance.disabled = not ready or _resonance_value() != 100
	$Layout/Commands/EndPhase.disabled = _input_locked or _session.battle_status != &"ongoing" or _session.turn_state.phase != &"player"


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	_refresh()


func show_feedback(message: String) -> void:
	$Layout/Feedback.text = message


func show_command_result(result: Dictionary) -> void:
	if result.get("ok", false):
		show_feedback("")
		return
	var messages := {
		&"full_hp": "该友军生命已满，无需治疗", &"not_healer": "只有艾利欧可以治疗", &"out_of_range": "目标不在行动范围内",
		&"invalid_target": "请选择相邻、存活且受伤的友军", &"not_enemy": "攻击需要选择敌军", &"no_ready_selection": "请先选择尚未行动的我方角色",
		&"no_selection": "请先选择角色", &"unit_acted": "该角色本回合已行动", &"already_moved": "已移动，右键可撤销未提交移动",
		&"occupied": "目标地块已被占据", &"origin_occupied": "原格已被占据，无法撤销", &"wrong_phase": "请等待我方阶段",
		&"presentation_busy": "正在播放行动，请稍候", &"battle_over": "战斗已经结束", &"no_support_target": "请先选择治疗目标", &"no_attack_target": "请先点击锁定攻击目标",
		&"not_resonance_leader": "只有奥蕾莉亚可以发动星誓共鸣", &"insufficient_resonance": "星誓共鸣尚未达到 100%",
		&"no_partner": "需要相邻且未行动的友军作为共鸣伙伴", &"invalid_partner": "请选择相邻、存活且未行动的友军",
		&"no_resonance_target": "请先选择共鸣目标"
	}
	show_feedback(String(messages.get(StringName(result.get("reason", &"")), "当前操作不可用")))


func _objective_text(chapter: Variant) -> String:
	var lines: Array[String] = []
	lines.append("胜利条件：" + _victory_text(chapter))
	var failure := _failure_text(chapter)
	if not failure.is_empty():
		lines.append("失败条件：" + failure)
	return "\n".join(lines)


func _victory_text(chapter: Variant) -> String:
	if chapter == null or chapter.objectives.is_empty():
		return "击败所有敌人"
	var parts: Array[String] = []
	for objective: Dictionary in chapter.objectives:
		parts.append(_condition_text(objective, true))
	return "；".join(parts)


func _failure_text(chapter: Variant) -> String:
	if chapter == null or chapter.failure_conditions.is_empty():
		return ""
	var parts: Array[String] = []
	for condition: Dictionary in chapter.failure_conditions:
		parts.append(_condition_text(condition, false))
	return "；".join(parts)


func _condition_text(condition: Dictionary, show_progress: bool) -> String:
	var condition_type := StringName(condition.get("type", &""))
	if condition_type != &"unit_defeated":
		return String(condition.get("description", "完成本章目标"))
	var target: Variant = _find_unit(StringName(condition.get("target_id", &"")))
	if target == null:
		return String(condition.get("description", "目标单位"))
	var display_name := String(target.definition.display_name)
	if show_progress:
		return "击败%s（%d/1）" % [display_name, 1 if target.current_hp <= 0 else 0]
	return "%s阵亡" % display_name


func _turn_text(chapter: Variant) -> String:
	var limit := 0 if chapter == null else int(chapter.turn_limit)
	if limit > 0:
		return "回合：%d / %d" % [_session.turn_state.round, limit]
	return "回合：%d" % _session.turn_state.round


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
