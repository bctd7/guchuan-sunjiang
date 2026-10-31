extends PanelContainer
## UI-only shell: no assembly, drag, camera or educational animation ownership.
signal joint_selected(index: int)
signal science_requested
signal view_requested
signal reset_requested
signal xray_requested(enabled: bool)
const TimberStyle = preload("res://classroom/ui/ladder_timber_style.gd")
const FriendlyTheme = preload("res://shared/ui/friendly_theme.gd")
const WoodButton = preload("res://classroom/ui/wood_block_button.gd")
const WoodLadder = preload("res://classroom/ui/wood_ladder.gd")
var block_count := 0
var picker: OptionButton
var science_entry: Button
var status: Label
var scroll: ScrollContainer
var content: VBoxContainer
var buttons: Dictionary = {}

func _ready() -> void:
	name = "WorkshopPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	theme = FriendlyTheme.make_theme()
	TimberStyle.apply(theme)
	var card := StyleBoxEmpty.new()
	card.content_margin_left = 20
	card.content_margin_right = 20
	card.content_margin_top = 20
	card.content_margin_bottom = 20
	add_theme_stylebox_override("panel",card)
	scroll = ScrollContainer.new()
	scroll.mouse_force_pass_scroll_events = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	content = WoodLadder.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	content.add_child(header)
	var logo := TextureRect.new()
	logo.texture = FriendlyTheme.icon("blocks")
	logo.custom_minimum_size = Vector2(32,32)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(logo)
	var brand := Label.new()
	brand.text = "古船榫匠"
	brand.add_theme_font_size_override("font_size",27)
	header.add_child(brand)
	picker = OptionButton.new()
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.y = 64
	picker.icon = FriendlyTheme.icon("blocks")
	picker.item_selected.connect(func(index: int): joint_selected.emit(index))
	content.add_child(picker)
	science_entry = _button(content,"science","受力演示",func(): science_requested.emit())
	var xray := _button(content,"xray","透明显示",func(): pass)
	xray.toggle_mode = true
	xray.toggled.connect(func(value: bool): xray_requested.emit(value))
	_button(content,"view","视角复位",func(): view_requested.emit())
	_button(content,"reset","重新拼装",func(): reset_requested.emit())
	content.connect_steps(picker,buttons.reset)
	status = Label.new()
	status.text = "待拼装"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status)
	get_viewport().size_changed.connect(_layout_panel)
	content.minimum_size_changed.connect(func(): _layout_panel.call_deferred())
	_layout_panel.call_deferred()

func configure(catalog: Array) -> void:
	picker.clear()
	for joint in catalog: picker.add_item(str(joint.name))

func _button(parent: Node, id: String, label: String, action: Callable) -> Button:
	var row := MarginContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	block_count += 1
	var button := WoodButton.new()
	button.text = label
	button.icon = FriendlyTheme.icon(id)
	button.custom_minimum_size.y = 72
	button.pressed.connect(action)
	row.add_child(button)
	buttons[id] = button
	return button

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and is_instance_valid(scroll):
		# Original ladder placement, independent of face textures and shadows.
		var second_shift := 6.0 if get_viewport().get_visible_rect().size.x < 800 else 14.0
		scroll.position.x += second_shift

func _layout_panel() -> void:
	if not is_instance_valid(content): return
	var viewport_size := get_viewport().get_visible_rect().size
	var small := viewport_size.x < 800
	var width := clampf(viewport_size.x*.34,248,340)
	var padding := 16.0 if small else 28.0
	# Preserve the original silhouette and model safe area.
	var horizontal_shift := 8.0 if small else 20.0
	var card := get_theme_stylebox("panel")
	card.content_margin_left = padding + horizontal_shift
	card.content_margin_right = padding - horizontal_shift
	card.content_margin_top = padding
	card.content_margin_bottom = padding
	content.add_theme_constant_override("separation",14 if small else clampi(roundi(viewport_size.y*.035),20,36))
	theme.default_font_size = 16 if small else 20
	picker.custom_minimum_size.y = 64 if small else 80
	for button in buttons.values():
		button.custom_minimum_size.y = 64 if small else 80
		button.add_theme_constant_override("icon_max_width",22 if small else 28)
		button.add_theme_constant_override("h_separation",8 if small else 12)
	# Restore the five original expanding steps without changing their hit areas.
	content.custom_minimum_size.x = width-padding*2-14
	position = Vector2.ZERO
	size = Vector2(width,maxf(80,viewport_size.y))
