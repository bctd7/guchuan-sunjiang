extends Node
var reading_translation: Translation

func _enter_tree() -> void:
	reading_translation = preload("res://shared/reading_translation.gd").new()
	reading_translation.locale = "en"
	TranslationServer.add_translation(reading_translation)
	TranslationServer.set_locale("en")

func _exit_tree() -> void:
	TranslationServer.remove_translation(reading_translation)

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
