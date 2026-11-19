extends Node
## Shared chapter pointer adapter. Only translates gestures into socket intent.
## The supplied view implements pick_socket(position); rules remain in chapter state.
## Pairing press/release prevents a release outside a GUI button from placing wood.
signal socket_requested(id: String)

var view: Node3D
var _mouse_armed := false
var _mouse_origin := Vector2.ZERO
var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _last_touch_ms := -1000
var _pointer_generation := 0
const TAP_SLOP := 24.0

func configure(socket_view: Node3D) -> void:
	view = socket_view
	cancel()

func cancel() -> void:
	_mouse_armed = false
	_touch_index = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()

func _input(event: InputEvent) -> void:
	# Observe releases even when GUI consumes them. Deferred cleanup leaves this
	# event available to _unhandled_input, but cannot cancel a newer gesture.
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		_mouse_armed = false
		if event.pressed:
			_pointer_generation += 1
		elif event.index == _touch_index:
			call_deferred("_finish_gesture", _pointer_generation)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_generation += 1
			_mouse_armed = false
		else:
			call_deferred("_finish_gesture", _pointer_generation)

func _finish_gesture(generation: int) -> void:
	if generation == _pointer_generation:
		cancel()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(view):
		return
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		_mouse_armed = false
		if event.pressed:
			if _touch_index < 0:
				_touch_index = event.index
				_touch_origin = event.position
		elif event.index == _touch_index:
			_touch_index = -1
			if not event.canceled and event.position.distance_to(_touch_origin) <= TAP_SLOP:
				_request(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Real devices may emit both touch and emulated mouse events for one tap.
		if event.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - _last_touch_ms < 450:
			return
		if event.pressed:
			_mouse_armed = true
			_mouse_origin = event.position
		else:
			var was_armed := _mouse_armed
			_mouse_armed = false
			if was_armed and event.position.distance_to(_mouse_origin) <= TAP_SLOP:
				_request(event.position)

func _request(position: Vector2) -> void:
	var socket_id: String = view.pick_socket(position)
	if not socket_id.is_empty():
		socket_requested.emit(socket_id)
		get_viewport().set_input_as_handled()
