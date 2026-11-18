extends Node
## Real pointer travel moves the selected ship part; release alone never installs it.
signal socket_requested(id: String)
signal feedback(message: String, error: bool)
signal gesture_changed
signal zoom_requested(factor: float)
const SNAP_DEPTH := .72
const DRAG_SLOP := 6.0
const TOUCH_DRAG_SLOP := 10.0
const Pinch = preload("res://levels/shared/touch_pinch.gd")
var pinch = Pinch.new()
var view: Node3D
var gate: Callable
var dragging := false
var _id := ""
var _last := Vector2.ZERO
var _press := Vector2.ZERO
var _input_inverse := Transform2D.IDENTITY
var _mouse := false
var _touch := -1
var _touches: Dictionary:
	get: return pinch.points
var _last_touch_ms := -1000
var _generation := 0
var _direction := Vector2.ZERO
var _travel := 100.0
var _moved := false
var _release_ready := false
var _orbiting:=false

func configure(ship_view: Node3D, permission: Callable) -> void:
	view=ship_view
	gate=permission
	view.local_surface.gui_input.connect(_surface_input)
	view.local_surface.get_viewport().size_changed.connect(cancel)
	view.local_surface.resized.connect(cancel)

func cancel() -> void:
	_generation+=1
	dragging=false
	_orbiting=false
	_mouse=false
	_touch=-1
	pinch.reset()
	_release_ready=false
	_id=""
	if is_instance_valid(view): view.reset_preview()
	gesture_changed.emit()

func consume_release(id: String) -> bool:
	if not _release_ready or id!=_id: return false
	_release_ready=false
	return true

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: cancel()

func _park_for_pinch() -> void:
	_generation += 1
	dragging = false
	_orbiting = false
	_mouse = false
	_touch = -1
	_moved = false
	_release_ready = false
	_id = ""
	gesture_changed.emit()

func suspend_gesture() -> void:
	_park_for_pinch()
	pinch.reset()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: cancel()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		var action: Dictionary = pinch.feed(event)
		if action.interrupt: _park_for_pinch()
		if not is_equal_approx(action.factor, 1.0): zoom_requested.emit(action.factor)
		if action.suppress: return
		if event is InputEventScreenTouch:
			if event.canceled and event.index == _touch: cancel()
			elif not event.pressed and dragging and event.index == _touch:
				_deferred_release.call_deferred(_generation, event.position)
		elif dragging and event.index == _touch:
			_move(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging and _mouse: _deferred_release.call_deferred(_generation,event.position)
	# A drag keeps its owner even when the finger passes over a GUI control.
	elif event is InputEventMouseMotion and dragging and _mouse:
		_move(event.position)
		get_viewport().set_input_as_handled()

func _deferred_release(generation: int, point: Vector2) -> void:
	if generation==_generation and dragging: _release(point)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(view): return
	if pinch.blocked or ((event is InputEventScreenTouch or event is InputEventScreenDrag) and pinch.suppress_current): return
	if event is InputEventScreenTouch:
		_last_touch_ms=Time.get_ticks_msec()
		if event.pressed and _touch<0 and _touches.size()<=1:
			if _begin(event.position): _touch=event.index
		elif not event.pressed and event.index==_touch:
			if event.canceled: cancel()
			else: _release(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.device==InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec()-_last_touch_ms<450 or not _touches.is_empty(): return
		if event.pressed:
			if _begin(event.position): _mouse=true
		elif _mouse: _release(event.position)

func _begin(point: Vector2) -> bool:
	if dragging: return false
	if not view.inspected:return false
	if not view.inside_observation(point):return false
	var id: String=view.pick_drag_piece(point)
	if id.is_empty():
		_orbiting=true;dragging=true;_last=point;_generation+=1
		return true
	var result: Dictionary=gate.call(id)
	if not result.ok:
		feedback.emit(str(result.message),true)
		return false
	_id=id
	_input_inverse=view.local_surface.get_global_transform_with_canvas().affine_inverse()
	_last=_input_inverse*point
	_press=_last
	_moved=false
	_release_ready=false
	_generation+=1
	var path: Vector2=_input_inverse.basis_xform(view.drag_input_path_screen())
	_direction=path.normalized()
	_travel=path.length()
	dragging=true
	gesture_changed.emit()
	get_viewport().set_input_as_handled()
	return true

func _move(point: Vector2) -> void:
	if not dragging: return
	if _orbiting:
		view.orbit_delta((point-_last)/view.local_surface.get_global_transform_with_canvas().get_scale())
		_last=point
		return
	var local_point:=_input_inverse*point
	if not _moved and local_point.distance_to(_press)<=(TOUCH_DRAG_SLOP if _touch>=0 else DRAG_SLOP):return
	var delta: float=(local_point-_last).dot(_direction)/_travel
	_last=local_point
	if absf(delta)>.0001: _moved=true
	view.set_preview_progress(clampf(view.preview_progress+delta,0.0,1.0))
	gesture_changed.emit()

func _release(point: Vector2) -> void:
	if not dragging: return
	_move(point)
	if _orbiting:
		_orbiting=false;dragging=false;_mouse=false;_touch=-1
		get_viewport().set_input_as_handled()
		return
	dragging=false
	_mouse=false
	_touch=-1
	if _moved and view.preview_progress>=SNAP_DEPTH:
		_release_ready=true
		socket_requested.emit(_id)
		_release_ready=false
	else:
		feedback.emit("木料尚未完全装入。" if _moved else "",false)
	gesture_changed.emit()
	get_viewport().set_input_as_handled()

func _surface_input(event: InputEvent) -> void:
	if not view.inspected:return
	if event is InputEventScreenTouch and event.pressed: pinch.claim(event.index)
	if pinch.blocked or ((event is InputEventScreenTouch or event is InputEventScreenDrag) and pinch.suppress_current):
		view.local_surface.accept_event(); return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if not dragging:zoom_requested.emit(.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.15)
		view.local_surface.accept_event()
		return
	var translated: InputEvent=event.duplicate()
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		translated.position=view.local_surface.get_global_transform_with_canvas()*event.position
		if event is InputEventMouse:translated.global_position=translated.position
	_unhandled_input(translated)
	view.local_surface.accept_event()
