class_name BattleScene
extends Node3D

const BATTLE_SESSION_SCRIPT := preload("res://src/tactics/battle_session.gd")
const CHAPTER_ONE_SCRIPT := preload("res://src/content/chapter_one.gd")
const GREYBOX_UNIT_SCRIPT := preload("res://src/presentation/greybox_unit.gd")
const COMBAT_VFX_DIRECTOR_SCRIPT := preload("res://src/presentation/combat_vfx_director.gd")

var chapter: Variant
var session: Variant
var _configured: bool = false
var last_command_result: Dictionary = {}
var interaction_mode: StringName = &"idle"
var pending_target_id: StringName = &""
var _phase_advancing: bool = false
var pointer_input_count: int = 0

signal result_requested(path: String, summary: Dictionary)

func _exit_tree() -> void:
	_disconnect_session()
	var director := get_node_or_null("CombatVfxDirector")
	if director != null:
		director.clear_active_presentations()


func _ready() -> void:
	if not _configured:
		setup_battle(CHAPTER_ONE_SCRIPT.build())


func setup_battle(initial_chapter: Variant, injected_session: Variant = null) -> void:
	_disconnect_session()
	var director := get_node_or_null("CombatVfxDirector")
	if director == null:
		director = COMBAT_VFX_DIRECTOR_SCRIPT.new()
		director.name = "CombatVfxDirector"
		add_child(director)
		director.owner = self
	var impact_callable := Callable(self, "_on_camera_impact_requested")
	if not director.camera_impact_requested.is_connected(impact_callable):
		director.camera_impact_requested.connect(impact_callable)
	director.clear_active_presentations()
	chapter = initial_chapter
	session = injected_session
	if session == null:
		session = BATTLE_SESSION_SCRIPT.new(initial_chapter)
	var presentation_chapter: Variant = session.chapter if session.chapter != null else initial_chapter
	get_node("GreyboxBoard").build(presentation_chapter)
	_clear_units()
	for unit_state: Variant in session.units:
		var unit := GREYBOX_UNIT_SCRIPT.new() as Node3D
		unit.name = String(unit_state.instance_id)
		unit.configure(unit_state)
		get_node("Units").add_child(unit)
		unit.picked.connect(_on_unit_picked)
		unit.hovered.connect(_on_unit_hovered)
		unit.hover_exited.connect(_on_unit_hover_exited)
		_assign_owner_recursive(unit)
	get_node("TacticalCamera").configure_board(
		int(presentation_chapter.width),
		int(presentation_chapter.height),
	)
	director.set_board_center(Vector3(
		float(presentation_chapter.width - 1) * 0.5,
		0.0,
		float(presentation_chapter.height - 1) * 0.5,
	))
	var allied_positions: Array[Vector3] = []
	for unit_state: Variant in session.units:
		if unit_state.definition.team == &"player":
			allied_positions.append(get_unit_node(unit_state.instance_id).position)
	get_node("TacticalCamera").frame_group(allied_positions)
	var event_callable := Callable(self, "_on_events_flushed")
	if not session.events_flushed.is_connected(event_callable):
		session.events_flushed.connect(event_callable)
	get_node("BattleHud").configure(session)
	var command_callable := Callable(self, "_on_hud_command")
	if not get_node("BattleHud").command_selected.is_connected(command_callable):
		get_node("BattleHud").command_selected.connect(command_callable)
	var result_callable := Callable(self, "_on_hud_result_requested")
	if not get_node("BattleHud").result_requested.is_connected(result_callable):
		get_node("BattleHud").result_requested.connect(result_callable)
	get_node("CombatForecastPanel").show_forecast(null)
	var board_pick_callable := Callable(self, "_on_cell_picked")
	if not get_node("GreyboxBoard").cell_picked.is_connected(board_pick_callable):
		get_node("GreyboxBoard").cell_picked.connect(board_pick_callable)
	var board_hover_callable := Callable(self, "_on_cell_hovered")
	if not get_node("GreyboxBoard").cell_hovered.is_connected(board_hover_callable):
		get_node("GreyboxBoard").cell_hovered.connect(board_hover_callable)
	_assign_owner_recursive(get_node("BattleHud"))
	_assign_owner_recursive(get_node("CombatForecastPanel"))
	_configured = true


