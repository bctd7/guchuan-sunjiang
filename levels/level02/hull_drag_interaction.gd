extends Node
## Real pointer travel moves the selected ship part; release alone never installs it.
signal socket_requested(id: String)
signal feedback(message: String, error: bool)
signal gesture_changed
const SNAP_DEPTH := .72
var view: Node3D
var gate: Callable
var dragging := false
var _id := ""
var _last := Vector2.ZERO
var _mouse := false
var _touch := -1
var _touches: Dictionary = {}
var _multiple_touches := false
var _last_touch_ms := -1000
var _generation := 0
var _direction := Vector2.ZERO
var _travel := 100.0
var _moved := false
var _release_ready := false

func configure(ship_view: Node3D, permission: Callable) -> void:
	view=ship_view
	gate=permission

func cancel() -> void:
	_generation+=1
	dragging=false
	_mouse=false
	_touch=-1
	_touches.clear()
	_multiple_touches=false
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: cancel()
	if event is InputEventScreenTouch:
		_last_touch_ms=Time.get_ticks_msec()
		if event.pressed:
			_touches[event.index]=true
			if _touches.size()>1:
				var held:=_touches.duplicate()
				cancel()
				_touches=held
				_multiple_touches=true
		else:
			_touches.erase(event.index)
			if _touches.is_empty(): _multiple_touches=false
			if event.canceled and event.index==_touch: cancel()
			elif dragging and event.index==_touch: _deferred_release.call_deferred(_generation,event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging and _mouse: _deferred_release.call_deferred(_generation,event.position)
	# Once wood owns a gesture, dragging across a button must continue the SAME
	# wood gesture, while a new press on that button remains ordinary GUI input.
	elif event is InputEventMouseMotion and dragging and _mouse:
		_move(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and dragging and event.index==_touch:
		_move(event.position)
		get_viewport().set_input_as_handled()

func _deferred_release(generation: int, point: Vector2) -> void:
	if generation==_generation and dragging: _release(point)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(view): return
	if event is InputEventScreenTouch:
		_last_touch_ms=Time.get_ticks_msec()
		if event.pressed and _touch<0 and _touches.size()<=1 and not _multiple_touches:
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
	var id: String=view.pick_drag_piece(point)
	if id.is_empty(): return false
	var result: Dictionary=gate.call(id)
	if not result.ok:
		feedback.emit(str(result.message),true)
		return false
	_id=id
	_last=point
	_moved=false
	_release_ready=false
	_generation+=1
	var path: Vector2=view.drag_path_screen()
	if path.length()<12: return false
	_direction=path.normalized()
	_travel=path.length()
	dragging=true
	feedback.emit("沿箭头推入；浅推松手会停留，拉回可抽出。",false)
	gesture_changed.emit()
	get_viewport().set_input_as_handled()
	return true

func _move(point: Vector2) -> void:
	if not dragging: return
	var delta: float=(point-_last).dot(_direction)/_travel
	_last=point
	if absf(delta)>.0001: _moved=true
	view.set_preview_progress(clampf(view.preview_progress+delta,0.0,1.0))
	gesture_changed.emit()

func _release(point: Vector2) -> void:
	if not dragging: return
	_move(point)
	dragging=false
	_mouse=false
	_touch=-1
	if _moved and view.preview_progress>=SNAP_DEPTH:
		_release_ready=true
		socket_requested.emit(_id)
		_release_ready=false
	else:
		feedback.emit("木料停在当前深度。可以继续推入，也可以往回拉。" if _moved else "按住木料沿箭头拖动，松手才会接合。",false)
	gesture_changed.emit()
	get_viewport().set_input_as_handled()
