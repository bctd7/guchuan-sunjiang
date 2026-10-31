extends HBoxContainer
## Three actual connected wooden ends, visible before choosing.
signal chosen(type: String)
const Preview = preload("res://levels/level01/candidate_preview.gd")
const TYPES := {"blind_tenon":"半榫", "dovetail":"燕尾榫", "through_tenon":"透榫"}
var buttons: Dictionary = {}
var viewports: Dictionary = {}
var previews: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation",8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()

func _build() -> void:
	if not buttons.is_empty(): return
	custom_minimum_size.y = 174
	for kind in TYPES:
		var button:=Button.new()
		button.name="Choose_"+kind
		button.toggle_mode=true
		button.custom_minimum_size=Vector2(100,174)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): chosen.emit(kind))
		button.tooltip_text="选择"+TYPES[kind]
		add_child(button)
		buttons[kind]=button
		var column:=VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left=3
		column.offset_right=-3
		column.offset_top=3
		column.offset_bottom=-3
		column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation",2)
		button.add_child(column)
		var preview:=Preview.new()
		preview.custom_minimum_size=Vector2(100,132)
		preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
		column.add_child(preview)
		previews[kind]=preview
		viewports[kind]=preview.viewport
		var caption:=Label.new()
		caption.text="选"+TYPES[kind]
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.y=32
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)

func configure(source_view: Node3D, piece_id: String, length: String = "correct") -> void:
	_build()
	if not is_instance_valid(source_view) or not source_view.pieces.has(piece_id): return
	for kind in TYPES:
		previews[kind].configure(source_view,piece_id,kind,length)

func select_type(kind: String) -> void:
	for id in buttons: buttons[id].set_pressed_no_signal(id == kind)

func set_selected(kind: String) -> void:
	select_type(kind)
