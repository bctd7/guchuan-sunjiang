extends CanvasLayer
## Current lesson lifecycle API. The artwork and visible controls contain no labels.
signal closed
signal lesson_visibility_changed(is_open: bool)
const Diagram = preload("res://classroom/science/dynamic/diagram.gd")
var panel: Control
var diagram: Control
var close_button: Button
var opened := false

func _ready() -> void:
	layer = 30
	_build()
	panel.hide()
	set_process(false)

func _build() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("f5f2e9")
	skin.content_margin_left = 20
	skin.content_margin_right = 20
	skin.content_margin_top = 16
	skin.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",skin)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(space)
	close_button = preload("res://shared/ui/joint_return_button.gd").create(close)
	top.add_child(close_button)
	diagram = Diagram.new()
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagram.custom_minimum_size.y = 180
	column.add_child(diagram)

func open_for_joint(joint_id: String = "dovetail") -> bool:
	if joint_id != "dovetail" or panel == null: return false
	diagram.replay()
	opened = true
	panel.show()
	set_process(true)
	lesson_visibility_changed.emit(true)
	close_button.grab_focus()
	return true

func close() -> void:
	opened = false
	diagram.playing = false
	set_process(false)
	panel.hide()
	lesson_visibility_changed.emit(false)
	closed.emit()

func set_paused(value: bool) -> void:
	# Lifecycle/test API only; no playback controls are shown.
	diagram.playing = opened and not value

func _process(delta: float) -> void:
	if opened: diagram.advance(delta)

func _input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func create_entry_button(assembly: Node) -> Button:
	var entry := Button.new()
	entry.text = "二维受力 · 燕尾榫"
	entry.pressed.connect(func(): open_for_joint(str(assembly.definition.get("id",""))))
	var refresh := func():
		entry.visible = str(assembly.definition.get("id","")) == "dovetail"
		if opened and not entry.visible: close()
	assembly.changed.connect(refresh)
	refresh.call()
	return entry
