extends CanvasLayer
## Optional chapter-two story; leaves assembly and ship input ownership unchanged.
const Friendly = preload("res://shared/ui/friendly_theme.gd")
const Fonts = preload("res://shared/chinese_fonts.gd")
const Illustration = preload("res://levels/level02/bulkhead_diagram.gd")
const SHIPYARD = preload("res://shared/assets/shipyard_background.png")
const STORY_TITLE := "水密隔舱"
const STORY_PARAGRAPHS := [
	"龙骨像脊梁，船板合成外壳。舱内再用横向隔板分成多个舱位，就像给船装上一道道内墙。",
	"一处船板破损时，密封良好的隔板能限制水向其他舱扩散，为处置险情争取时间。",
	"榫卯把木材接在一起，艌密工艺把板缝封好。船匠会在缝里填入麻料，配合桐油灰等材料密封，再把船放进水里检查。",
	"看看刚才的船段：隔板沿两侧船壳和底板相接，青色线表示需要密封的边缘。"
]
var opened := false
var close_button: Button
var _root: Control
var _source: Node
var _flags: Array[bool] = []
var _previous_focus: Control
var _reading_font: Font
var _frame: PanelContainer
var _spread: GridContainer
var _left_page: VBoxContainer
var _image_frame: PanelContainer
var _title: Label
var _quote: PanelContainer
var _scroll: ScrollContainer
var _card_style: StyleBoxFlat
var _reading_style: StyleBoxFlat

