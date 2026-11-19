extends Control
## A pointer surface for one close-up viewport. Only its camera is ever changed.
signal camera_changed
const YAW_LIMIT := deg_to_rad(30.0)
const PITCH_LIMIT := deg_to_rad(18.0)
const RADIANS_PER_PIXEL := 0.006
const DRAG_SLOP := 5.0
const TOUCH_DRAG_SLOP := 10.0
const RESPONSE := 14.0
var yaw_limit:=YAW_LIMIT
var pitch_min:=-PITCH_LIMIT
var pitch_max:=PITCH_LIMIT
var camera: Camera3D
var target_angles := Vector2.ZERO
var angles := Vector2.ZERO
var active := false
var _center := Vector3.ZERO
var _direction := Vector3.ONE
var _mouse_down := false
var _touch_index := -1
var _origin := Vector2.ZERO
var _dragging := false
var _last_touch_ms := -1000
var _generation := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(view_camera: Camera3D, center: Vector3, direction: Vector3, reset: bool) -> void:
	cancel()
	camera = view_camera
	_center = center
	_direction = direction
	active = true
	if reset:
		angles = Vector2.ZERO
		target_angles = Vector2.ZERO
	_apply_camera()

func cancel() -> void:
	_mouse_down = false
	_touch_index = -1
	_dragging = false
	_generation += 1

func deactivate() -> void:
	active = false
	cancel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(camera) or angles == target_angles: return
	angles = angles.lerp(target_angles, 1.0 - exp(-RESPONSE * delta))
	if angles.distance_to(target_angles) < 0.00001: angles = target_angles
	_apply_camera()

func _apply_camera() -> void:
	# Pitch around the camera's horizontal right axis after yaw: no roll/pole flip.
	var offset := _direction.rotated(Vector3.UP, angles.x)
	var right := Vector3.UP.cross(offset).normalized()
	offset = offset.rotated(right, angles.y)
	camera.position = _center + offset
	camera.look_at(_center, Vector3.UP)
	camera_changed.emit()

func _input(event: InputEvent) -> void:
	if not active: return
	# Track raw touch even if its generated mouse arrives at another GUI control.
	# Release cleanup is deferred so the GUI receives the matching release first.
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		_mouse_down = false
		if not event.pressed and event.index == _touch_index:
			call_deferred("_finish_release", _generation)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _mouse_down:
		call_deferred("_finish_release", _generation)

func _finish_release(generation: int) -> void:
	if generation == _generation: cancel()

func _gui_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		_mouse_down = false
		if event.pressed and _touch_index < 0:
			cancel()
			_touch_index = event.index
			_origin = event.position
		elif not event.pressed and event.index == _touch_index:
			cancel()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_rotate_drag(event.position, event.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _last_touch_ms >= 450:
				if event.pressed and _touch_index < 0:
					cancel()
					_mouse_down = true
					_origin = event.position
				elif not event.pressed:
					cancel()
		accept_event()
	elif event is InputEventMouseMotion:
		if _mouse_down and _touch_index < 0 and event.device != InputEvent.DEVICE_ID_EMULATION:
			_rotate_drag(event.position, event.relative)
		accept_event()

func _rotate_drag(position: Vector2, relative: Vector2) -> void:
	if not _dragging:
		if position.distance_to(_origin) <= (TOUCH_DRAG_SLOP if _touch_index >= 0 else DRAG_SLOP): return
		_dragging = true
	rotate_delta(relative)

func rotate_delta(relative: Vector2) -> void:
	target_angles.x=clampf(target_angles.x-relative.x*RADIANS_PER_PIXEL,-yaw_limit,yaw_limit)
	target_angles.y=clampf(target_angles.y-relative.y*RADIANS_PER_PIXEL,pitch_min,pitch_max)
