class_name TacticalCamera
extends Camera3D

@export var min_pitch_degrees: float = 25.0
@export var max_pitch_degrees: float = 72.0
@export var min_distance: float = 6.0
@export var max_distance: float = 24.0
@export var orbit_sensitivity: float = 0.18
@export var zoom_step: float = 1.5

const FRAMING_MARGIN := 1.08
const GROUP_MIN_DISTANCE := 4.8
const GROUP_SCREEN_BIAS_X := -1.15

var board_width: int = 1
var board_height: int = 1
var focus_point: Vector3 = Vector3.ZERO
var distance: float = 16.0
var yaw_degrees: float = 0.0
var pitch_degrees: float = 40.0
var framing_mode: StringName = &"overview"
var _framing_radius: float = 0.5
var focus_target: Node3D
var _middle_orbiting: bool = false


func _process(_delta: float) -> void:
	if framing_mode != &"group" or get_viewport() == null:
		return
	var size := get_viewport().get_visible_rect().size
	if size.y > size.x * 1.08:
		reset_view()


func configure_board(width: int, height: int) -> void:
	board_width = maxi(1, width)
	board_height = maxi(1, height)
	reset_view()


func focus(target: Vector3) -> void:
	focus_point = Vector3(
		clampf(target.x, 0.0, float(board_width - 1)),
		0.0,
		clampf(target.z, 0.0, float(board_height - 1)),
	)
	_update_safe_distance_limits()
	distance = clampf(distance, min_distance, max_distance)
	_apply_transform()


func frame_group(points: Array) -> void:
	if points.is_empty():
		reset_view()
		return
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	_framing_radius = maxf(1.55, maxf(bounds.size.x, bounds.size.z) * 0.72 + 0.8)
	framing_mode = &"group"
	focus_point = Vector3(
		clampf(center.x + GROUP_SCREEN_BIAS_X, 0.0, float(board_width - 1)),
		0.0,
		clampf(center.z - 0.15, 0.0, float(board_height - 1)),
	)
	yaw_degrees = 12.0
	pitch_degrees = 43.0
	_update_safe_distance_limits()
	distance = min_distance
	_apply_transform()


func orbit(delta: Vector2) -> void:
	yaw_degrees = wrapf(yaw_degrees + delta.x * orbit_sensitivity, -180.0, 180.0)
	pitch_degrees = clampf(
		pitch_degrees + delta.y * orbit_sensitivity,
		min_pitch_degrees,
		max_pitch_degrees,
	)
	_apply_transform()


func zoom(amount: float) -> void:
	distance = clampf(distance + amount * zoom_step, min_distance, max_distance)
	_apply_transform()


func reset_view() -> void:
	framing_mode = &"overview"
	focus_point = Vector3(
		float(board_width - 1) * 0.5,
		0.0,
		float(board_height - 1) * 0.5,
	)
	yaw_degrees = 0.0
	pitch_degrees = 40.0
	_update_safe_distance_limits()
	distance = min_distance
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_orbiting = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1.0)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0)
	elif event is InputEventMouseMotion and _middle_orbiting:
		orbit((event as InputEventMouseMotion).relative)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F:
			if is_instance_valid(focus_target):
				focus(focus_target.global_position)
			else:
				focus(focus_point)


func _apply_transform() -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch),
	) * distance
	look_at_from_position(focus_point + offset, focus_point, Vector3.UP)


func _update_safe_distance_limits() -> void:
	var radius := _framing_radius if framing_mode == &"group" else _board_radius_from_focus()
	var half_angle := _limiting_half_fov_radians()
	var projected_distance := radius / maxf(0.01, sin(half_angle))
	var near_safe_distance := radius + near + 0.05
	min_distance = maxf(GROUP_MIN_DISTANCE if framing_mode == &"group" else 0.0, maxf(projected_distance * FRAMING_MARGIN, near_safe_distance))
	max_distance = maxf(24.0, min_distance * 1.85)


func _board_radius_from_focus() -> float:
	var result := 0.0
	for corner: Vector3 in _board_corners():
		result = maxf(result, focus_point.distance_to(corner))
	return maxf(result, 0.5)


func _board_corners() -> Array[Vector3]:
	return [
		Vector3(-0.5, 0.0, -0.5),
		Vector3(float(board_width) - 0.5, 0.0, -0.5),
		Vector3(-0.5, 0.0, float(board_height) - 0.5),
		Vector3(float(board_width) - 0.5, 0.0, float(board_height) - 0.5),
	]


func _limiting_half_fov_radians() -> float:
	var viewport_size := Vector2(1920.0, 1080.0)
	if get_viewport() != null:
		var visible_size := get_viewport().get_visible_rect().size
		if visible_size.x > 0.0 and visible_size.y > 0.0:
			viewport_size = visible_size
	var aspect := maxf(0.01, viewport_size.x / viewport_size.y)
	var configured_half_fov := deg_to_rad(clampf(fov, 1.0, 179.0) * 0.5)
	var horizontal_half_fov: float
	var vertical_half_fov: float
	if keep_aspect == Camera3D.KEEP_WIDTH:
		horizontal_half_fov = configured_half_fov
		vertical_half_fov = atan(tan(horizontal_half_fov) / aspect)
	else:
		vertical_half_fov = configured_half_fov
		horizontal_half_fov = atan(tan(vertical_half_fov) * aspect)
	return minf(horizontal_half_fov, vertical_half_fov)
