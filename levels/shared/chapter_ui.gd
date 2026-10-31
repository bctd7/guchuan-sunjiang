extends RefCounted
## Common chapter controls; no game rules, state or layout decisions.
const Friendly = preload("res://demo/friendly_theme.gd")
const ERROR_COLOR := Color("a1432e")
const FEEDBACK_COLOR := Color("325c4d")

static func panel(parent: Node, rect: Rect2) -> PanelContainer:
	var control := PanelContainer.new()
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size
	control.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("d4c6a6"),2))
	return control

static func label(parent: Node, text: String, font_size: int) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size",font_size)
	parent.add_child(control)
	return control

static func button(parent: Node, text: String) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(0,48)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)
	return control

static func feedback(control: Label, message: String, error := false) -> void:
	control.text = message
	control.modulate = ERROR_COLOR if error else FEEDBACK_COLOR
