class_name BattleScene
extends Node3D

const BATTLE_SESSION_SCRIPT := preload("res://src/tactics/battle_session.gd")
const CHAPTER_ONE_SCRIPT := preload("res://src/content/chapter_one.gd")
const GREYBOX_UNIT_SCRIPT := preload("res://src/presentation/greybox_unit.gd")
const SPRITE_PRESENTATION := preload("res://src/presentation/sprite_combat_presentation.gd")
const COMBAT_VFX_DIRECTOR_SCRIPT := preload("res://src/presentation/combat_vfx_director.gd")
const THREAT_RULES_SCRIPT := preload("res://src/core/threat_rules.gd")
const TUTORIAL_FLOW_SCRIPT := preload("res://src/tutorial/tutorial_flow.gd")
const RESONANCE_STATE_SCRIPT := preload("res://src/core/resonance_state.gd")

var chapter: Variant
var session: Variant
var tutorial: Variant
var _configured: bool = false
var last_command_result: Dictionary = {}
var interaction_mode: StringName = &"idle"
var pending_target_id: StringName = &""
var pending_partner_id: StringName = &""
var _attack_target_locked := false
var _inspected_unit_id: StringName = &""
var _threat_enabled := false
var _phase_advancing: bool = false
var pointer_input_count: int = 0
var _pending_result: Dictionary = {}
var _camera_controls_before_presentation := true

signal result_requested(path: String, summary: Dictionary)

func _exit_tree() -> void:
	var window := get_window()
	if window != null and window.mouse_exited.is_connected(_on_inspection_window_exited):
		window.mouse_exited.disconnect(_on_inspection_window_exited)
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
	var window := get_window()
	if window != null and not window.mouse_exited.is_connected(_on_inspection_window_exited):
		window.mouse_exited.connect(_on_inspection_window_exited)
	if not _configured:
		setup_battle(CHAPTER_ONE_SCRIPT.build())


func setup_battle(initial_chapter: Variant, injected_session: Variant = null) -> void:
	_clear_enemy_inspection()
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
	var threat_callable := Callable(self, "_on_threat_toggled")
	if not get_node("BattleHud").threat_toggled.is_connected(threat_callable):
		get_node("BattleHud").threat_toggled.connect(threat_callable)
	_threat_enabled = false
	get_node("BattleHud").set_threat_enabled(false)
	get_node("GreyboxBoard").show_threat_cells([], [])
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
	if not panel.resonance_confirmed.is_connected(_confirm_resonance):
		panel.resonance_confirmed.connect(_confirm_resonance)
	interaction_mode = &"idle"
	pending_target_id = &""
	pending_partner_id = &""
	_attack_target_locked = false
	var board_pick_callable := Callable(self, "_on_cell_picked")
	if not get_node("GreyboxBoard").cell_picked.is_connected(board_pick_callable):
		get_node("GreyboxBoard").cell_picked.connect(board_pick_callable)
	var board_hover_callable := Callable(self, "_on_cell_hovered")
	if not get_node("GreyboxBoard").cell_hovered.is_connected(board_hover_callable):
		get_node("GreyboxBoard").cell_hovered.connect(board_hover_callable)
	var tutorial_panel := get_node("TutorialPanel")
	if not tutorial_panel.skip_requested.is_connected(_on_tutorial_skip):
		tutorial_panel.skip_requested.connect(_on_tutorial_skip)
	tutorial = TUTORIAL_FLOW_SCRIPT.new()
	tutorial.step_changed.connect(_on_tutorial_step_changed)
	tutorial.finished.connect(_on_tutorial_finished)
	_assign_owner_recursive(get_node("BattleHud"))
	_assign_owner_recursive(get_node("CombatForecastPanel"))
	_assign_owner_recursive(get_node("EnemyInspectionPanel"))
	_assign_owner_recursive(get_node("TutorialPanel"))
	_configured = true
	_refresh_tutorial()


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
	if interaction_mode == &"resonance_partner":
		return _pick_resonance_partner(unit_id)
	if interaction_mode == &"resonance_target":
		return _pick_resonance_target(unit_id)
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
	if interaction_mode == &"resonance_target":
		return _hover_resonance_target(unit_id)
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
	if interaction_mode in [&"idle", &"move"]:
		_show_enemy_inspection(unit_id)
	else:
		_clear_enemy_inspection()
	handle_board_hover(unit_id)


func _on_unit_hover_exited(unit_id: StringName) -> void:
	if _inspected_unit_id == unit_id: _clear_enemy_inspection()
	_clear_forecast_target()


