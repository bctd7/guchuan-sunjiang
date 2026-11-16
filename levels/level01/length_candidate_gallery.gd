extends VBoxContainer
## Whole-row buttons with actual connected timber previews; no default choice.
signal chosen(id: String)
signal inspect_requested(id: String)
var inspect_buttons: Dictionary={}
const Preview = preload("res://levels/level01/candidate_preview.gd")
const Lengths = preload("res://models/ship/keel/length_geometry.gd")
const ORDER := ["long","short","correct"]
var buttons: Dictionary = {}
var viewports: Dictionary = {}
var previews: Dictionary = {}
var captions: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation",4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()

func _build() -> void:
	if not buttons.is_empty(): return
	for index in ORDER.size():
		var length: String = ORDER[index]
		var button := Button.new()
		button.name = "Length"+str(index)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(100,72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): chosen.emit(length))
		add_child(button)
		buttons[length] = button
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_right = -7
		row.offset_top = 3
		row.offset_bottom = -3
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation",5)
		button.add_child(row)
		var preview := Preview.new()
		preview.custom_minimum_size = Vector2(120,66)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(preview)
		previews[length] = preview
		preview.activated.connect(func():
			if not button.disabled:chosen.emit(length))
		viewports[length] = preview.viewport
		var caption := Label.new()
		caption.custom_minimum_size.x = 76
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size",15)
		row.add_child(caption)
		captions[length] = caption
		var inspect:=Button.new();inspect.text="放大";inspect.custom_minimum_size=Vector2(56,44);inspect.add_theme_font_size_override("font_size",16);row.add_child(inspect);inspect_buttons[length]=inspect
		inspect.pressed.connect(func():inspect_requested.emit(length))

func configure(source: Node3D, piece_id: String, kind: String = "") -> void:
	_build()
	for index in ORDER.size():
		var length: String = ORDER[index]
		previews[length].configure(source,piece_id,kind,length,true)
		var specimen: Node3D = previews[length].specimen
		if not is_instance_valid(specimen): continue
		var tip: MeshInstance3D
		var axis := "x"
		var measure := "榫端长"
		if piece_id.begins_with("rib_"):
			tip = specimen.find_child("RootTenon",true,false) as MeshInstance3D
		elif piece_id in ["bow","stern"]:
			tip = specimen.get_child(0).get_child(0) as MeshInstance3D
			axis = "z"
		else:
			tip = specimen.find_child("CandidateTenon",true,false) as MeshInstance3D
			if tip == null:
				tip = specimen.get_child(0) as MeshInstance3D
				measure = "整梁长"
		if tip == null: continue
		var ticks := roundi(float(tip.mesh.get_aabb().size[axis])*100.0)
		var detail := measure
		if piece_id.begins_with("beam") and measure == "榫端长":
			var body := specimen.get_child(0) as MeshInstance3D
			var stock_ticks := roundi((body.mesh.get_aabb().size.x+tip.mesh.get_aabb().size.x)*100.0)
			detail = "整料 %d格" % stock_ticks
		captions[length].text = "%s · %s%d格\n%s" % [char(65+index),measure.trim_suffix("长"),ticks,detail]
		buttons[length].tooltip_text = "木料 %s · %s%d格；点选后试装" % [char(65+index),measure,ticks]

func set_selected(length: String) -> void:
	for id in buttons: buttons[id].set_pressed_no_signal(id == length)
