extends VBoxContainer
const Lighting=preload("res://levels/level02/timber_lighting.gd")
## Same stock envelopes, with actual position, width/depth or layered cuts.
signal chosen(id: String)
signal inspect_requested(id: String)
signal measurement_changed
var inspect_buttons: Dictionary={}
const Preview=preload("res://components/preview/rotatable_preview.gd")
const Workspace=preload("res://components/ui/inspection_workspace.gd")
const Dimensions=preload("res://components/ui/measurements/opening_dimensions.gd")
const Marks=preload("res://components/ui/measurements/opening_measure_marks.gd")
var marks: Dictionary={}
var buttons: Dictionary={}
var previews: Dictionary={}
var captions: Dictionary={}
var caption_labels: Dictionary={}
var measurements: Dictionary={}
var _key: Array = []
var _scale_update_queued := false
func _ready() -> void:
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)

func build_cards() -> void:
	if not buttons.is_empty():
		return
	for id in ["A","B","C"]:
		var button:=Button.new();button.toggle_mode=true;button.size_flags_vertical=Control.SIZE_EXPAND_FILL;button.custom_minimum_size=Vector2(100,92);add_child(button)
		Workspace.neutral_selection(button);buttons[id]=button
		button.pressed.connect(func():chosen.emit(id))
		var row:=HBoxContainer.new();row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=10;row.offset_right=-10;row.offset_top=8;row.offset_bottom=-8;row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_theme_constant_override("separation",5);button.add_child(row)
		var preview:=Preview.new();preview.custom_minimum_size=Vector2(120,66);preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(preview);previews[id]=preview
		preview.resized.connect(_queue_scale_update)
		preview.set_lighting_profile(Lighting)
		preview.clip_contents=true
		preview.set_meta("magnifier_whole_model",true)
		preview.zoom_changed.connect(_share_zoom)
		var measure:=Marks.new();preview.add_child(measure);marks[id]=measure
		preview.activated.connect(func():
			if not button.disabled:chosen.emit(id))
		var label:=Label.new();label.custom_minimum_size.x=76;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",18);row.add_child(label);caption_labels[id]=label
		var inspect:=Button.new();inspect.text="放大";inspect.size_flags_vertical=Control.SIZE_SHRINK_CENTER;inspect.custom_minimum_size=Vector2(56,44);inspect.add_theme_font_size_override("font_size",16);row.add_child(inspect);inspect_buttons[id]=inspect
		inspect.pressed.connect(func():inspect_requested.emit(id))
func configure(view: Node3D,state) -> void:
	var geometry_id: String = view.opening_geometry_id(state.selected)
	var key := [state.selected, geometry_id, state.layout]
	if key!=_key:
		_key=key
		for id in previews:
			var model: Node3D=view.candidate_opening(state.selected,id)
			measurements[id]=Dimensions.read(model)
			captions[id]=Dimensions.caption(measurements[id])
			caption_labels[id].text=Dimensions.candidate_lines(id,measurements[id])
			buttons[id].tooltip_text=captions[id]
			var plank: bool=geometry_id.begins_with("plank")
			var center:=Vector3(0,0,.09) if plank else Vector3(0,-.015,0)
			# Like chapter one's tenon tips, frame the actual mating cut rather than
			# shrinking a tall bulkhead until its small bottom opening disappears.
			var height: float=.25 if plank else .33
			var width: float=.42 if plank else .76
			var direction:=Vector3(4,0,0)
			# Look across a three-way arm instead of straight down its length.
			if geometry_id=="three_middle":direction=Vector3(cos(-PI/3),0,sin(-PI/3))*4;height=.32;width=.9;center=Vector3(.08,.04,0)
			elif geometry_id=="three_upper":direction=Vector3(-sin(PI/3),0,-cos(PI/3))*4;height=.32;width=.9
			previews[id].show_model(model,center,direction,height,width)
			marks[id].configure(previews[id],measurements[id])
		# Different digit counts must not steal width from just one preview.
		# All three measured captions occupy the same width, as do their models.
		var caption_width:=76.0
		var row_height:=92.0
		for label in caption_labels.values():
			var font: Font=label.get_theme_font("font")
			for line in label.text.split("\n"):caption_width=maxf(caption_width,ceilf(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x))
			row_height=maxf(row_height,label.get_minimum_size().y+6)
		for label in caption_labels.values():label.custom_minimum_size.x=caption_width
		for button in buttons.values():button.custom_minimum_size.y=row_height
		_queue_scale_update()
	for id in buttons:buttons[id].set_pressed_no_signal(state.opening==id)

func _share_zoom(factor: float) -> void:
	# A wheel gesture must not change the apparent size of just one candidate.
	for preview in previews.values():
		preview.zoom_factor=factor
	_sync_camera_scale()

func _queue_scale_update() -> void:
	if _scale_update_queued:
		return
	_scale_update_queued = true
	_sync_camera_scale.call_deferred()

func _sync_camera_scale() -> void:
	_scale_update_queued = false
	var shared_height := 0.0
	for preview: JointPreview in previews.values():
		var aspect := maxf(preview.size.x, 1.0) / maxf(preview.size.y, 1.0)
		shared_height = maxf(shared_height, maxf(preview._height, preview._width / aspect) * preview.zoom_factor)
	for id in previews:
		previews[id].camera.size = shared_height
		previews[id].request_frame()
		marks[id].queue_redraw()
	measurement_changed.emit()

func reset_view() -> void:
	for preview in previews.values():preview.reset_view()
