class_name TacticalCamera
extends Camera3D

@export var min_pitch_degrees: float = 25.0
@export var max_pitch_degrees: float = 72.0
@export var min_distance: float = 6.0
@export var max_distance: float = 24.0
@export var orbit_sensitivity: float = 0.18
@export var zoom_step: float = 1.5
@export var edge_margin_pixels: float = 28.0
@export var pan_speed: float = 6.0
@export var controls_enabled: bool = true

const FIXED_PITCH := 45.0
const ROTATION_STEP := 30.0
const ROTATION_RESPONSE := 14.0

const FRAMING_MARGIN := 1.08
const GROUP_MIN_DISTANCE := 4.8
const GROUP_SCREEN_BIAS_X := -1.15

var board_width: int = 1
var board_height: int = 1
var focus_point: Vector3 = Vector3.ZERO
var distance: float = 16.0
var yaw_degrees: float = 0.0
var pitch_degrees: float = FIXED_PITCH
var framing_mode: StringName = &"overview"
var _framing_radius: float = 0.5
var focus_target: Node3D
var _target_yaw_degrees: float = 0.0
var _pan_velocity := Vector2.ZERO
var _pointer_in_window := true
var _follow_target: Node3D
var _follow_start_focus := Vector3.ZERO
var _follow_start_position := Vector3.ZERO
var last_impact_origin: Vector3 = Vector3.ZERO
var last_impact_strength: float = 0.0
var last_impact_duration: float = 0.0


func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_sync_follow_before_render)
	var window := get_window()
	if window != null:
		window.mouse_entered.connect(_on_pointer_entered_window)
		window.mouse_exited.connect(_on_pointer_left_window)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_follow_before_render):
		RenderingServer.frame_pre_draw.disconnect(_sync_follow_before_render)
	var window := get_window()
	if window != null:
		if window.mouse_entered.is_connected(_on_pointer_entered_window):
			window.mouse_entered.disconnect(_on_pointer_entered_window)
		if window.mouse_exited.is_connected(_on_pointer_left_window):
			window.mouse_exited.disconnect(_on_pointer_left_window)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	if get_viewport() == null:
		return
	var size := get_viewport().get_visible_rect().size
	if framing_mode == &"group" and size.y > size.x * 1.08:
		reset_view()
		return
	_update_safe_distance_limits()
	distance = min_distance if framing_mode == &"overview" else clampf(distance, min_distance, max_distance)
	_apply_transform()


func configure_board(width: int, height: int) -> void:
	board_width = maxi(1, width)
	board_height = maxi(1, height)
	reset_view()


func focus(target: Vector3) -> void:
	_cancel_movement_follow()
	focus_point = Vector3(
		clampf(target.x, 0.0, float(board_width - 1)),
		0.0,
		clampf(target.z, 0.0, float(board_height - 1)),
	)
	_update_safe_distance_limits()
	distance = clampf(distance, min_distance, max_distance)
	_apply_transform()


func frame_group(points: Array) -> void:
	_cancel_movement_follow()
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
	_target_yaw_degrees = yaw_degrees
	pitch_degrees = FIXED_PITCH
	_update_safe_distance_limits()
	distance = min_distance
	_apply_transform()


func orbit(delta: Vector2) -> void:
	# Retained for programmatic framing callers; player wheel input is discrete.
	yaw_degrees = wrapf(yaw_degrees + delta.x * orbit_sensitivity, -180.0, 180.0)
	_target_yaw_degrees = yaw_degrees
	pitch_degrees = FIXED_PITCH
	_apply_transform()


func rotate_steps(steps: int) -> void:
	if not controls_enabled:
		return
	_cancel_movement_follow()
	_sync_orbit_focus_to_target()
	# From +Y looking down, screen-up is -Z: south -> west is clockwise.
	_target_yaw_degrees -= float(steps) * ROTATION_STEP


func _sync_orbit_focus_to_target() -> void:
	if not is_instance_valid(focus_target):
		return
	var target := focus_target.global_position
	focus_point = Vector3(
		clampf(target.x, 0.0, float(board_width - 1)),
		0.0,
		clampf(target.z, 0.0, float(board_height - 1)),
	)
	_update_safe_distance_limits()
	_apply_transform()


func advance_rotation(delta: float) -> void:
	if not controls_enabled:
		return
	var target := wrapf(_target_yaw_degrees, -180.0, 180.0)
	yaw_degrees = rad_to_deg(lerp_angle(deg_to_rad(yaw_degrees), deg_to_rad(target), 1.0 - exp(-ROTATION_RESPONSE * maxf(0.0, delta))))
	if absf(wrapf(target - yaw_degrees, -180.0, 180.0)) < 0.01:
		yaw_degrees = target
	_apply_transform()


