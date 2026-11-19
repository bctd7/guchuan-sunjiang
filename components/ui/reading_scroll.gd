extends ScrollContainer
## Reading-only touch adapter. Touch is consumed before native GUI handling,
## so exactly one path scrolls. Native wheel, scrollbar and keyboard stay intact.
var _finger := -1
var _ignored: Array[int] = []
func _ready() -> void:
	scroll_deadzone = 12
	mouse_force_pass_scroll_events = false
	visibility_changed.connect(_clear_gesture)
	get_tree().node_added.connect(_prepare_later)
	_prepare_tree.call_deferred(self)

func _prepare_later(node: Node) -> void:
	if is_ancestor_of(node): _prepare_tree.call_deferred(node)

func _prepare_tree(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is ScrollBar: return
	if node is Control and node != self:
		# Decorative panels must bubble to the native ScrollContainer.
		# Do not change embedded model surfaces or their input controllers.
		if node is SubViewportContainer: return
		if node is Container or node is BaseButton:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
		elif node is Label or node is TextureRect:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _prepare_tree(child)

func _clear_gesture() -> void:
	_finger = -1
	_ignored.clear()
	_tap_button=null
	_dragged=false
	# Stop native inertia while hidden / unfocused. The next native press
	# initializes the drag accumulator, so reentry cannot resume an old swipe.
	set_process_internal(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_gesture()

var _origin := Vector2.ZERO
var _start_scroll := 0
var _dragged := false
var _tap_button: BaseButton
var _suppress_mouse_until := 0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouse and event.device == -1 and Time.get_ticks_msec() < _suppress_mouse_until:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _finger >= 0:
				_ignored.append(event.index)
				get_viewport().set_input_as_handled()
			elif get_global_rect().has_point(event.position):
				# Leave the scrollbar's native touch/drag entry intact.
				if get_v_scroll_bar().visible and get_v_scroll_bar().get_global_rect().has_point(event.position): return
				_finger=event.index
				_origin=event.position
				_start_scroll=scroll_vertical
				_dragged=false
				_tap_button=null
				for button in find_children("*","BaseButton",true,false):
					if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
						_tap_button=button
				_suppress_mouse_until=Time.get_ticks_msec()+600
				get_viewport().set_input_as_handled()
		elif event.index in _ignored:
			_ignored.erase(event.index)
			get_viewport().set_input_as_handled()
		elif event.index == _finger:
			get_viewport().set_input_as_handled()
			_suppress_mouse_until=Time.get_ticks_msec()+600
			if not event.canceled and not _dragged and is_instance_valid(_tap_button) and not _tap_button.disabled and _tap_button.get_global_rect().has_point(event.position):
				_tap_button.grab_focus()
				if _tap_button.toggle_mode: _tap_button.button_pressed=not _tap_button.button_pressed
				_tap_button.pressed.emit()
			_clear_gesture()
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			get_viewport().set_input_as_handled()
			_suppress_mouse_until=Time.get_ticks_msec()+600
			var delta: float=(event.position.y-_origin.y)/get_global_transform_with_canvas().get_scale().y
			if absf(delta)>scroll_deadzone: _dragged=true
			if _dragged and vertical_scroll_mode!=SCROLL_MODE_DISABLED:
				scroll_vertical=roundi(_start_scroll-delta)
		elif event.index in _ignored or get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
