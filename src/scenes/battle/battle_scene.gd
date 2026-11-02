class_name BattleScene
extends Node3D

const BATTLE_SESSION_SCRIPT := preload("res://src/tactics/battle_session.gd")
const CHAPTER_ONE_SCRIPT := preload("res://src/content/chapter_one.gd")
const GREYBOX_UNIT_SCRIPT := preload("res://src/presentation/greybox_unit.gd")
const SPRITE_PRESENTATION := preload("res://src/presentation/sprite_combat_presentation.gd")
const COMBAT_VFX_DIRECTOR_SCRIPT := preload("res://src/presentation/combat_vfx_director.gd")

var chapter: Variant
var session: Variant
var _configured: bool = false
var last_command_result: Dictionary = {}
var interaction_mode: StringName = &"idle"
var pending_target_id: StringName = &""
var _attack_target_locked := false
var _phase_advancing: bool = false
var pointer_input_count: int = 0
var _pending_result: Dictionary = {}
var _camera_controls_before_presentation := true

signal result_requested(path: String, summary: Dictionary)

func _exit_tree() -> void:
	var sprite_presenter := get_node_or_null("SpriteCombatPresentation")
	if sprite_presenter != null:
		if sprite_presenter.event_due.is_connected(Callable(self, "_present_event")):
			sprite_presenter.event_due.disconnect(Callable(self, "_present_event"))
		if sprite_presenter.playback_finished.is_connected(Callable(self, "_on_sprite_playback_finished")):
			sprite_presenter.playback_finished.disconnect(Callable(self, "_on_sprite_playback_finished"))
		sprite_presenter.clear()
		sprite_presenter.resolve_unit = Callable()
		remove_child(sprite_presenter)
		sprite_presenter.free()
	_disconnect_session()
	var director := get_node_or_null("CombatVfxDirector")
	if director != null:
		var impact_callable := Callable(self, "_on_camera_impact_requested")
		if director.camera_impact_requested.is_connected(impact_callable):
			director.camera_impact_requested.disconnect(impact_callable)
		if director.has_method("shutdown"):
			director.shutdown()
		else:
			director.clear_active_presentations()
		remove_child(director)
		director.free()


func _ready() -> void:
	if not _configured:
		setup_battle(CHAPTER_ONE_SCRIPT.build())


func setup_battle(initial_chapter: Variant, injected_session: Variant = null) -> void:
	_disconnect_session()
	_pending_result.clear()
	var presenter := get_node_or_null("SpriteCombatPresentation")
	if presenter == null:
		presenter = SPRITE_PRESENTATION.new()
		presenter.name = "SpriteCombatPresentation"
		add_child(presenter)
		presenter.owner = self
		presenter.resolve_unit = Callable(self, "get_unit_node")
		presenter.event_due.connect(_present_event)
		presenter.playback_finished.connect(_on_sprite_playback_finished)
	presenter.clear()
	get_node("BattleHud").presentation_driven = true
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
	var panel := get_node("CombatForecastPanel")
	if not panel.support_confirmed.is_connected(_confirm_support):
		panel.support_confirmed.connect(_confirm_support)
		panel.preview_cancelled.connect(_cancel_action_preview)
	if not panel.attack_confirmed.is_connected(_confirm_attack):
		panel.attack_confirmed.connect(_confirm_attack)
	interaction_mode = &"idle"
	pending_target_id = &""
	_attack_target_locked = false
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
	if session == null or session.battle_status != &"ongoing" or _phase_advancing or combat_presentation_busy():
		return false
	if kind == &"cell" and value is Vector2i and interaction_mode == &"move":
		last_command_result = session.move_selected(value)
		get_node("BattleHud").show_command_result(last_command_result)
		if last_command_result.get("ok", false):
			cancel_interaction()
			return true
		return false
	if interaction_mode == &"move" and kind == &"unit":
		return false
	if kind == &"cell" and interaction_mode == &"idle":
		last_command_result = session.clear_selection()
		cancel_interaction()
		return bool(last_command_result.get("ok", false))
	if kind != &"unit" or not value is StringName:
		return false
	var unit_id: StringName = value
	if interaction_mode == &"support":
		last_command_result = session.forecast_support(unit_id)
		get_node("BattleHud").show_command_result(last_command_result)
		if not last_command_result.get("ok", false):
			pending_target_id = &""
			get_node("CombatForecastPanel").show_forecast(null)
			return false
		pending_target_id = unit_id
		get_node("CombatForecastPanel").show_support(last_command_result.forecast)
		return true
	if interaction_mode == &"attack":
		last_command_result = session.forecast_attack(unit_id)
		get_node("BattleHud").show_command_result(last_command_result)
		if not last_command_result.get("ok", false):
			_attack_target_locked = false
			pending_target_id = &""
			get_node("CombatForecastPanel").show_forecast(null)
			return false
		pending_target_id = unit_id
		_attack_target_locked = true
		var target: Variant = session._find_unit(unit_id)
		get_node("CombatForecastPanel").show_attack(last_command_result.forecast, target.definition.display_name)
		return true
	last_command_result = session.select_unit(unit_id)
	return bool(last_command_result.get("ok", false))


