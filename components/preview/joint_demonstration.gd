extends VBoxContainer
## Optional read-only explanation of real component meshes, driven by model metadata.
## Owns only clone visibility/camera/Tween; never a chapter State or acceptance rule.
signal phase_changed(part: String)
var preview: JointPreview
var model: Node3D
var parts: Dictionary={}
var part_buttons: Dictionary={}
var motion: Tween
var all_button: Button
var flip_button: Button
var play_button: Button
var split_button: Button
var description: Label
var _row: HBoxContainer
var _split: Dictionary={}
var _info: Dictionary={}
var _selected:=""
var _flipped:=false
var _generation:=0
var _scale:=1.0
var _center:=Vector3.ZERO
var _direction:=Vector3.ONE
var _height:=2.3
var _width:=3.6
func _ready() -> void:
	add_theme_constant_override("separation",8)
	_row=HBoxContainer.new();_row.add_theme_constant_override("separation",8);add_child(_row)
	description=Label.new();description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_font_size_override("font_size",18);add_child(description)
	visibility_changed.connect(func():
		if not is_visible_in_tree():stop())
	hide()
func configure(viewer: JointPreview,root: Node3D) -> void:
	stop();preview=viewer;model=root;parts.clear();part_buttons.clear();_split.clear();_selected="";_flipped=false
	for child in _row.get_children():_row.remove_child(child);child.queue_free()
	if not root.has_meta("joint_demo"):
		for child in root.find_children("*","Node3D",true,false):
			if child.has_meta("joint_demo"):root=child;break
	model=root
	_info=root.get_meta("joint_demo",{})
	if _info.is_empty():hide();return
	_center=preview.orbit._center;_direction=preview.orbit._direction;_height=preview._height;_width=preview._width
	all_button=_button("整体",show_all)
	for item in _info.parts:
		var key: String=item.path
		parts[key]=root.get_node(key);_split[key]=parts[key].transform
		part_buttons[key]=_button(item.caption,func():show_part(key))
	flip_button=_button("翻面",func():_flipped=not _flipped;_frame_part())
	play_button=_button("逐步合拢",play)
	split_button=_button("拆开观察",show_all)
	show();show_all();set_display_scale(_scale)
func _button(text: String,action: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(140,52);button.pressed.connect(action);_row.add_child(button);return button
func stop() -> void:
	_generation+=1
	if is_instance_valid(motion):motion.kill()
	motion=null
	if is_instance_valid(preview):
		preview.set_animating(false)

func release_model() -> void:
	stop()
	preview = null
	model = null
	parts.clear()
	_split.clear()
	hide()
func show_all() -> void:
	stop();_selected="";_flipped=false
	for key in parts:parts[key].visible=true;parts[key].transform=_split[key]
	preview.frame(_center,_direction,_height,_width)
	flip_button.disabled=true;play_button.text="逐步合拢";description.text=_info.description
func show_part(key: String) -> void:
	stop();_selected=key;_flipped=false
	for path in parts:parts[path].visible=path==key;parts[path].transform=_split[path]
	flip_button.disabled=false
	description.text=_info.description+"  ·  "+part_buttons[key].text
	_frame_part()
func _frame_part() -> void:
	if _selected.is_empty():return
	var item: Dictionary={}
	for entry in _info.parts:
		if entry.path==_selected:item=entry;break
	var axis: Vector3=item.axis
	var normal: Vector3=item.normal*(-1.0 if _flipped else 1.0)
	var direction:=axis.cross(Vector3.UP)*3.0+normal*3.6+axis*.7
	preview.frame_model(parts[_selected],direction)
func play() -> void:
	show_all();var generation:=_generation
	preview.set_animating(true)
	motion=create_tween()
	for key in _info.order:
		motion.tween_callback(func():
			if generation==_generation:phase_changed.emit(key);description.text="正在合拢 · "+part_buttons[key].text)
		var destination: Vector3=_split[key].origin;destination.y=0.0
		destination=_info.get("closed_positions",{}).get(key,destination)
		motion.tween_property(parts[key],"position",destination,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_callback(func():
		if generation==_generation:
			description.text=_info.closed_text
			play_button.text="重新演示"
			preview.set_animating(false))
func set_display_scale(factor: float) -> void:
	_scale=factor
	if not is_instance_valid(_row):return
	for button in _row.get_children():button.custom_minimum_size.y=maxf(52,60/factor)
