class_name TacticalCamera
extends Camera3D

@export var min_pitch_degrees: float = 25.0
@export var max_pitch_degrees: float = 72.0
@export var min_distance: float = 6.0
@export var max_distance: float = 24.0
@export var orbit_sensitivity: float = 0.18
@export var zoom_step: float = 1.5

var board_width: int = 1
var board_height: int = 1
var focus_point: Vector3 = Vector3.ZERO
var distance: float = 16.0
var yaw_degrees: float = 0.0
var pitch_degrees: float = 40.0
var focus_target: Node3D
var _middle_orbiting: bool = false


func configure_board(width: int, height: int) -> void:
	board_width = maxi(1, width)
	board_height = maxi(1, height)
	var board_diagonal := Vector2(board_width, board_height).length()
	max_distance = maxf(18.0, board_diagonal * 1.85)
	distance = clampf(board_diagonal * 1.28, min_distance, max_distance)
	reset_view()


func focus(target: Vector3) -> void:
	focus_point = Vector3(
		clampf(target.x, 0.0, float(board_width - 1)),
		0.0,
		clampf(target.z, 0.0, float(board_height - 1)),
	)
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
	focus_point = Vector3(
		float(board_width - 1) * 0.5,
		0.0,
		float(board_height - 1) * 0.5,
	)
	yaw_degrees = 0.0
	pitch_degrees = 40.0
	var board_diagonal := Vector2(board_width, board_height).length()
	distance = clampf(board_diagonal * 1.28, min_distance, max_distance)
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
