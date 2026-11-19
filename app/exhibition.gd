extends Node

const WELCOME_SCENE := preload("res://app/startup/startup.tscn")
const WELCOME_VIDEO_GROUP := &"welcome_video"

var reading_translation: Translation
var _idle_timeout_msec := 0
var _last_activity_msec := 0
var _idle_timer: Timer

func _enter_tree() -> void:
	reading_translation = preload("res://components/ui/reading_translation.gd").new()
	reading_translation.locale = "en"
	TranslationServer.add_translation(reading_translation)
	TranslationServer.set_locale("en")

func _ready() -> void:
	var timeout_seconds := float(ProjectSettings.get_setting("exhibition/idle_timeout_seconds", 180))
	_idle_timeout_msec = roundi(timeout_seconds * 1000.0)
	if _idle_timeout_msec > 0:
		_idle_timer = Timer.new()
		_idle_timer.one_shot = true
		_idle_timer.ignore_time_scale = true
		add_child(_idle_timer)
		_idle_timer.timeout.connect(_check_idle)
		get_tree().scene_changed.connect(reset_idle_window)
		# Observe window input before a lesson or 3D interaction consumes it.
		get_window().window_input.connect(_record_activity)

func _exit_tree() -> void:
	TranslationServer.remove_translation(reading_translation)

func _record_activity(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if event.relative.is_zero_approx():
			return
	elif not (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey):
		return
	_last_activity_msec = Time.get_ticks_msec()

func reset_idle_window() -> void:
	if _idle_timer == null:
		return
	_idle_timer.stop()
	_last_activity_msec = Time.get_ticks_msec()
	if _idle_timeout_msec > 0 and get_tree().current_scene != null and not get_tree().has_group(WELCOME_VIDEO_GROUP):
		_idle_timer.start(_idle_timeout_msec / 1000.0)

func _check_idle() -> void:
	var tree := get_tree()
	if tree.current_scene == null or tree.has_group(WELCOME_VIDEO_GROUP) or _idle_timeout_msec <= 0:
		return
	var remaining := _idle_timeout_msec - (Time.get_ticks_msec() - _last_activity_msec)
	if remaining > 0:
		_idle_timer.start(remaining / 1000.0)
		return
	var error := tree.change_scene_to_packed(WELCOME_SCENE)
	if error != OK:
		push_warning("Could not return to the welcome video: %s" % error_string(error))
		reset_idle_window()

## Physical keyboard maintenance only. Fullscreen is not an OS kiosk lock.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.ctrl_pressed and event.shift_pressed:
		if event.keycode == KEY_Q:
			get_tree().quit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