func handle_board_hover(unit_id: StringName) -> bool:
	if interaction_mode != &"attack" or session == null or combat_presentation_busy():
		return false
	if _attack_target_locked: return true
	last_command_result = session.forecast_attack(unit_id)
	get_node("BattleHud").show_command_result(last_command_result)
	if not last_command_result.get("ok", false):
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
		return false
	pending_target_id = unit_id
	get_node("CombatForecastPanel").show_forecast(last_command_result.get("forecast"))
	return true


# Resolve unit pick areas before terrain, regardless of unit team. UI-consumed
# clicks never arrive here; empty sky/outside the viewport is not a board click.
func board_hit_kind(pointer: Vector2) -> StringName:
	if not get_viewport().get_visible_rect().has_point(pointer):
		return &"outside"
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_inside_tree():
		return &"outside"
	var origin := camera.project_ray_origin(pointer)
	var end := origin + camera.project_ray_normal(pointer) * camera.far
	for mask: int in [2, 1]:
		var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var collider: Node = hit.get("collider")
		var parent := collider.get_parent() if collider != null else null
		if parent != null and get_node("Units").is_ancestor_of(parent):
			return &"unit"
		if parent != null and parent.has_meta("grid_position"):
			return &"cell"
	return &"outside"


func handle_board_right_click(kind: StringName) -> bool:
	if session == null or session.battle_status != &"ongoing" or session.turn_state.phase != &"player" or _phase_advancing or combat_presentation_busy():
		return false
	if kind not in [&"cell", &"unit"]:
		return false
	if session.can_undo_selected_move():
		last_command_result = session.undo_selected_move()
		get_node("BattleHud").show_command_result(last_command_result)
		if last_command_result.get("ok", false):
			cancel_interaction()
			return true
		# A rejected undo must not silently deselect the pending mover.
		return false
	_on_hud_command(&"cancel")
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_board_right_click(board_hit_kind(event.position))
		get_viewport().set_input_as_handled()


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
	if interaction_mode != &"attack" or _attack_target_locked:
		return
	pending_target_id = &""
	get_node("CombatForecastPanel").show_forecast(null)


func cancel_interaction() -> void:
	interaction_mode = &"idle"
	pending_target_id = &""
	_attack_target_locked = false
	get_node("GreyboxBoard").show_move_cells([])
	get_node("GreyboxBoard").show_attack_cells([])
	get_node("CombatForecastPanel").show_forecast(null)


func combat_presentation_busy() -> bool:
	var presenter := get_node_or_null("SpriteCombatPresentation")
	return presenter != null and presenter.is_busy()


func _on_events_flushed(events: Array[Dictionary]) -> void:
	var presenter := get_node("SpriteCombatPresentation")
	if presenter.accepts(events):
		if not presenter.is_busy():
			_camera_controls_before_presentation = get_node("TacticalCamera").controls_enabled
		get_node("TacticalCamera").controls_enabled = false
		get_node("BattleHud").set_input_locked(true)
		presenter.enqueue(events)
	else:
		for event in events: _present_event(event)


