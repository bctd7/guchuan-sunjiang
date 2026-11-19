extends Control
## Shared story presentation, matching chapter one's approved reading card.
## Input suspension and assembly state remain owned by the chapter overlays.
signal close_requested
const Friendly = preload("res://components/ui/friendly_theme.gd")
const Fonts = preload("res://components/ui/chinese_fonts.gd")
var story_title: String
var paragraphs: Array
var illustration_script: Script
var close_button: Button
var scroll: ScrollContainer
var _reading_font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	theme = Friendly.make_theme(true)
	theme.default_font = Fonts.font(600)
	_reading_font = Fonts.font(400)
	var shade := ColorRect.new()
	shade.color = Color(0.16, 0.20, 0.17, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_force_pass_scroll_events = false
	add_child(shade)
	var frame := PanelContainer.new()
	frame.name = "StoryCard"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.5
	var fit_card := func():
		var viewport_size := get_viewport().get_visible_rect().size
		var half_width := minf(viewport_size.x * .45, 530)
		var half_height := minf(viewport_size.y * .44, 370)
		frame.offset_left = -half_width
		frame.offset_right = half_width
		frame.offset_top = -half_height
		frame.offset_bottom = half_height
	resized.connect(fit_card)
	fit_card.call()
	var card_style := Friendly.block(Color("fff9ee"), Color("ccb99a"), 2)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(20)
	card_style.shadow_color = Color(0.10, 0.13, 0.09, 0.25)
	card_style.shadow_size = 28
	card_style.shadow_offset = Vector2(0, 12)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 28
	frame.add_theme_stylebox_override("panel", card_style)
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 20)
	frame.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	stack.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 4)
	header.add_child(heading)
	_label(heading, "船匠小故事", 16, Color("7c806a"), true)
	_label(heading, story_title, 34)
	close_button = Button.new()
	close_button.name = "CloseStory"
	close_button.text = "关闭"
	close_button.tooltip_text = "关闭小故事（Esc）"
	close_button.custom_minimum_size = Vector2(96, 64)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_font_override("font", _reading_font)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("f4eddf") if state == "normal" else Color("e3ecd9")
		button_style.border_color = Color("cdbfa8") if state == "normal" else Color("9cad8d")
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(14)
		button_style.content_margin_left = 14
		button_style.content_margin_right = 14
		button_style.content_margin_top = 8
		button_style.content_margin_bottom = 8
		close_button.add_theme_stylebox_override(state, button_style)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("849b73")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(14)
	close_button.add_theme_stylebox_override("focus", focus_style)
	close_button.pressed.connect(func():close_requested.emit())
	header.add_child(close_button)
	scroll = preload("res://components/ui/reading_scroll.gd").new()
	scroll.name = "StoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 16)
	scroll.add_child(pages)
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	pages.add_child(body)
	var figure:=VBoxContainer.new()
	figure.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	figure.add_theme_constant_override("separation", 4)
	body.add_child(figure)
	var image_frame := PanelContainer.new()
	image_frame.name = "StoryImageFrame"
	image_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var image_style := StyleBoxFlat.new()
	image_style.bg_color = Color("ead8bb")
	image_style.set_corner_radius_all(16)
	image_frame.add_theme_stylebox_override("panel", image_style)
	figure.add_child(image_frame)
	var illustration: Control
	if illustration_script:
		illustration = illustration_script.new()
	else:
		var placeholder := Label.new()
		placeholder.text = "故事配图待补充"
		placeholder.custom_minimum_size.y = 320
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size",24)
		placeholder.add_theme_color_override("font_color",Color("7c806a"))
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		illustration = placeholder
	illustration.name = "StoryIllustration"
	image_frame.add_child(illustration)
	var reading_card := PanelContainer.new()
	reading_card.name = "StoryReadingCard"
	var reading_style := StyleBoxFlat.new()
	reading_style.bg_color = Color("f1f2e8")
	reading_style.border_color = Color("dfdfce")
	reading_style.set_border_width_all(1)
	reading_style.set_corner_radius_all(14)
	reading_style.content_margin_left = 20
	reading_style.content_margin_right = 20
	reading_style.content_margin_top = 16
	reading_style.content_margin_bottom = 16
	reading_card.add_theme_stylebox_override("panel", reading_style)
	body.add_child(reading_card)
	var words:=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 14)
	reading_card.add_child(words)
	for index in paragraphs.size():
		var paragraph_label := _label(words, paragraphs[index], 24, Friendly.INK, true)
		paragraph_label.name = "StoryParagraph%d" % (index + 1)
		paragraph_label.add_theme_constant_override("line_spacing", 8)

func _label(parent: Node, text: String, font_size: int, color := Friendly.INK, reading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if reading:
		label.add_theme_font_override("font", _reading_font)
	parent.add_child(label)
	return label