func _on_cell_picked(position: Vector2i) -> void:
	pointer_input_count += 1
	handle_board_pick(&"cell", position)


func _on_cell_hovered(_position: Vector2i) -> void:
	_clear_enemy_inspection()
	_clear_forecast_target()


func _show_enemy_inspection(unit_id: StringName) -> void:
	if session == null or session.battle_status != &"ongoing" or _phase_advancing or combat_presentation_busy() or interaction_mode not in [&"idle", &"move"]:
		_clear_enemy_inspection()
		return
	var unit: Variant = session._find_unit(unit_id)
	var visual: Node3D = get_unit_node(unit_id)
	if unit == null or unit.definition == null or unit.definition.team != &"enemy" or unit.current_hp <= 0 or visual == null or not visual.visible or visual.visual_hp <= 0:
		_clear_enemy_inspection()
		return
	_inspected_unit_id = unit_id
	var definition: Variant = unit.definition
	get_node("EnemyInspectionPanel").show_enemy({
		"name": definition.display_name, "role": definition.role,
		"hp": visual.visual_hp, "max_hp": definition.max_hp,
		"attack": definition.attack, "damage_type": definition.damage_type,
		"defense": definition.defense, "resistance": definition.resistance,
		"move": definition.move, "ranges": definition.ranges.duplicate(),
		"hit": definition.hit, "critical": definition.critical, "acted": unit.acted,
	})


func _clear_enemy_inspection() -> void:
	_inspected_unit_id = &""
	var panel := get_node_or_null("EnemyInspectionPanel")
	if panel != null: panel.clear()


func _on_inspection_window_exited() -> void:
	_clear_enemy_inspection()


func _on_threat_toggled(enabled: bool) -> void:
	_threat_enabled = enabled
	_refresh_threat()


func _refresh_threat() -> void:
	var board := get_node_or_null("GreyboxBoard")
	if board == null:
		return
	if (
		not _threat_enabled
		or session == null
		or session.battle_status != &"ongoing"
		or session.turn_state.phase != &"player"
		or _phase_advancing
		or combat_presentation_busy()
	):
		board.show_threat_cells([], [])
		return
	var threat: Dictionary = THREAT_RULES_SCRIPT.compute(session.units, session.board_snapshot())
	board.show_threat_cells(threat.move, threat.attack)


func _on_tutorial_step_changed(_step: Dictionary) -> void:
	_refresh_tutorial()


func _on_tutorial_finished() -> void:
	_refresh_tutorial()


func _on_tutorial_skip() -> void:
	if tutorial != null:
		tutorial.skip()
	_refresh_tutorial()


func _refresh_tutorial() -> void:
	var panel := get_node_or_null("TutorialPanel")
	if panel == null:
		return
	if tutorial == null or not tutorial.is_active() or session == null or session.battle_status != &"ongoing":
		panel.clear()
		_clear_tutorial_highlights()
		return
	var step: Dictionary = tutorial.current_step()
	panel.show_step(step, tutorial.step_number(), tutorial.step_count(), _tutorial_extra(step))
	_apply_tutorial_highlight(StringName(step.get("id", &"")))


func _tutorial_extra(step: Dictionary) -> String:
	var step_id := StringName(step.get("id", &""))
	if step_id not in [&"heal", &"resonance"]:
		return ""
	var value: int = session.resonance_value()
	var text := "当前星誓共鸣：%d%% / 100%%" % value
	if value < 100:
		text += "（每次治疗 +25%）"
	return text


func _apply_tutorial_highlight(step_id: StringName) -> void:
	_clear_tutorial_highlights()
	var target_id := _tutorial_target_id(step_id)
	if target_id == &"":
		return
	var unit := get_unit_node(target_id)
	if unit != null and unit.has_method("set_tutorial_highlight"):
		unit.set_tutorial_highlight(true)


func _clear_tutorial_highlights() -> void:
	var units := get_node_or_null("Units")
	if units == null:
		return
	for child: Node in units.get_children():
		if child.has_method("set_tutorial_highlight"):
			child.set_tutorial_highlight(false)


func _tutorial_target_id(step_id: StringName) -> StringName:
	match step_id:
		&"move":
			return _living_unit_id(&"aurelia-1") if _living_unit_id(&"aurelia-1") != &"" else _first_ready_player_id()
		&"attack":
			return _living_unit_id(&"blade-1") if _living_unit_id(&"blade-1") != &"" else _first_living_enemy_id()
		&"heal":
			return _living_unit_id(&"elio-1")
		&"resonance":
			return _living_unit_id(&"aurelia-1")
	return &""


