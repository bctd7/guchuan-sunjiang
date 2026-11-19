extends Control
## Shared observation layout; no chapter state, geometry, or acceptance rules.
const RoundedPreview=preload("res://components/preview/rounded_preview.gdshader")
const Friendly=preload("res://components/ui/friendly_theme.gd")
const Controls=preload("res://components/ui/chapter_ui.gd")
var header: HBoxContainer
var title: Label
var candidates: VBoxContainer
var camera_actions: HBoxContainer
var camera_tools: HBoxContainer
var stage_surface: Control
var viewport_container: SubViewportContainer
var options: VBoxContainer
var actions: HBoxContainer
var status: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=Friendly.make_theme(true)
	var shade:=ColorRect.new()
	shade.color=Color("f7ead5")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel:=PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=14;panel.offset_right=-14;panel.offset_top=14;panel.offset_bottom=-14
	panel.add_theme_stylebox_override("panel",frame_style(24))
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",16)
	panel.add_child(stack)
	header=HBoxContainer.new();header.add_theme_constant_override("separation",24);header.custom_minimum_size.y=66;stack.add_child(header)
	title=label(header,"",34);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL

	candidates=VBoxContainer.new();stack.add_child(candidates)
	var middle:=HBoxContainer.new();middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation",16);stack.add_child(middle)
	var stage_panel:=PanelContainer.new();stage_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;middle.add_child(stage_panel)
	stage_panel.add_theme_stylebox_override("panel",frame_style(12))
	var stage_column:=VBoxContainer.new();stage_panel.add_child(stage_column)
	stage_surface=Control.new();stage_surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stage_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage_surface.custom_minimum_size=Vector2(0,330);stage_column.add_child(stage_surface)
	var separator:=HSeparator.new();stage_column.add_child(separator)
	camera_actions=HBoxContainer.new();camera_actions.add_theme_constant_override("separation",12);camera_actions.custom_minimum_size.y=72;stage_column.add_child(camera_actions)
	viewport_container=SubViewportContainer.new();viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch=true;viewport_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage_surface.add_child(viewport_container)
	var rounded := ShaderMaterial.new()
	rounded.shader = RoundedPreview
	viewport_container.material = rounded
	viewport_container.resized.connect(func(): rounded.set_shader_parameter("rect_size", viewport_container.size))
	var options_panel:=PanelContainer.new();middle.add_child(options_panel)
	options_panel.add_theme_stylebox_override("panel",frame_style(12))
	options=VBoxContainer.new();options.custom_minimum_size.x=450;options.add_theme_constant_override("separation",12);options_panel.add_child(options)
	actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);camera_actions.add_child(actions)
	status=label(stage_column,"",19);status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stage_column.move_child(status,2)

func label(parent: Node,text: String,font_size: int) -> Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);parent.add_child(node);return node
func button(parent: Node,text: String) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(140,60);parent.add_child(node);return node
static func neutral_selection(button: Button) -> void:
	for state in ["pressed","hover_pressed"]:button.add_theme_stylebox_override(state,Friendly.block(Color("e4e8d5"),Color("80986b"),2))

func mount_camera_tools(bar: HBoxContainer) -> void:
	camera_tools=bar
	camera_actions.add_theme_constant_override("separation",18)
	camera_actions.custom_minimum_size.y=68
	var reset_group:=HBoxContainer.new()
	reset_group.alignment=BoxContainer.ALIGNMENT_CENTER
	reset_group.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	camera_actions.add_child(reset_group)
	camera_actions.move_child(reset_group,0)
	bar.reset_button.reparent(reset_group)
	bar.reset_button.icon=null
	bar.reset_button.text="↻  重置视角"
	bar.reset_button.add_theme_stylebox_override("normal",Friendly.block(Color("eee3c3"),Color("738b60"),2))
	bar.reparent(camera_actions)
	camera_actions.move_child(bar,1)
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.alignment=BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation",10)
	bar.percentage.custom_minimum_size.x=68
	bar.percentage.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bar.percentage.add_theme_font_size_override("font_size",20)
	actions.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.size_flags_stretch_ratio=1.25
	actions.alignment=BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",16)
	for index in [1,3]:
		var divider:=VSeparator.new()
		divider.custom_minimum_size.y=40
		divider.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var line:=StyleBoxLine.new();line.color=Color("c8b895");line.thickness=1;line.vertical=true
		divider.add_theme_stylebox_override("separator",line)
		camera_actions.add_child(divider);camera_actions.move_child(divider,index)
	layout_camera_tools(1.0)

func layout_camera_tools(display_scale: float) -> void:
	if not is_instance_valid(camera_tools):return
	var height:=maxf(56,60/display_scale)
	camera_tools.reset_button.custom_minimum_size=Vector2(194,height)
	for button in [camera_tools.zoom_in,camera_tools.zoom_out]:button.custom_minimum_size=Vector2(height,height)
	for button in actions.get_children():
		if button is Button:button.custom_minimum_size=Vector2(148,height)
	var buttons: Array=[camera_tools.reset_button,camera_tools.zoom_in,camera_tools.zoom_out]
	buttons.append_array(actions.get_children())
	for button in buttons:
		if button is Button:
			button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			button.add_theme_font_size_override("font_size",20)
	for group in [camera_tools,actions]:group.size_flags_vertical=Control.SIZE_SHRINK_CENTER

static func frame_style(padding: float) -> StyleBoxFlat:
	var style=Friendly.block(Color("fff7e9"),Color("cbb899"),1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left=padding;style.content_margin_right=padding
	style.content_margin_top=padding;style.content_margin_bottom=padding
	style.shadow_size=3;style.shadow_offset=Vector2(0,3)
	return style

func fit_screen(nested := false) -> void:
	var dimensions=get_viewport().get_visible_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	if nested:
		var parent_scale=get_parent().get_global_transform().get_scale().x
		size=dimensions/parent_scale
		position=-get_parent().position/parent_scale
	else:
		var factor=minf(dimensions.x/1600.0,dimensions.y/900.0)
		scale=Vector2.ONE*factor;size=dimensions/factor;position=Vector2.ZERO

func show_feedback(message: String, error := false) -> void:
	# Keep the feedback row in the layout so clearing it does not interrupt a drag.
	Controls.feedback(status, message, error)
	status.show()
