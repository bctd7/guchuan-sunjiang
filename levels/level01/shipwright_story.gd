extends CanvasLayer
## Optional, read-only story. Owns no ship, camera, assembly, or campaign state.
signal closed

const Friendly = preload("res://demo/friendly_theme.gd")
const STORY_TITLE := "龙骨里的七星伴月"
const STORY_PARAGRAPHS := [
	"泉州出土的一艘宋代古船，龙骨接头处藏着一个小秘密：七个小孔里放着钱币，一个大孔里放着铜镜，合在一起，像七颗星星陪着月亮。这种排列被称为“七星伴月”，也寄托着平安出海的心愿。"
]
const Illustration=preload("res://levels/level01/seven_stars_illustration.gd")

var opened := false
var close_button: Button
var root: Control
var _source: Node
var _input_flags: Array[bool] = []
var _previous_focus: WeakRef
var _reading_font: SystemFont

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
	_reading_font = root.theme.default_font.duplicate() as SystemFont
	_reading_font.font_weight = 400
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.22, 0.25, 0.18, 0.64)
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
		var half_height := minf(viewport_size.y * .44, 300)
		frame.offset_left = -half_width
		frame.offset_right = half_width
		frame.offset_top = -half_height
		frame.offset_bottom = half_height
	root.resized.connect(fit_card)
	fit_card.call()
	var card_style := Friendly.block(Friendly.CREAM, Color("c9a479"), 5)
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", card_style)
	root.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	frame.add_child(stack)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	stack.add_child(heading)
	_label(heading, "船匠小故事  ·  自由阅读", 15, Color("718064"), true)
	_label(heading, STORY_TITLE, 32)
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
	var illustration:=Illustration.new()
	figure.add_child(illustration)
	_label(figure, "结构与故事示意 · 龙骨接头与藏物（非精确考古复原）", 14, Color("718064"), true)
	var words:=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_child(words)
	for paragraph in STORY_PARAGRAPHS:
		var paragraph_label := _label(words, paragraph, 22, Friendly.INK, true)
		paragraph_label.add_theme_constant_override("line_spacing", 5)
	_label(figure, "泉州湾宋代海船出土发现", 13, Color("7b816c"), true)
	close_button = Button.new()
	close_button.name = "CloseStory"
	close_button.text = "读完了，回到搭建  ·  Esc"
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(close)
	stack.add_child(close_button)

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
