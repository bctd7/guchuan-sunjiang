extends Button
## Shared selectable preview card, with a separate read-only magnifier action.
signal inspect_requested
const PREVIEW_AND_FOOTER_HEIGHT := 154.0
var preview_script: Script=preload("res://levels/shared/rotatable_preview.gd")
var preview: Control
var caption: Label
var inspect_button: Button
func _ready() -> void:
	toggle_mode=true
	custom_minimum_size=Vector2(100,174)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preload("res://levels/shared/inspection_workspace.gd").neutral_selection(self)
	var column=VBoxContainer.new();column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left=10;column.offset_right=-10;column.offset_top=8;column.offset_bottom=-8
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_theme_constant_override("separation",2);add_child(column)
	preview=preview_script.new();preview.custom_minimum_size=Vector2(100,92);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(preview)
	preview.viewport.transparent_bg = true
	preview.activated.connect(func():
		if not disabled:pressed.emit())
	var footer=HBoxContainer.new();footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(footer)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y=32;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(caption)
	inspect_button=Button.new();inspect_button.text="放大";inspect_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	inspect_button.custom_minimum_size=Vector2(60,60);inspect_button.add_theme_font_size_override("font_size",16);footer.add_child(inspect_button)
	inspect_button.pressed.connect(func():inspect_requested.emit())

func fit_inspect_button(display_scale: float) -> void:
	var touch_size := 60.0 / display_scale
	inspect_button.custom_minimum_size = Vector2(maxf(56.0, touch_size), touch_size)
	var available_height := PREVIEW_AND_FOOTER_HEIGHT - inspect_button.get_combined_minimum_size().y
	preview.custom_minimum_size.y = maxf(1.0, available_height)
