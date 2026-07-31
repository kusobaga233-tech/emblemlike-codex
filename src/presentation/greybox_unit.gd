class_name GreyboxUnit
extends Node3D

signal picked(unit_id: StringName)
signal hovered(unit_id: StringName)
signal hover_exited(unit_id: StringName)

const PLAYER_BLUE := Color("245fa8")
const PLAYER_GOLD := Color("d5ad38")
const ENEMY_CRIMSON := Color("9f2942")
const ENEMY_OUTLINE := Color("e27b75")
const HP_GREEN := Color("42b96b")
const HP_EMPTY := Color("322f35")
const DEFEAT_SCALE := Vector3(1.08, 0.08, 1.08)
const PRODUCTION_VISUALS := {
	&"aurelia": "res://assets/production/models/hero_ember_warden.glb",
	&"bridge-captain": "res://assets/production/models/boss_star_eater.glb",
}

var unit_id: StringName = &""
var team: StringName = &""
var max_hp: int = 1
var visual_hp: int = 1
var last_phase: StringName = &"player"
var last_event_type: StringName = &""
var active_animation: Tween
var animation_kind: StringName = &""
var phase_visual_energy: float = 0.0
var position_animation: Tween
var body_animation: Tween
var phase_animation: Tween
var defeat_animation: Tween

var _position_animation_target: Vector3 = Vector3.ZERO
var _phase_animation_target: float = 0.0


func configure(unit_state: Variant) -> void:
	_clear_visuals()
	if unit_state == null or unit_state.definition == null or unit_state.grid_position == null:
		return
	unit_id = unit_state.instance_id
	team = unit_state.definition.team
	max_hp = maxi(1, int(unit_state.definition.max_hp))
	visual_hp = clampi(int(unit_state.current_hp), 0, max_hp)
	position = Vector3(unit_state.grid_position.x, 0.7, unit_state.grid_position.y)
	_build_body()
	_build_production_visual(unit_state.definition.id)
	_build_selection_outline()
	_build_hp_bar()
	_build_pick_area()
	_update_hp_bar()


func set_selected(selected: bool) -> void:
	var outline := get_node_or_null("SelectionOutline") as MeshInstance3D
	if outline != null:
		outline.visible = selected


func pick() -> void:
	picked.emit(unit_id)


func hover() -> void:
	hovered.emit(unit_id)


func _build_pick_area() -> void:
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = 2
	pick_area.collision_mask = 0
	pick_area.input_ray_pickable = visual_hp > 0
	pick_area.input_event.connect(_on_pick_input_event)
	pick_area.mouse_entered.connect(_on_pick_mouse_entered)
	pick_area.mouse_exited.connect(_on_pick_mouse_exited)
	add_child(pick_area)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.2
	collision.shape = shape
	pick_area.add_child(collision)


func _on_pick_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int,
) -> void:
	if visual_hp > 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		picked.emit(unit_id)


func _on_pick_mouse_entered() -> void:
	if visual_hp > 0:
		hovered.emit(unit_id)


func _on_pick_mouse_exited() -> void:
	hover_exited.emit(unit_id)


func play_event(event: Dictionary) -> void:
	last_event_type = StringName(event.get("type", &""))
	var actor_id := StringName(event.get("actor_id", &""))
	var target_id := StringName(event.get("target_id", &""))
	var payload: Dictionary = event.get("payload", {})
	match last_event_type:
		&"unit_selected":
			set_selected(actor_id == unit_id)
		&"unit_moved":
			if actor_id == unit_id:
				var destination: Vector2i = payload.get("to", Vector2i.ZERO)
				_animate_move(Vector3(destination.x, 0.7, destination.y))
		&"damage_applied":
			if target_id == unit_id:
				visual_hp = clampi(int(payload.get("remaining_hp", visual_hp)), 0, max_hp)
				_update_hp_bar()
				_pulse_body(Vector3(1.12, 0.88, 1.12))
		&"unit_defeated":
			if target_id == unit_id:
				visual_hp = 0
				var pick_area := get_node_or_null("PickArea") as Area3D
				if pick_area != null:
					pick_area.input_ray_pickable = false
					pick_area.monitorable = false
				_update_hp_bar()
				_animate_defeat()
		&"phase_changed", &"phase_visual_changed":
			last_phase = StringName(payload.get("to", last_phase))
			_animate_phase_visual()


func _build_body() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	if team == &"player":
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.1
		body.mesh = capsule
		body.material_override = _material(PLAYER_BLUE)
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.27
		cylinder.bottom_radius = 0.34
		cylinder.height = 1.05
		body.mesh = cylinder
		body.material_override = _material(ENEMY_CRIMSON)
	add_child(body)


func _build_production_visual(definition_id: StringName) -> void:
	var path := String(PRODUCTION_VISUALS.get(definition_id, ""))
	if path.is_empty():
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return
	visual.name = "ProductionVisual"
	visual.position = Vector3(0.0, -0.7, 0.0)
	visual.scale = Vector3.ONE * 0.78
	add_child(visual)
	var body := get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.visible = false