func get_unit_node(instance_id: StringName) -> Node3D:
	return get_node_or_null("Units/%s" % String(instance_id)) as Node3D


func set_combat_vfx_quality_tier(tier: StringName) -> void:
	get_node("CombatVfxDirector").set_quality_tier(tier)


func combat_vfx_metrics() -> Dictionary:
	return get_node("CombatVfxDirector").metrics()


func reset_combat_vfx_metrics() -> void:
	get_node("CombatVfxDirector").reset_metrics()


func capture_combat_vfx_frame(event: Dictionary, output_path: String) -> Error:
	get_node("CombatVfxDirector").play_events([event] as Array[Dictionary])
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	return image.save_png(absolute_path)


func handle_board_pick(kind: StringName, value: Variant) -> bool:
	if session == null or session.battle_status != &"ongoing" or _phase_advancing:
		return false
	if kind == &"cell" and value is Vector2i and interaction_mode == &"move":
		last_command_result = session.move_selected(value)
		if last_command_result.get("ok", false):
			cancel_interaction()
			return true
		return false
	if interaction_mode == &"move" and kind == &"unit":
		return false
	if kind != &"unit" or not value is StringName:
		return false
	var unit_id: StringName = value
	if interaction_mode == &"attack":
		if pending_target_id != unit_id:
			return handle_board_hover(unit_id)
		last_command_result = session.confirm_attack(unit_id)
		if last_command_result.get("ok", false):
			cancel_interaction()
			return true
		return false
	last_command_result = session.select_unit(unit_id)
	return bool(last_command_result.get("ok", false))


func handle_board_hover(unit_id: StringName) -> bool:
	if interaction_mode != &"attack" or session == null:
		return false
	last_command_result = session.forecast_attack(unit_id)
	if not last_command_result.get("ok", false):
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
		return false
	pending_target_id = unit_id
	get_node("CombatForecastPanel").show_forecast(last_command_result.get("forecast"))
	return true


func _on_unit_picked(unit_id: StringName) -> void:
	pointer_input_count += 1
	handle_board_pick(&"unit", unit_id)


func _on_unit_hovered(unit_id: StringName) -> void:
	pointer_input_count += 1
	handle_board_hover(unit_id)


func _on_unit_hover_exited(_unit_id: StringName) -> void:
	_clear_forecast_target()


func _on_cell_picked(position: Vector2i) -> void:
	pointer_input_count += 1
	handle_board_pick(&"cell", position)


func _on_cell_hovered(_position: Vector2i) -> void:
	_clear_forecast_target()


func _clear_forecast_target() -> void:
	if interaction_mode != &"attack":
		return
	pending_target_id = &""
	get_node("CombatForecastPanel").show_forecast(null)


func cancel_interaction() -> void:
	interaction_mode = &"idle"
	pending_target_id = &""
	get_node("GreyboxBoard").show_move_cells([])
	get_node("GreyboxBoard").show_attack_cells([])
	get_node("CombatForecastPanel").show_forecast(null)


func _on_events_flushed(events: Array[Dictionary]) -> void:
	get_node("BattleAudio").play_events(events)
	get_node("CombatVfxDirector").play_events(events)
	for event: Dictionary in events:
		for unit: Node in get_node("Units").get_children():
			unit.play_event(event)
		var event_type := StringName(event.get("type", &""))
		var actor_id := StringName(event.get("actor_id", &""))
		if event_type == &"unit_selected":
			var selected := get_unit_node(actor_id)
			get_node("TacticalCamera").focus_target = selected
		elif event_type == &"unit_moved":
			var moved := get_unit_node(actor_id)
			if moved != null and get_node("TacticalCamera").focus_target == moved:
				get_node("TacticalCamera").focus(moved.position)

