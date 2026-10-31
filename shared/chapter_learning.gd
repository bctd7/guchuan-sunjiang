extends CanvasLayer
## A read-only doorway into the original lessons; owns no ship or campaign state.
const Friendly = preload("res://demo/friendly_theme.gd")
const ModelPreview=preload("res://shared/lesson_model_preview.gd")
const Workshop = preload("res://demo/workshop.gd")
const CHAPTER_LESSONS := {
	1: ["dovetail", "blind_tenon", "through_tenon"],
	2: ["cross_lap", "tongue_groove", "three_way_lap"],
	3: ["zong_corner", "clamp_head", "l_through"]
}
const LESSON_COPY := {
	"dovetail": ["燕尾榫", "榫头外宽内窄，沿槽口滑入；燕尾形让连接不易横向脱开。"],
	"blind_tenon": ["半榫", "榫孔有底，榫头藏在木料里面；留意孔底与插入深度。"],
	"through_tenon": ["透榫", "榫孔贯穿木料，榫头从另一侧露出；比较它与半榫的孔底。"],
	"cross_lap": ["搭扣榫", "两根木料各让出一部分，在交叉处搭合；观察重叠的承托面。"],
	"tongue_groove": ["企口榫", "一边凸舌、一边凹槽，沿板边接合；观察连续的接缝。"],
	"three_way_lap": ["扣合榫", "三根木料在同一处交会，分层让位；观察各自的搭接次序。"],
	"zong_corner": ["粽角榫", "三向木料在转角处互相咬合；观察角部如何藏住榫头。"],
	"clamp_head": ["夹头榫", "竖向木料以开口夹住横材；观察两侧夹持与中间的承托。"],
	"l_through": ["穿榫", "两根木料成直角，榫头穿过对应榫孔；观察穿出的端面。"]
}

var opened := false
var workshop: Node3D
var start_button: Button
var lesson_buttons: Dictionary = {}
var back_button: Button
var source_view: Node3D
var source_panel: CanvasLayer
var source_interaction: Node
var chapter := 1
var lesson_ids: Array[String] = []
var previews: Dictionary = {}
var _intro: Control
var _heading: Label
var _scroll: ScrollContainer
var _cards: GridContainer
var _started := false
var _suspended := false
var _view_visible := true
var _panel_visible := true
var _input_enabled := true
var _unhandled_enabled := true
var _key_enabled := true
var _camera: Camera3D

func _ready() -> void:
	layer = 40
	_build_ui()
	_intro.hide()
	back_button.hide()

func configure(value: int, view: Node3D, panel: CanvasLayer, interaction: Node = null) -> void:
	if modal_open(): _leave_intro()
	chapter = clampi(value, 1, 3)
	source_view = view
	source_panel = panel
	source_interaction = interaction
	lesson_ids.assign(CHAPTER_LESSONS[chapter])
	_started = false
	_build_cards()
	show_intro()

func modal_open() -> bool:
	return opened or is_instance_valid(workshop)

func show_intro() -> void:
	if not is_instance_valid(_intro): return
	_close_workshop()
	_suspend_source()
	opened = true
	_heading.text = "第 %d 关 · 先认识这三种榫卯" % chapter
	start_button.text = "返回船体局部" if _started else "开始本关"
	_intro.show()
	back_button.hide()
	start_button.grab_focus()

func _build_ui() -> void:
	_intro = Control.new()
	_intro.name = "ChapterIntroduction"
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.mouse_force_pass_scroll_events = false
	_intro.theme = Friendly.make_theme(true)
	add_child(_intro)
	var shade := TextureRect.new()
	var wash := GradientTexture2D.new()
	wash.gradient=Gradient.new()
	wash.gradient.colors=PackedColorArray([Color("f3e8d2"),Color("e4d2b1")])
	wash.fill_from=Vector2(0,0)
	wash.fill_to=Vector2(0,1)
	shade.texture=wash
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	_intro.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge,32)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge,28)
	_intro.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",20)
	margin.add_child(stack)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation",10)
	stack.add_child(heading)
	_label(heading,"古船榫匠 · 开工之前",18)
	_heading = _label(heading,"",32)
	_label(heading,"先看清榫头与槽口。轻点“观察此榫卯”，可以走近看看它怎样连接。",19)
	_scroll=ScrollContainer.new()
	_scroll.name="LessonScroll"
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_force_pass_scroll_events=false
	stack.add_child(_scroll)
	_cards=GridContainer.new()
	_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_cards.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation",20)
	_cards.add_theme_constant_override("v_separation",18)
	_scroll.add_child(_cards)
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",24)
	stack.add_child(footer)
	var hint:=_label(footer,"看懂这三种连接，就去搭建船的一部分吧。",19)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	start_button=Button.new()
	start_button.name="StartChapter"
	start_button.custom_minimum_size=Vector2(280,62)
	start_button.add_theme_font_size_override("font_size",23)
	start_button.add_theme_stylebox_override("normal",Friendly.block(Color("bacbaa"),Color("8da37a")))
	start_button.pressed.connect(_leave_intro)
	footer.add_child(start_button)
	back_button=Button.new()
	back_button.name="BackToChapterIntroduction"
	back_button.text="返回本关三种介绍"
	back_button.theme=Friendly.make_theme(true)
	back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back_button.offset_left=-250
	back_button.offset_right=-20
	back_button.offset_top=16
	back_button.offset_bottom=72
	back_button.pressed.connect(show_intro)
	add_child(back_button)
	get_viewport().size_changed.connect(_layout_cards)
	_layout_cards()