func _present_event(event: Dictionary) -> void:
	var batch: Array[Dictionary] = [event]
	get_node("BattleAudio").play_events(batch)
	var type := StringName(event.get("type", &""))
	# Sequenced attacks have typed slash/arrow/casting effects; do not also draw
	# the old instant full-distance orange rectangle over the battlefield.
	if not event.get("sprite_sequence", false) or type not in [&"attack_started", &"hit_confirmed", &"damage_applied", &"attack_missed", &"unit_healed"]:
		get_node("CombatVfxDirector").play_events(batch)
	for unit in get_node("Units").get_children(): unit.play_event(event)
	var actor_id := StringName(event.get("actor_id", &""))
	if type == &"unit_selected":
		cancel_interaction()
		get_node("TacticalCamera").focus_target = get_unit_node(actor_id)
	elif type == &"unit_deselected":
		get_node("TacticalCamera").focus_target = null
	elif type == &"unit_moved":
		var moved := get_unit_node(actor_id)
		if moved != null and get_node("TacticalCamera").focus_target == moved:
			get_node("TacticalCamera").begin_movement_follow(moved)
	get_node("BattleHud").present_events(batch)


func _on_sprite_playback_finished() -> void:
	get_node("BattleHud").set_input_locked(false)
	var camera := get_node_or_null("TacticalCamera")
	if camera != null:
		camera.controls_enabled = _camera_controls_before_presentation
	if not _pending_result.is_empty():
		var pending := _pending_result.duplicate(true)
		_pending_result.clear()
		result_requested.emit(pending["path"], pending["summary"])

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
	_route_hud_command(command)
	get_node("BattleHud").show_command_result(last_command_result)


func _route_hud_command(command: Variant) -> void:
	if combat_presentation_busy():
		last_command_result = {"ok": false, "reason": &"presentation_busy"}
		return
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
		&"support":
			_enter_support_mode()
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
			if interaction_mode == &"idle":
				last_command_result = session.clear_selection()
			else:
				last_command_result = {"ok": true, "routed": command_type}
			cancel_interaction()
		_:
			last_command_result = {"ok": false, "reason": &"unknown_command"}


func _on_hud_result_requested(path: String, summary: Dictionary) -> void:
	if combat_presentation_busy():
		_pending_result = {"path": path, "summary": summary.duplicate(true)}
	else:
		result_requested.emit(path, summary)


func _enter_move_mode() -> void:
	var selected: Variant = _selected_unit()
	if selected == null or selected.acted or session.turn_state.phase != &"player":
		last_command_result = {"ok": false, "reason": &"no_ready_selection"}
		return
	if selected.has_moved:
		last_command_result = {"ok": false, "reason": &"already_moved"}
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


func _enter_support_mode() -> void:
	var selected: Variant = _selected_unit()
	if selected == null or selected.acted or session.turn_state.phase != &"player":
		last_command_result = {"ok": false, "reason": &"no_ready_selection"}
		return
	if selected.definition.id != &"elio":
		last_command_result = {"ok": false, "reason": &"not_healer"}
		return
	cancel_interaction()
	interaction_mode = &"support"
	last_command_result = {"ok": true, "mode": &"support"}
	get_node("GreyboxBoard").show_move_cells(_attack_cells(selected))


func _confirm_support() -> void:
	if combat_presentation_busy(): return
	if interaction_mode != &"support" or pending_target_id == &"":
		last_command_result = {"ok": false, "reason": &"no_support_target"}
	else:
		last_command_result = session.support_selected(pending_target_id)
	if last_command_result.get("ok", false):
		cancel_interaction()
	else:
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
	get_node("BattleHud").show_command_result(last_command_result)


func _confirm_attack() -> void:
	if combat_presentation_busy(): return
	if interaction_mode != &"attack" or not _attack_target_locked or pending_target_id == &"":
		last_command_result = {"ok": false, "reason": &"no_attack_target"}
	else:
		last_command_result = session.confirm_attack(pending_target_id)
	if last_command_result.get("ok", false):
		cancel_interaction()
	else:
		_attack_target_locked = false
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
	get_node("BattleHud").show_command_result(last_command_result)


func _cancel_action_preview() -> void:
	if combat_presentation_busy(): return
	cancel_interaction()
	get_node("BattleHud").show_feedback("已取消预览，未消耗行动")


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
