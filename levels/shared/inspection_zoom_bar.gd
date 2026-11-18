extends HBoxContainer
## Camera controls only. Chapters decide when zoom/reset is allowed.
signal zoom_requested(factor: float)
signal reset_requested
var zoom_in: Button
var zoom_out: Button
var reset_button: Button
var percentage: Label
func _ready() -> void:
	add_theme_constant_override("separation",6)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal=Control.GROW_DIRECTION_BEGIN
	offset_left=-8;offset_right=-8;offset_top=8;offset_bottom=8
	zoom_out=_button("−",52);zoom_out.tooltip_text="缩小观察"
	zoom_out.pressed.connect(func():zoom_requested.emit(1.2))
	percentage=Label.new();percentage.text="100%";percentage.add_theme_font_size_override("font_size",17)
	percentage.custom_minimum_size.x=58;percentage.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;add_child(percentage)
	zoom_in=_button("＋",52);zoom_in.tooltip_text="放大观察"
	zoom_in.pressed.connect(func():zoom_requested.emit(1.0/1.2))
	reset_button=_button("重置视角",160);reset_button.pressed.connect(func():reset_requested.emit())
func _button(text: String,width: float) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(width,48);add_child(button);return button
func update_zoom(factor: float) -> void:percentage.text="%d%%"%roundi(100.0/factor)
func set_display_scale(factor: float) -> void:
	reset_button.custom_minimum_size=Vector2(maxf(160,160/factor),maxf(64,64/factor))
	for button in [zoom_in,zoom_out]:button.custom_minimum_size.y=maxf(48,60/factor)
	for button in [zoom_in,zoom_out]:button.custom_minimum_size.x=maxf(52,60/factor)

func separate_reset(parent: Control) -> void:
	reset_button.reparent(parent)
	reset_button.custom_minimum_size=Vector2(160,64)
	reset_button.mouse_filter=Control.MOUSE_FILTER_STOP