func _build_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	lesson_buttons.clear()
	previews.clear()
	for id in lesson_ids:
		var card:=PanelContainer.new()
		card.name=id
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var paper:=Friendly.block(Color("f9efd9"),Color("dfccaa"),2)
		paper.set_border_width_all(1)
		paper.set_corner_radius_all(24)
		paper.shadow_size=6
		paper.content_margin_top=22
		paper.content_margin_bottom=22
		card.add_theme_stylebox_override("panel",paper)
		_cards.add_child(card)
		var content:=VBoxContainer.new()
		content.add_theme_constant_override("separation",14)
		card.add_child(content)
		_label(content,str(LESSON_COPY[id][0]),27)
		var preview:=ModelPreview.new()
		preview.name="OriginalModelPreview"
		preview.custom_minimum_size=Vector2(0,240)
		preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
		content.add_child(preview)
		preview.configure(id)
		previews[id]=preview
		var note:=_label(content,str(LESSON_COPY[id][1]),18)
		note.custom_minimum_size.y=70
		var observe:=Button.new()
		observe.text="观察此榫卯"
		observe.custom_minimum_size=Vector2(220,52)
		observe.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		observe.pressed.connect(_open_lesson.bind(id))
		content.add_child(observe)
		lesson_buttons[id]=observe
	_layout_cards()

func _layout_cards() -> void:
	if not is_instance_valid(_cards): return
	var dimensions:=get_viewport().get_visible_rect().size
	var wide:=dimensions.x>=900
	_cards.columns=3 if wide else 1
	_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED if wide and dimensions.y>=720 else ScrollContainer.SCROLL_MODE_AUTO

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _open_lesson(id: String) -> void:
	if not lesson_ids.has(id): return
	_close_workshop()
	_suspend_source()
	opened = false
	_intro.hide()
	workshop = Workshop.new()
	workshop.name = "ChapterWorkshop"
	workshop.lesson_filter.assign(lesson_ids)
	add_child(workshop)
	var index := lesson_ids.find(id)
	workshop.picker.select(index)
	workshop.load_joint(index)
	workshop.camera.make_current()
	back_button.show()
	back_button.grab_focus()

func _close_workshop() -> void:
	if not is_instance_valid(workshop): return
	# CanvasLayer descendants do not inherit a Node3D's visibility. Free the
	# complete embedded classroom before revealing the introduction again.
	remove_child(workshop)
	workshop.queue_free()
	workshop = null
	back_button.hide()
	_restore_camera()

func _suspend_source() -> void:
	if _suspended: return
	_suspended = true
	_camera = get_viewport().get_camera_3d()
	if is_instance_valid(source_view):
		_view_visible = source_view.visible
		source_view.hide()
	if is_instance_valid(source_panel):
		_panel_visible = source_panel.visible
		source_panel.hide()
	if is_instance_valid(source_interaction):
		_input_enabled = source_interaction.is_processing_input()
		_unhandled_enabled = source_interaction.is_processing_unhandled_input()
		_key_enabled = source_interaction.is_processing_unhandled_key_input()
		if source_interaction.has_method("cancel"): source_interaction.cancel()
		source_interaction.set_process_input(false)
		source_interaction.set_process_unhandled_input(false)
		source_interaction.set_process_unhandled_key_input(false)

func _restore_camera() -> void:
	if is_instance_valid(source_view):
		var source_camera = source_view.get("camera")
		if source_camera is Camera3D:
			source_camera.make_current()
			return
	if is_instance_valid(_camera): _camera.make_current()

func _restore_source() -> void:
	if not _suspended: return
	_suspended = false
	if is_instance_valid(source_view): source_view.visible = _view_visible
	if is_instance_valid(source_panel): source_panel.visible = _panel_visible
	if is_instance_valid(source_interaction):
		source_interaction.set_process_input(_input_enabled)
		source_interaction.set_process_unhandled_input(_unhandled_enabled)
		source_interaction.set_process_unhandled_key_input(_key_enabled)
	_restore_camera()

func _leave_intro() -> void:
	_close_workshop()
	opened = false
	_started = true
	_intro.hide()
	back_button.hide()
	_restore_source()

func _unhandled_key_input(event: InputEvent) -> void:
	if modal_open() and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(workshop): show_intro()
		else: _leave_intro()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_restore_source()
