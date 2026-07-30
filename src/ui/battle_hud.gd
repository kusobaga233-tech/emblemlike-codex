class_name BattleHud
extends Control

signal command_selected(command: StringName)
signal result_requested(path: String, summary: Dictionary)

const RESULT_PATH := "res://src/scenes/result/result.tscn"

var _session: Variant
var _result_was_requested: bool = false


func _ready() -> void:
	for button: Button in [$Layout/Commands/Move, $Layout/Commands/Attack, $Layout/Commands/Wait, $Layout/Commands/EndPhase]:
		button.pressed.connect(_emit_command.bind(StringName(button.name.to_snake_case())))
	$Layout/Commands/Move.call_deferred("grab_focus")
	_refresh()


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
	if _session != null and _session.events_flushed.is_connected(_on_events_flushed):
		_session.events_flushed.disconnect(_on_events_flushed)


func _emit_command(command: StringName) -> void:
	command_selected.emit(command)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		command_selected.emit(&"cancel")
		get_viewport().set_input_as_handled()


func _on_events_flushed(events: Array[Dictionary]) -> void:
	_refresh()
	for event: Dictionary in events:
		if StringName(event.get("type", &"")) == &"battle_status_changed" and not _result_was_requested:
			_result_was_requested = true
			result_requested.emit(RESULT_PATH, _build_summary(StringName(event.get("payload", {}).get("to", &"defeat"))))


func _refresh() -> void:
	if not is_node_ready() or _session == null:
		return
	var chapter: Variant = _session.chapter
	$Layout/Objective.text = "Objective: %s" % _objective_text(chapter)
	$Layout/Turn.text = "Turn: %d" % _session.turn_state.round
	$Layout/Phase.text = "Phase: %s" % _session.turn_state.phase
	$Layout/Resonance.text = "Resonance: %d" % _resonance_value()
	var selected: Variant = _find_unit(_session.selected_unit_id)
	$Layout/SelectedUnit.text = "Selected: None" if selected == null else "Selected: %s  HP %d/%d" % [selected.definition.display_name, selected.current_hp, selected.definition.max_hp]


func _objective_text(chapter: Variant) -> String:
	if chapter == null or chapter.objectives.is_empty():
		return "Defeat all enemies"
	return String(chapter.objectives[0].get("description", chapter.objectives[0].get("type", "Defeat all enemies")))


func _resonance_value() -> int:
	if _session.turn_state != null and "resonance" in _session.turn_state:
		return int(_session.turn_state.resonance)
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
