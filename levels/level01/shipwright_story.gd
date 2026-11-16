extends CanvasLayer
## Optional, read-only story. Owns no ship, camera, assembly, or campaign state.
signal closed

const Friendly = preload("res://shared/ui/friendly_theme.gd")
const Fonts = preload("res://shared/chinese_fonts.gd")
const STORY_TITLE := "龙骨里的七星伴月"
const STORY_PARAGRAPHS := [
	"福建泉州出土的一艘宋代古船，龙骨接头里藏着一个小秘密：七个小孔里放着钱币，另一个大孔里放着铜镜。小孔排成北斗七星的样子，圆圆的铜镜像满月，人们把它叫作“七星伴月”，寄托着平安出海的心愿。",
	"让我们沿着这个发现，想象一个造船的早晨。海风吹动帆角，船场传来笃、笃、笃的敲木声。小帮手阿禾蹲在船匠师傅身边，看见木头上摆着钱币和铜镜，好奇地问：“船还没出海，怎么先把星星请来了？”",
	"师傅笑了：“你数数看。”阿禾伸出手指，一枚、两枚……正好七枚！他顺着钱币的排列看过去：“这几颗连起来，像一把长柄勺子！”师傅又指了指旁边的铜镜：“再加上这轮小月亮，便是七星伴月。我们把盼望平安的心愿，藏进船里。”",
	"阿禾看看大船，又望望远处的海：“有了星星和月亮，船就不怕风浪了吗？”师傅摇摇头：“心愿很美好，木头也要接得牢。哪一处没对齐，哪一段没装稳，都要仔细看看。出海的人，还得留心天气，懂得掌舵。”阿禾明白了：祝福装在心里，功夫用在手上。",
	"他低头望着龙骨。长长的龙骨像船底的脊梁，一根根船肋向两边伸开，仿佛大船慢慢张开了怀抱。刚才只顾着找星星的阿禾，这回认真看起木头的接头：“师傅，这里也要接得稳稳的！”",
	"海风又吹来了。阿禾想，等船扬起帆，钱币和铜镜会静静留在龙骨里，陪着船上的人去远方。现在，再看看画里的七枚钱币与铜镜：你能找到那把长柄勺子吗？大船带走的不只是货物，还有岸上人盼它平安归来的心愿。"
]
const Illustration=preload("res://levels/level01/seven_stars_illustration.gd")

var opened := false
var close_button: Button
var root: Control
var _source: Node
var _input_flags: Array[bool] = []
var _previous_focus: WeakRef
var _reading_font: Font

func _ready() -> void:
	layer = 35
	_build_ui()
	root.hide()
	set_process_input(false)

func show_story(source_interaction: Node = null) -> void:
	if opened: return
	if not is_instance_valid(root): return
	_source = source_interaction
	_input_flags.clear()
	if is_instance_valid(_source):
		_input_flags.assign([
			_source.is_processing_input(), _source.is_processing_unhandled_input(),
			_source.is_processing_unhandled_key_input(), _source.is_processing_shortcut_input()
		])
		if _source.has_method("cancel"): _source.call("cancel")
		_source.set_process_input(false)
		_source.set_process_unhandled_input(false)
		_source.set_process_unhandled_key_input(false)
		_source.set_process_shortcut_input(false)
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if is_instance_valid(focus) else null
	opened = true
	root.show()
	set_process_input(true)
	close_button.grab_focus()

func close() -> void:
	if not opened: return
	opened = false
	root.hide()
	set_process_input(false)
	_restore_source()
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	_previous_focus = null
	closed.emit()

func _restore_source() -> void:
	if is_instance_valid(_source) and _input_flags.size() == 4:
		_source.set_process_input(_input_flags[0])
		_source.set_process_unhandled_input(_input_flags[1])
		_source.set_process_unhandled_key_input(_input_flags[2])
		_source.set_process_shortcut_input(_input_flags[3])
	_source = null
	_input_flags.clear()

func _exit_tree() -> void:
	_restore_source()

func _input(event: InputEvent) -> void:
	if not opened: return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()

func _build_ui() -> void:
	root = Control.new()
	root.name = "ShipwrightStory"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_force_pass_scroll_events = false
	root.theme = Friendly.make_theme(true)
	root.theme.default_font = Fonts.font(600)
	_reading_font = Fonts.font(400)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.16, 0.20, 0.17, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_force_pass_scroll_events = false
	root.add_child(shade)
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
	root.resized.connect(fit_card)
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
	root.add_child(frame)
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
	_label(heading, STORY_TITLE, 34)
	close_button = Button.new()
	close_button.name = "CloseStory"
	close_button.text = "关闭"
	close_button.tooltip_text = "关闭小故事（Esc）"
	close_button.custom_minimum_size = Vector2(84, 44)
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
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
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
	var illustration:=Illustration.new()
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
	for index in STORY_PARAGRAPHS.size():
		var paragraph_label := _label(words, STORY_PARAGRAPHS[index], 24, Friendly.INK, true)
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
