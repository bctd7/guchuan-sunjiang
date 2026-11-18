extends CanvasLayer
signal lesson_visibility_changed(is_open: bool)
const Diagram = preload("res://classroom/science/force_gallery/zong_diagram.gd")
var profiles: Dictionary = {}
var panel: PanelContainer
var diagram: Control
var close_button: Button
var opened := false
var joint_id := ""

func _ready() -> void:
	layer = 30
	for profile in JSON.parse_string(FileAccess.get_file_as_string("res://classroom/science/force_gallery/profiles.json")):
		profiles[profile.id] = profile
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5f2e9")
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	close_button = preload("res://shared/ui/joint_return_button.gd").create(close)
	top.add_child(close_button)
	diagram = Diagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(diagram)
	panel.hide()
	set_process(false)

func show_joint(id: String) -> bool:
	if not profiles.has(id): return false
	joint_id = id
	diagram.configure(profiles[id])
	opened = true
	panel.show()
	set_process(true)
	lesson_visibility_changed.emit(true)
	close_button.grab_focus()
	return true

func close() -> void:
	if not opened: return
	opened = false
	diagram.clock.playing = false
	set_process(false)
	panel.hide()
	lesson_visibility_changed.emit(false)

func _process(delta: float) -> void:
	if opened: diagram.advance(delta)

func _input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
