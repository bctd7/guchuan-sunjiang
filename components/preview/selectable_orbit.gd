extends "res://components/preview/inspection_orbit.gd"
## Tap selects, one finger rotates, two fingers zoom without selecting.
signal activated
signal tapped(position: Vector2)
signal zoom_requested(factor: float)
const Pinch = preload("res://components/input/touch_pinch.gd")
var pinch = Pinch.new()

func _ready() -> void:
	super._ready()
	resized.connect(suspend_gesture)
	get_viewport().size_changed.connect(suspend_gesture)

func configure(view_camera: Camera3D, center: Vector3, direction: Vector3, reset: bool) -> void:
	pinch.reset()
	super.configure(view_camera, center, direction, reset)

func _gui_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch and event.pressed: pinch.claim(event.index)
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and pinch.suppress_current:
		accept_event(); return
	if event is InputEventMouse and pinch.blocked:
		accept_event(); return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_requested.emit(.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15)
		accept_event(); return
	var tap := false
	if event is InputEventScreenTouch and not event.pressed:
		tap = not event.canceled and event.index == _touch_index and not _dragging and event.position.distance_to(_origin) <= TOUCH_DRAG_SLOP
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tap = _mouse_down and not _dragging and event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _last_touch_ms >= 450 and event.position.distance_to(_origin) <= DRAG_SLOP
	super._gui_input(event)
	if tap:
		tapped.emit(get_global_transform_with_canvas()*event.position)
		activated.emit()

func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree(): return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		var action: Dictionary = pinch.feed(event)
		if action.interrupt: cancel()
		if not is_equal_approx(action.factor, 1.0): zoom_requested.emit(action.factor)
		# Let every surface observe raw releases; GUI input handles consumption.
		if action.suppress: return
	super._input(event)

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: pinch.reset()

func suspend_gesture() -> void:
	cancel()
	pinch.reset()