func _living_unit_id(instance_id: StringName) -> StringName:
	var unit: Variant = session._find_unit(instance_id) if session != null else null
	if unit != null and unit.current_hp > 0:
		return instance_id
	return &""


func _first_ready_player_id() -> StringName:
	if session == null:
		return &""
	for unit: Variant in session.units:
		if unit.definition.team == &"player" and unit.current_hp > 0 and not unit.acted:
			return unit.instance_id
	return &""


func _first_living_enemy_id() -> StringName:
	if session == null:
		return &""
	for unit: Variant in session.units:
		if unit.definition.team == &"enemy" and unit.current_hp > 0:
			return unit.instance_id
	return &""


func _clear_forecast_target() -> void:
	if interaction_mode == &"resonance_target":
		if _attack_target_locked:
			return
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
		return
	if interaction_mode != &"attack" or _attack_target_locked:
		return
	pending_target_id = &""
	get_node("CombatForecastPanel").show_forecast(null)


func cancel_interaction() -> void:
	_clear_enemy_inspection()
	interaction_mode = &"idle"
	pending_target_id = &""
	pending_partner_id = &""
	_attack_target_locked = false
	get_node("BattleHud").show_feedback("")
	get_node("GreyboxBoard").show_move_cells([])
	get_node("GreyboxBoard").show_attack_cells([])
	get_node("GreyboxBoard").show_resonance_cells([])
	get_node("CombatForecastPanel").show_forecast(null)


func combat_presentation_busy() -> bool:
	var presenter := get_node_or_null("SpriteCombatPresentation")
	return presenter != null and presenter.is_busy()


func _on_events_flushed(events: Array[Dictionary]) -> void:
	var presenter := get_node("SpriteCombatPresentation")
	if presenter.accepts(events):
		_clear_enemy_inspection()
		if not presenter.is_busy():
			_camera_controls_before_presentation = get_node("TacticalCamera").controls_enabled
		get_node("TacticalCamera").controls_enabled = false
		get_node("BattleHud").set_input_locked(true)
		presenter.enqueue(events)
	else:
		for event in events: _present_event(event)
	_refresh_threat()
	if tutorial != null:
		for event: Dictionary in events:
			tutorial.observe_event(event, session)
		_refresh_tutorial()


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
	if _inspected_unit_id != &"": _show_enemy_inspection(_inspected_unit_id)


func _on_sprite_playback_finished() -> void:
	get_node("BattleHud").set_input_locked(false)
	var camera := get_node_or_null("TacticalCamera")
	if camera != null:
		camera.controls_enabled = _camera_controls_before_presentation
	_refresh_threat()
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
	if last_command_result.get("ok", false) and last_command_result.has("hint"):
		get_node("BattleHud").show_feedback(String(last_command_result["hint"]))


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
		&"resonance":
			_enter_resonance_mode()
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


func _enter_resonance_mode() -> void:
	var selected: Variant = _selected_unit()
	if selected == null or selected.acted or session.turn_state.phase != &"player":
		last_command_result = {"ok": false, "reason": &"no_ready_selection"}
		return
	if selected.definition.id != &"aurelia":
		last_command_result = {"ok": false, "reason": &"not_resonance_leader"}
		return
	if session.resonance_value() != 100:
		last_command_result = {"ok": false, "reason": &"insufficient_resonance"}
		return
	var partners := _resonance_partner_ids(selected)
	if partners.is_empty():
		last_command_result = {"ok": false, "reason": &"no_partner"}
		return
	cancel_interaction()
	interaction_mode = &"resonance_partner"
	var cells: Array = []
	for partner_id: StringName in partners:
		var partner: Variant = session._find_unit(partner_id)
		cells.append(Vector2i(partner.grid_position.x, partner.grid_position.y))
	get_node("GreyboxBoard").show_resonance_cells(cells)
	last_command_result = {
		"ok": true,
		"mode": &"resonance_partner",
		"partners": partners,
		"hint": "选择相邻且未行动的友军作为共鸣伙伴",
	}


func _resonance_partner_ids(leader: Variant) -> Array[StringName]:
	var partners: Array[StringName] = []
	if leader == null or session == null:
		return partners
	for unit: Variant in session.units:
		if unit == null or unit.definition == null or unit.grid_position == null:
			continue
		if unit == leader or unit.instance_id == leader.instance_id:
			continue
		if unit.definition.team != &"player" or unit.current_hp <= 0 or unit.acted:
			continue
		if absi(unit.grid_position.x - leader.grid_position.x) + absi(unit.grid_position.y - leader.grid_position.y) == 1:
			partners.append(unit.instance_id)
	return partners


