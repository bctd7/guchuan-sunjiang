extends HBoxContainer
## Three actual connected wooden ends, visible before choosing.
signal chosen(type: String)
signal inspect_requested(id: String)
var inspect_buttons: Dictionary={}
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
		var button=preload("res://components/ui/selection_card.gd").new()
		button.preview_script=Preview;button.name="Choose_"+kind
		add_child(button);buttons[kind]=button
		button.pressed.connect(func():chosen.emit(kind))
		button.tooltip_text="选择"+TYPES[kind]
		previews[kind]=button.preview;viewports[kind]=button.preview.viewport
		button.caption.text="选"+TYPES[kind]
		inspect_buttons[kind]=button.inspect_button
		button.inspect_requested.connect(func():inspect_requested.emit(kind))

func configure(source_view: Node3D, piece_id: String, length: String = "correct") -> void:
	_build()
	if not is_instance_valid(source_view) or not source_view.pieces.has(piece_id): return
	for kind in TYPES:
		previews[kind].configure(source_view,piece_id,kind,length)

func select_type(kind: String) -> void:
	for id in buttons: buttons[id].set_pressed_no_signal(id == kind)

func set_selected(kind: String) -> void:
	select_type(kind)
