extends Control
## Read-only clone viewer. No choice, assembly state or installation signal lives here.
signal closed
const Demonstration=preload("res://levels/shared/joint_demonstration.gd")
const Preview=preload("res://levels/shared/rotatable_preview.gd")
const Friendly=preload("res://shared/ui/friendly_theme.gd")
var demonstration: Control
var preview: Control
var title: Label
var close_button: Button
var zoom_in: Button
var zoom_out: Button
var reset_button: Button
var zoom_label: Label
var _previous_focus: Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP;theme=Friendly.make_theme(true)
	var shade:=ColorRect.new();shade.color=Color(.12,.14,.10,.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel:=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=36;panel.offset_right=-36;panel.offset_top=36;panel.offset_bottom=-36
	panel.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("c8b895"),2))
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",10);panel.add_child(stack)
	var header:=HBoxContainer.new();stack.add_child(header)
	title=Label.new();title.add_theme_font_size_override("font_size",27);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	close_button=_button(header,"返回选材");close_button.pressed.connect(close)
	preview=Preview.new();preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;stack.add_child(preview)
	var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER;actions.add_theme_constant_override("separation",12);stack.add_child(actions)
	zoom_out=_button(actions,"− 缩小");zoom_out.pressed.connect(func():preview.zoom(1.2))
	zoom_label=Label.new();zoom_label.custom_minimum_size.x=85;zoom_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;actions.add_child(zoom_label)
	zoom_in=_button(actions,"＋ 放大");zoom_in.pressed.connect(func():preview.zoom(1.0/1.2))
	reset_button=_button(actions,"重置视角");reset_button.pressed.connect(preview.reset_view)
	preview.zoom_changed.connect(func(value: float):zoom_label.text="%d%%"%roundi(100.0/value))
	demonstration=Demonstration.new();stack.add_child(demonstration);stack.move_child(demonstration,1)
	var note:=Label.new();note.text="拖动旋转 · 双指、滚轮或按钮缩放";note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(note)
	hide()
func _button(parent: Node,text: String) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(140,52);parent.add_child(button);return button
func open(source: Control,caption: String) -> void:
	_previous_focus=get_viewport().gui_get_focus_owner()
	preview.set_lighting_profile(source.get("lighting_profile") as Script)
	var model:=source.model_root.duplicate() as Node3D
	preview.configure(model,source.orbit._center,source.orbit._direction,source._height,source._width)
	preview.orbit.angles=source.orbit.angles;preview.orbit.target_angles=source.orbit.angles;preview.orbit._apply_camera()
	if source.get_meta("magnifier_whole_model",false):
		# Face-on comparison cards crop around the cut; the viewer opens the
		# complete stock. Preserve an inspected angle, otherwise expose its depth.
		var direction: Vector3=preview.camera.position-preview.orbit._center
		if source.orbit.angles.is_zero_approx():direction+=Vector3.UP*2.0+source.camera.basis.x*1.5
		preview.frame_model(model,direction)
	title.text=caption;zoom_label.text="100%";show();demonstration.configure(preview,model);close_button.grab_focus()
func close() -> void:
	if not visible:return
	demonstration.stop();hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():_previous_focus.grab_focus()
	closed.emit()
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:close();get_viewport().set_input_as_handled()
func set_display_scale(factor: float) -> void:
	demonstration.set_display_scale(factor)
	for button in [close_button,zoom_in,zoom_out,reset_button]:button.custom_minimum_size.y=maxf(52,44/factor)
