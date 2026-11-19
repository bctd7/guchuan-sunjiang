extends Control
## Pure lesson introduction. No source scene, gameplay state or classroom ownership.
const SIDE_MARGIN := 32
signal start_requested
signal lesson_requested(id: String)
const Friendly = preload("res://components/ui/friendly_theme.gd")
const ModelPreview = preload("res://components/teaching/classroom/display/lesson_model_preview.gd")
const LESSON_COPY = preload("res://components/teaching/classroom/content/lesson_copy.gd").LESSON_COPY
var _intro: Control
var _heading: Label
var _scroll: ScrollContainer
var _cards: GridContainer
var start_button: Button
var lesson_buttons: Dictionary = {}
var previews: Dictionary = {}
var lesson_ids: Array[String] = []

func configure(ids: Array[String]) -> void:
	lesson_ids.assign(ids)
	_build_cards()

func _ready() -> void:
	_intro = self
	_intro.name = "ChapterIntroduction"
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.mouse_force_pass_scroll_events = false
	_intro.theme = Friendly.make_theme(true)
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
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge,SIDE_MARGIN)
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
	_scroll=preload("res://components/ui/reading_scroll.gd").new()
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
	start_button.pressed.connect(func(): start_requested.emit())
	footer.add_child(start_button)
	get_viewport().size_changed.connect(_layout_cards)
	tree_entered.connect(_layout_cards.call_deferred)
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
		observe.custom_minimum_size=Vector2(220,64)
		observe.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		observe.pressed.connect(func(): lesson_requested.emit(id))
		content.add_child(observe)
		lesson_buttons[id]=observe
	_layout_cards()

func _layout_cards() -> void:
	if not is_inside_tree():return
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