func _ready() -> void:
	layer = 35
	_build_ui()
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

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BulkheadStory"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.mouse_force_pass_scroll_events = false
	_root.theme = Friendly.make_theme(true)
	_root.theme.default_font = Fonts.font(600)
	_reading_font = Fonts.font(400)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color("30251c")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_force_pass_scroll_events = false
	_root.add_child(shade)
	var shipyard := TextureRect.new()
	shipyard.texture = SHIPYARD
	shipyard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shipyard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shipyard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shipyard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(shipyard)
	var wash := ColorRect.new()
	wash.color = Color(.16, .11, .07, .72)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(wash)
	_frame = PanelContainer.new()
	_frame.name = "StoryCard"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color("fbf3e5")
	_card_style.border_color = Color("c4a575")
	_card_style.set_border_width_all(1)
	_card_style.set_corner_radius_all(12)
	_card_style.shadow_color = Color(0.07, 0.04, 0.02, .45)
	_card_style.shadow_size = 30
	_card_style.shadow_offset = Vector2(0, 12)
	_frame.add_theme_stylebox_override("panel", _card_style)
	_root.add_child(_frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 20)
	_frame.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	stack.add_child(header)
	var eyebrow := _label(header, "船匠的小课堂", 16, Color("8c7252"), true)
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button = Button.new()
	close_button.name = "CloseStory"
	close_button.text = "返回船板装配"
	close_button.tooltip_text = "返回船板装配（Esc）"
	close_button.custom_minimum_size = Vector2(172, 44)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.add_theme_font_override("font", _reading_font)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("f3e7d3") if state == "normal" else Color("ead7b8")
		button_style.border_color = Color("c9ae84") if state == "normal" else Color("a58251")
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(8)
		button_style.content_margin_left = 14
		button_style.content_margin_right = 14
		button_style.content_margin_top = 8
		button_style.content_margin_bottom = 8
		close_button.add_theme_stylebox_override(state, button_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close_button.add_theme_color_override(state, Color("59432e"))
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("ac8247")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(8)
	close_button.add_theme_stylebox_override("focus", focus_style)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_spread = GridContainer.new()
	_spread.name = "StorySpread"
	_spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spread.add_theme_constant_override("h_separation", 28)
	_spread.add_theme_constant_override("v_separation", 20)
	stack.add_child(_spread)
	_left_page = VBoxContainer.new()
	_left_page.name = "StoryPicturePage"
	_left_page.add_theme_constant_override("separation", 24)
	_spread.add_child(_left_page)
	_title = _label(_left_page, STORY_TITLE, 38, Color("493321"))
	_title.name = "StoryTitle"
	var picture_center := CenterContainer.new()
	picture_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_page.add_child(picture_center)
	_image_frame = PanelContainer.new()
	_image_frame.name = "StoryImageFrame"
	_image_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var image_style := StyleBoxFlat.new()
	image_style.bg_color = Color("e3ccaa")
	image_style.border_color = Color("b99a70")
	image_style.set_border_width_all(1)
	image_style.set_corner_radius_all(6)
	for edge in ["left", "right", "top", "bottom"]:
		image_style.set("content_margin_" + edge, 4.0)
	_image_frame.add_theme_stylebox_override("panel", image_style)
	picture_center.add_child(_image_frame)
	var illustration := Illustration.new()
	illustration.name = "StoryIllustration"
	_image_frame.add_child(illustration)
	_quote = PanelContainer.new()
	_quote.name = "StoryQuote"
	var quote_style := StyleBoxFlat.new()
	quote_style.bg_color = Color.TRANSPARENT
	quote_style.border_color = Color("b89357")
	quote_style.border_width_left = 2
	quote_style.content_margin_left = 18
	quote_style.content_margin_top = 4
	quote_style.content_margin_bottom = 4
	_quote.add_theme_stylebox_override("panel", quote_style)
	_left_page.add_child(_quote)
	var quote := _label(_quote, "榫卯把木材接在一起，\n艌密工艺把板缝封好。", 22, Color("8b643a"), true)
	quote.add_theme_constant_override("line_spacing", 8)
	var reading_page := PanelContainer.new()
	reading_page.name = "StoryReadingCard"
	reading_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reading_style = StyleBoxFlat.new()
	_reading_style.bg_color = Color.TRANSPARENT
	_reading_style.border_color = Color("deccb0")
	reading_page.add_theme_stylebox_override("panel", _reading_style)
	_spread.add_child(reading_page)
	_scroll = ScrollContainer.new()
	_scroll.name = "StoryScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading_page.add_child(_scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 22)
	_scroll.add_child(words)
	for index in STORY_PARAGRAPHS.size():
		var paragraph := _label(words, STORY_PARAGRAPHS[index], 24, Color("514332"), true)
		paragraph.name = "StoryParagraph%d" % (index + 1)
		paragraph.add_theme_constant_override("line_spacing", 8)
	var bar := _scroll.get_v_scroll_bar()
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var handle := StyleBoxFlat.new()
		handle.bg_color = Color("bda278") if state == "grabber" else Color("937044")
		handle.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(state, handle)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("eee1cb")
	track.content_margin_left = 4
	track.content_margin_right = 4
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("scroll", track)
	_root.resized.connect(_fit_story)
	_fit_story()

func _fit_story() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < 900
	var padding := 24 if viewport_size.x < 1200 else 32
	var card_width := minf(viewport_size.x - 48, 1320)
	var card_height := minf(viewport_size.y - 48, 760 if narrow else 660)
	_frame.offset_left = -card_width * .5
	_frame.offset_right = card_width * .5
	_frame.offset_top = -card_height * .5
	_frame.offset_bottom = card_height * .5
	for edge in ["left", "right", "top", "bottom"]:
		_card_style.set("content_margin_" + edge, float(padding))
	_spread.columns = 1 if narrow else 2
	var inner_width := card_width - padding * 2
	var picture_width := minf(inner_width, 480) if narrow else floorf((inner_width - 28) * .48)
	_left_page.custom_minimum_size.x = 0 if narrow else picture_width
	_left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	_left_page.add_theme_constant_override("separation", 14 if narrow else 24)
	_image_frame.custom_minimum_size.x = picture_width
	_title.add_theme_font_size_override("font_size", 28 if narrow else (32 if viewport_size.x < 1200 else 38))
	_quote.visible = not narrow
	_reading_style.border_width_left = 0 if narrow else 1
	_reading_style.border_width_top = 1 if narrow else 0
	_reading_style.content_margin_left = 0 if narrow else 28
	_reading_style.content_margin_top = 16 if narrow else 0
	_reading_style.content_margin_right = 12
	for paragraph in _scroll.find_children("StoryParagraph*", "Label", true, false):
		paragraph.add_theme_font_size_override("font_size", 22 if viewport_size.x < 1200 else 24)

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