func _build_selection_outline() -> void:
	var outline := MeshInstance3D.new()
	outline.name = "SelectionOutline"
	if team == &"player":
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.34
		capsule.height = 1.18
		outline.mesh = capsule
		outline.material_override = _material(PLAYER_GOLD, true)
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.33
		cylinder.bottom_radius = 0.40
		cylinder.height = 1.12
		outline.mesh = cylinder
		outline.material_override = _material(ENEMY_OUTLINE, true)
	outline.visible = false
	add_child(outline)


func _build_hp_bar() -> void:
	var hp_bar := Node3D.new()
	hp_bar.name = "HpBar"
	hp_bar.position = Vector3(0.0, 0.82, 0.0)
	add_child(hp_bar)
	var background := MeshInstance3D.new()
	background.name = "Background"
	background.mesh = _bar_mesh()
	background.material_override = _material(HP_EMPTY, true)
	hp_bar.add_child(background)
	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	fill.mesh = _bar_mesh()
	fill.position = Vector3(0.0, 0.0, -0.012)
	fill.material_override = _material(HP_GREEN, true)
	hp_bar.add_child(fill)


func _bar_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.82, 0.075, 0.055)
	return mesh


func _update_hp_bar() -> void:
	var fill := get_node_or_null("HpBar/Fill") as MeshInstance3D
	if fill == null:
		return
	var ratio := clampf(float(visual_hp) / float(max_hp), 0.0, 1.0)
	fill.scale.x = ratio
	fill.position.x = -0.41 * (1.0 - ratio)
	fill.visible = ratio > 0.0


func _animate_move(destination: Vector3) -> void:
	_commit_position_animation()
	_position_animation_target = destination
	var tween := _new_animation(&"move")
	if tween == null:
		position = destination
		return
	position_animation = tween
	tween.tween_property(self, "position", destination, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pulse_body(target_scale: Vector3) -> void:
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	_commit_body_animation()
	var tween := _new_animation(&"damage")
	if tween == null:
		body.scale = Vector3.ONE
		return
	body_animation = tween
	body.scale = target_scale
	tween.tween_property(body, "scale", Vector3.ONE, 0.12)


func _animate_defeat() -> void:
	if defeat_animation != null:
		_commit_defeat_animation()
	animation_kind = &"defeat"
	if not visible:
		return
	var tween := _new_animation(&"defeat")
	if tween == null:
		_finish_defeat()
		return
	defeat_animation = tween
	tween.tween_property(self, "scale", DEFEAT_SCALE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_finish_defeat"))


func _finish_defeat() -> void:
	scale = DEFEAT_SCALE
	visible = false


func _animate_phase_visual() -> void:
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var material := body.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = true
	material.emission = PLAYER_GOLD if last_phase == team else Color(0.04, 0.04, 0.05)
	var target_energy := 0.18 if last_phase == team else 0.05
	_commit_phase_animation()
	_phase_animation_target = target_energy
	var tween := _new_animation(&"phase_visual_changed")
	if tween == null:
		_set_phase_visual_energy(target_energy)
		return
	phase_animation = tween
	tween.tween_method(
		Callable(self, "_set_phase_visual_energy"),
		phase_visual_energy,
		target_energy,
		0.16,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_phase_visual_energy(value: float) -> void:
	phase_visual_energy = value
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var material := body.material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = phase_visual_energy


func _new_animation(kind: StringName) -> Tween:
	animation_kind = kind
	if not is_inside_tree():
		active_animation = null
		return null
	active_animation = create_tween()
	active_animation.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	return active_animation


func _commit_position_animation() -> void:
	if position_animation == null:
		return
	var previous := position_animation
	if previous.is_valid():
		previous.kill()
	position = _position_animation_target
	position_animation = null
	_clear_active_animation(previous)


func _commit_body_animation() -> void:
	if body_animation == null:
		return
	var previous := body_animation
	if previous.is_valid():
		previous.kill()
	var body := get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.scale = Vector3.ONE
	body_animation = null
	_clear_active_animation(previous)


func _commit_phase_animation() -> void:
	if phase_animation == null:
		return
	var previous := phase_animation
	if previous.is_valid():
		previous.kill()
	_set_phase_visual_energy(_phase_animation_target)
	phase_animation = null
	_clear_active_animation(previous)


func _commit_defeat_animation() -> void:
	if defeat_animation == null:
		return
	var previous := defeat_animation
	if previous.is_valid():
		previous.kill()
	_finish_defeat()
	defeat_animation = null
	_clear_active_animation(previous)


func _clear_active_animation(previous: Tween) -> void:
	if active_animation == previous:
		active_animation = null


func _commit_all_animation_terminals() -> void:
	_commit_position_animation()
	_commit_body_animation()
	_commit_phase_animation()
	_commit_defeat_animation()


func _exit_tree() -> void:
	_commit_all_animation_terminals()


func _clear_visuals() -> void:
	_commit_all_animation_terminals()
	active_animation = null
	animation_kind = &""
	phase_visual_energy = 0.0
	for child: Node in get_children():
		child.free()
	visible = true
	scale = Vector3.ONE
	last_event_type = &""


func _material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
