extends CanvasLayer
## Shared story lifecycle: suspend source input, close by button/Esc, restore focus.
signal closed
const StoryPanel = preload("res://levels/shared/story_panel.gd")
var content: Dictionary = {}
var opened := false
var close_button: Button
var root: Control
var _source: Node
var _input_flags: Array[bool] = []
var _previous_focus: WeakRef

func _ready() -> void:
	layer = 35
	_build_ui()
	root.hide()
	set_process_input(false)

func show_story(source_interaction: Node = null) -> void:
	if opened: return
	if not is_instance_valid(root): return
	_source = source_interaction
	_input_flags.clear()
	if is_instance_valid(_source):
		_input_flags.assign([
			_source.is_processing_input(), _source.is_processing_unhandled_input(),
			_source.is_processing_unhandled_key_input(), _source.is_processing_shortcut_input()
		])
		if _source.has_method("cancel"): _source.call("cancel")
		_source.set_process_input(false)
		_source.set_process_unhandled_input(false)
		_source.set_process_unhandled_key_input(false)
		_source.set_process_shortcut_input(false)
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if is_instance_valid(focus) else null
	opened = true
	root.show()
	set_process_input(true)
	close_button.grab_focus()

func close() -> void:
	if not opened: return
	opened = false
	root.hide()
	set_process_input(false)
	_restore_source()
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	_previous_focus = null
	closed.emit()

func _restore_source() -> void:
	if is_instance_valid(_source) and _input_flags.size() == 4:
		_source.set_process_input(_input_flags[0])
		_source.set_process_unhandled_input(_input_flags[1])
		_source.set_process_unhandled_key_input(_input_flags[2])
		_source.set_process_shortcut_input(_input_flags[3])
	_source = null
	_input_flags.clear()

func _exit_tree() -> void:
	_restore_source()

func _input(event: InputEvent) -> void:
	if not opened: return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()

func _story_content() -> Dictionary:
	return content

func _build_ui() -> void:
	var content := _story_content()
	root = StoryPanel.new()
	root.name = content.get("name", "ChapterStory")
	root.story_title = content.title
	root.paragraphs = content.paragraphs
	root.illustration_script = content.get("illustration")
	add_child(root)
	close_button = root.close_button
	root.close_requested.connect(close)
