extends Node

const WELCOME_SCENE := preload("res://startup/startup.tscn")
const WELCOME_VIDEO_GROUP := &"welcome_video"

var reading_translation: Translation
var _idle_timeout_msec := 0
var _last_activity_msec := 0

func _enter_tree() -> void:
	reading_translation = preload("res://shared/reading_translation.gd").new()
	reading_translation.locale = "en"
	TranslationServer.add_translation(reading_translation)
	TranslationServer.set_locale("en")

func _ready() -> void:
	var timeout_seconds := float(ProjectSettings.get_setting("exhibition/idle_timeout_seconds", 180))
	_idle_timeout_msec = roundi(timeout_seconds * 1000.0)
	set_process(_idle_timeout_msec > 0)
	if _idle_timeout_msec > 0:
		_last_activity_msec = Time.get_ticks_msec()
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

func _process(_delta: float) -> void:
	var tree := get_tree()
	var now := Time.get_ticks_msec()
	if tree.current_scene == null or tree.has_group(WELCOME_VIDEO_GROUP):
		_last_activity_msec = now
		return
	if now - _last_activity_msec < _idle_timeout_msec:
		return
	_last_activity_msec = now
	var error := tree.change_scene_to_packed(WELCOME_SCENE)
	if error != OK:
		push_warning("Could not return to the welcome video: %s" % error_string(error))

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
