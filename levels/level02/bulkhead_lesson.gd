extends CanvasLayer
## Optional chapter-two reading, with the same input/focus restoration as the story.
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Illustration=preload("res://levels/level02/bulkhead_diagram.gd")
var opened := false
var close_button: Button
var _root: Control
var _source: Node
var _flags: Array[bool]=[]
var _previous_focus: Control
func _ready() -> void:
	layer=35
	_root=Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme=Friendly.make_theme(true)
	add_child(_root)
	var shade:=ColorRect.new()
	shade.color=Color(.20,.17,.12,.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
	_root.add_child(margin)
	var center:=CenterContainer.new()
	margin.add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(300,0)
	panel.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("c8b895"),2))
	center.add_child(panel)
	var layout:=VBoxContainer.new()
	layout.add_theme_constant_override("separation",14)
	panel.add_child(layout)
	var title:=Label.new()
	title.text="船匠的小课堂 · 水密隔舱"
	title.add_theme_font_size_override("font_size",28)
	layout.add_child(title)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(0,290)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",15)
	scroll.add_child(content)
	var picture:=Illustration.new()
	content.add_child(picture)
	for paragraph in ["龙骨像脊梁，船板合成外壳。舱内再用横向隔板分成多个舱位，就像给船装上一道道内墙。","一处船板破损时，密封良好的隔板能限制水向其他舱扩散，为处置险情争取时间；这并不保证船永远不会沉。","榫卯负责连接木材，水密还靠艌密工艺。板缝需要填入麻料、配合桐油灰等材料密封，并检查工艺与实体试水。","看看刚才的船段：隔板沿两侧船壳和底板相接，青色线表示需要密封的边缘；浅水与海浪只是教学示意。"]:
		var label:=Label.new()
		label.text=paragraph
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",20)
		content.add_child(label)
	close_button=Button.new()
	close_button.text="返回船板装配"
	close_button.custom_minimum_size.y=54
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	get_viewport().size_changed.connect(func():
		panel.custom_minimum_size.x=minf(820,get_viewport().get_visible_rect().size.x-48)
		scroll.custom_minimum_size.y=clampf(get_viewport().get_visible_rect().size.y-230,180,510))
	panel.custom_minimum_size.x=minf(820,get_viewport().get_visible_rect().size.x-48)
	scroll.custom_minimum_size.y=clampf(get_viewport().get_visible_rect().size.y-230,180,510)
	hide()
func show_lesson(interaction: Node) -> void:
	if opened: return
	_source=interaction
	_previous_focus=get_viewport().gui_get_focus_owner()
	_flags.assign([interaction.is_processing_input(),interaction.is_processing_unhandled_input()])
	interaction.cancel()
	interaction.set_process_input(false)
	interaction.set_process_unhandled_input(false)
	opened=true
	show()
	close_button.grab_focus()
func close() -> void:
	if not opened:return
	opened=false
	hide()
	if is_instance_valid(_source) and _flags.size()==2:
		_source.set_process_input(_flags[0])
		_source.set_process_unhandled_input(_flags[1])
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree(): _previous_focus.grab_focus()
func _unhandled_key_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	close()