func edge_direction(pointer: Vector2, viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or not Rect2(Vector2.ZERO, viewport_size).has_point(pointer):
		return Vector2.ZERO
	var margin := minf(edge_margin_pixels, minf(viewport_size.x, viewport_size.y) * 0.2)
	var direction := Vector2.ZERO
	if pointer.x < margin:
		direction.x = -1.0
	elif pointer.x >= viewport_size.x - margin:
		direction.x = 1.0
	if pointer.y < margin:
		direction.y = -1.0
	elif pointer.y >= viewport_size.y - margin:
		direction.y = 1.0
	return direction.normalized()


func pan_from_screen(pointer: Vector2, viewport_size: Vector2, delta: float) -> void:
	if controls_enabled:
		_pan_direction(edge_direction(pointer, viewport_size), delta)


func _pan_direction(direction: Vector2, delta: float) -> void:
	if not direction.is_zero_approx():
		_cancel_movement_follow()
	var yaw := deg_to_rad(yaw_degrees)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var down := Vector3(sin(yaw), 0.0, cos(yaw))
	var offset := (right * direction.x + down * direction.y) * pan_speed * maxf(0.0, delta)
	focus_point.x = clampf(focus_point.x + offset.x, 0.0, float(board_width - 1))
	focus_point.z = clampf(focus_point.z + offset.z, 0.0, float(board_height - 1))
	_apply_transform()


func _on_pointer_entered_window() -> void:
	_pointer_in_window = true


func _on_pointer_left_window() -> void:
	_pointer_in_window = false
	_pan_velocity = Vector2.ZERO


func _pointer_controls_allowed() -> bool:
	if not controls_enabled or not _pointer_in_window or not is_inside_tree() or get_tree().paused:
		return false
	if get_viewport().gui_get_hovered_control() != null:
		return false
	if DisplayServer.get_name() != "headless" and not DisplayServer.window_is_focused():
		return false
	return true


func begin_movement_follow(target: Node3D) -> void:
	_cancel_movement_follow()
	if not controls_enabled or not is_instance_valid(target) or target != focus_target:
		return
	_follow_target = target
	_follow_start_focus = focus_point
	_follow_start_position = target.global_position


func _cancel_movement_follow() -> void:
	_follow_target = null


func advance_movement_follow(_delta: float) -> void:
	if not controls_enabled:
		return
	if not is_instance_valid(_follow_target) or _follow_target != focus_target:
		_cancel_movement_follow()
		return
	var desired := _follow_start_focus + _follow_target.global_position - _follow_start_position
	focus_point = Vector3(clampf(desired.x, 0.0, float(board_width - 1)), 0.0, clampf(desired.z, 0.0, float(board_height - 1)))
	_apply_transform()


func _sync_follow_before_render() -> void:
	# SceneTree tweens update after Node._process. Sample once more before
	# rendering so camera and character appear at the same movement frame.
	if is_inside_tree() and not get_tree().paused and (DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()):
		advance_movement_follow(0.0)


func _process(delta: float) -> void:
	# Follow is presentation-driven, not pointer-driven: hovering HUD must not
	# interrupt an already-issued move. Tree pause and window focus still stop it.
	if controls_enabled and not get_tree().paused and (DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()):
		advance_movement_follow(delta)
	if not _pointer_controls_allowed():
		_pan_velocity = Vector2.ZERO
		return
	advance_rotation(delta)
	# Headless mouse position is synthetic and must not move a test camera.
	if DisplayServer.get_name() == "headless":
		return
	var pointer := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, size).has_point(pointer):
		_pan_velocity = Vector2.ZERO
		return
	var direction := edge_direction(pointer, size)
	_pan_velocity = _pan_velocity.move_toward(direction, maxf(delta, 0.0) * 12.0)
	_pan_direction(_pan_velocity, delta)


func zoom(amount: float) -> void:
	distance = clampf(distance + amount * zoom_step, min_distance, max_distance)
	_apply_transform()

func request_impact(origin: Vector3, strength: float, duration: float) -> void:
	last_impact_origin = origin
	last_impact_strength = clampf(strength, 0.0, 0.08)
	last_impact_duration = clampf(duration, 0.0, 0.18)


func reset_view() -> void:
	_cancel_movement_follow()
	framing_mode = &"overview"
	focus_point = Vector3(
		float(board_width - 1) * 0.5,
		0.0,
		float(board_height - 1) * 0.5,
	)
	yaw_degrees = 0.0
	_target_yaw_degrees = yaw_degrees
	_pan_velocity = Vector2.ZERO
	pitch_degrees = FIXED_PITCH
	_update_safe_distance_limits()
	distance = min_distance
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if not _pointer_controls_allowed():
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			rotate_steps(1)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotate_steps(-1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode in [KEY_R, KEY_HOME]:
			reset_view()
		elif key_event.keycode == KEY_F:
			if is_instance_valid(focus_target):
				frame_group([focus_target.global_position])
			else:
				frame_group([focus_point])


func _apply_transform() -> void:
	pitch_degrees = FIXED_PITCH
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
