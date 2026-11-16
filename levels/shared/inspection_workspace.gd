extends Control
## Shared observation layout; no chapter state, geometry, or acceptance rules.
const Friendly=preload("res://shared/ui/friendly_theme.gd")
var header: HBoxContainer
var title: Label
var explanation: Label
var candidates: VBoxContainer
var stage_surface: Control
var viewport_container: SubViewportContainer
var options: VBoxContainer
var actions: HBoxContainer
var status: Label
var note: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=Friendly.make_theme(true)
	var shade:=ColorRect.new()
	shade.color=Color("e9dcc2")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel:=PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=24;panel.offset_right=-24;panel.offset_top=24;panel.offset_bottom=-24
	panel.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("c8b895"),2))
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	panel.add_child(stack)
	header=HBoxContainer.new();stack.add_child(header)
	title=label(header,"",27);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	explanation=label(stack,"",20);explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	candidates=VBoxContainer.new();stack.add_child(candidates)
	var middle:=HBoxContainer.new();middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation",16);stack.add_child(middle)
	stage_surface=Control.new();stage_surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stage_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage_surface.custom_minimum_size=Vector2(0,330);middle.add_child(stage_surface)
	viewport_container=SubViewportContainer.new();viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch=true;viewport_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage_surface.add_child(viewport_container)
	options=VBoxContainer.new();options.custom_minimum_size.x=345;options.add_theme_constant_override("separation",6);middle.add_child(options)
	actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);stack.add_child(actions)
	status=label(actions,"",19);status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note=label(stack,"",15);note.modulate=Color("73806d")
func label(parent: Node,text: String,font_size: int) -> Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);parent.add_child(node);return node
func button(parent: Node,text: String) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(140,52);parent.add_child(node);return node
static func neutral_selection(button: Button) -> void:
	for state in ["pressed","hover_pressed"]:button.add_theme_stylebox_override(state,Friendly.block(Color("dbe4e5"),Color("7b9098"),2))