func _on_camera_impact_requested(origin: Vector3, strength: float, duration: float) -> void:
	var camera := get_node_or_null("TacticalCamera")
	if camera != null and camera.has_method("request_impact") and get_node("CombatVfxDirector").quality_tier != &"low":
		camera.request_impact(origin, strength, duration)


func _disconnect_session() -> void:
	if session == null:
		return
	var event_callable := Callable(self, "_on_events_flushed")
	if session.events_flushed.is_connected(event_callable):
		session.events_flushed.disconnect(event_callable)


func _on_hud_command(command: Variant) -> void:
	if session == null:
		last_command_result = {"ok": false, "reason": &"missing_session"}
		return
	var command_type := StringName(command.get("type", &"")) if command is Dictionary else StringName(command)
	match command_type:
		&"select":
			last_command_result = session.select_unit(StringName(command.get("unit_id", &"")))
		&"forecast":
			last_command_result = session.forecast_attack(StringName(command.get("target_id", &"")))
			get_node("CombatForecastPanel").show_forecast(last_command_result.get("forecast"))
		&"attack":
			if command is Dictionary and command.has("target_id"):
				last_command_result = session.confirm_attack(StringName(command.get("target_id", &"")))
			else:
				_enter_attack_mode()
		&"move":
			if command is Dictionary and command.get("destination") is Vector2i:
				last_command_result = session.move_selected(command.get("destination"))
			else:
				_enter_move_mode()
		&"end_phase":
			_start_end_phase()
		&"wait":
			last_command_result = session.wait_selected()
			if last_command_result.get("ok", false):
				cancel_interaction()
		&"cancel":
			cancel_interaction()
			last_command_result = {"ok": true, "routed": command_type}
		_:
			last_command_result = {"ok": false, "reason": &"unknown_command"}


func _on_hud_result_requested(path: String, summary: Dictionary) -> void:
	result_requested.emit(path, summary)


func _enter_move_mode() -> void:
	var selected: Variant = _selected_unit()
	if selected == null or selected.acted or session.turn_state.phase != &"player":
		last_command_result = {"ok": false, "reason": &"no_ready_selection"}
		return
	cancel_interaction()
	interaction_mode = &"move"
	get_node("GreyboxBoard").show_move_cells(session.reachable_cells_for_selected())
	last_command_result = {"ok": true, "mode": &"move"}


func _enter_attack_mode() -> void:
	var selected: Variant = _selected_unit()
	if selected == null or selected.acted or session.turn_state.phase != &"player":
		last_command_result = {"ok": false, "reason": &"no_ready_selection"}
		return
	cancel_interaction()
	interaction_mode = &"attack"
	get_node("GreyboxBoard").show_attack_cells(_attack_cells(selected))
	last_command_result = {"ok": true, "mode": &"attack"}


func _selected_unit() -> Variant:
	for unit: Variant in session.units:
		if unit.instance_id == session.selected_unit_id and unit.current_hp > 0 and unit.definition.team == &"player":
			return unit
	return null


func _attack_cells(selected: Variant) -> Array:
	var cells: Array = []
	for y: int in chapter.height:
		for x: int in chapter.width:
			var distance := absi(x - selected.grid_position.x) + absi(y - selected.grid_position.y)
			if distance in selected.definition.ranges:
				cells.append(Vector2i(x, y))
	return cells


func _start_end_phase() -> void:
	if _phase_advancing or session == null or session.battle_status != &"ongoing":
		last_command_result = {"ok": false, "reason": &"phase_busy"}
		return
	last_command_result = session.end_player_phase()
	if not last_command_result.get("ok", false):
		return
	_phase_advancing = true
	cancel_interaction()
	_complete_enemy_phase.call_deferred()


func _complete_enemy_phase() -> void:
	if session != null and session.battle_status == &"ongoing" and session.turn_state.phase == &"enemy":
		last_command_result = session.advance_enemy_phase()
	_phase_advancing = false


func _clear_units() -> void:
	for child: Node in get_node("Units").get_children():
		child.free()


func _assign_owner_recursive(node: Node) -> void:
	node.owner = self
	for child: Node in node.get_children():
		_assign_owner_recursive(child)