func _pick_resonance_partner(partner_id: StringName) -> bool:
	var leader: Variant = _selected_unit()
	if leader == null or session.resonance_value() != 100:
		cancel_interaction()
		return _reject_resonance(&"insufficient_resonance")
	if partner_id not in _resonance_partner_ids(leader):
		return _reject_resonance(&"invalid_partner")
	pending_partner_id = partner_id
	interaction_mode = &"resonance_target"
	get_node("GreyboxBoard").show_resonance_cells(_attack_cells(leader))
	var partner: Variant = session._find_unit(partner_id)
	last_command_result = {"ok": true, "mode": &"resonance_target", "hint": "选择射程内敌军"}
	get_node("BattleHud").show_feedback("伙伴：%s。请选择射程内敌军" % partner.definition.display_name)
	return true


func _hover_resonance_target(target_id: StringName) -> bool:
	if _attack_target_locked:
		return true
	var leader: Variant = _selected_unit()
	var partner: Variant = session._find_unit(pending_partner_id) if session != null else null
	var target: Variant = session._find_unit(target_id) if session != null else null
	if not _is_resonance_target(leader, partner, target):
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
		return false
	pending_target_id = target_id
	get_node("CombatForecastPanel").show_resonance(_resonance_preview(leader, partner, target))
	return true


func _pick_resonance_target(target_id: StringName) -> bool:
	var leader: Variant = _selected_unit()
	var partner: Variant = session._find_unit(pending_partner_id) if session != null else null
	var target: Variant = session._find_unit(target_id) if session != null else null
	if partner == null or not _is_resonance_partner(leader, partner):
		cancel_interaction()
		return _reject_resonance(&"invalid_partner")
	if not _is_resonance_target(leader, partner, target):
		pending_target_id = &""
		get_node("CombatForecastPanel").show_forecast(null)
		return _reject_resonance(&"out_of_range")
	pending_target_id = target_id
	_attack_target_locked = true
	get_node("CombatForecastPanel").show_resonance(_resonance_preview(leader, partner, target))
	get_node("BattleHud").show_feedback("")
	return true


func _is_resonance_partner(leader: Variant, partner: Variant) -> bool:
	if leader == null or partner == null or session == null:
		return false
	if partner.definition == null or partner.grid_position == null:
		return false
	if partner.definition.team != &"player" or partner.current_hp <= 0 or partner.acted:
		return false
	if partner.instance_id == leader.instance_id:
		return false
	return absi(partner.grid_position.x - leader.grid_position.x) + absi(partner.grid_position.y - leader.grid_position.y) == 1


func _is_resonance_target(leader: Variant, partner: Variant, target: Variant) -> bool:
	if not _is_resonance_partner(leader, partner) or target == null:
		return false
	if target.definition == null or target.grid_position == null:
		return false
	if target.definition.team != &"enemy" or target.current_hp <= 0:
		return false
	var distance := absi(leader.grid_position.x - target.grid_position.x) + absi(leader.grid_position.y - target.grid_position.y)
	return distance in leader.definition.ranges


func _resonance_preview(leader: Variant, partner: Variant, target: Variant) -> Dictionary:
	var damage: int = RESONANCE_STATE_SCRIPT.pair_damage(leader, partner, target)
	return {
		"target_name": target.definition.display_name,
		"partner_name": partner.definition.display_name,
		"damage": damage,
		"target_hp": target.current_hp,
		"remaining_hp": maxi(0, target.current_hp - damage),
		"max_hp": target.definition.max_hp,
	}


func _reject_resonance(reason: StringName) -> bool:
	last_command_result = {"ok": false, "reason": reason}
	get_node("BattleHud").show_command_result(last_command_result)
	return false


func _confirm_resonance() -> void:
	if combat_presentation_busy():
		return
	if interaction_mode != &"resonance_target" or not _attack_target_locked or pending_partner_id == &"" or pending_target_id == &"":
		last_command_result = {"ok": false, "reason": &"no_resonance_target"}
	else:
		last_command_result = session.use_resonance_selected(pending_partner_id, pending_target_id)
	cancel_interaction()
	get_node("BattleHud").show_command_result(last_command_result)


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
	_refresh_threat()


func _clear_units() -> void:
	for child: Node in get_node("Units").get_children():
		child.free()


func _assign_owner_recursive(node: Node) -> void:
	node.owner = self
	for child: Node in node.get_children():
		_assign_owner_recursive(child)
