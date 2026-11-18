extends ColorRect
## Read-only result presentation. Validation and navigation remain in the chapter.
signal restart_requested
signal return_requested
signal next_requested
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Style=preload("res://shared/ui/workshop_ui_style.gd")
const Preview=preload("res://levels/shared/rotatable_preview.gd")
var panel: PanelContainer
var title: Label
var description: Label
var headline: Label
var chapter_label: Label
var restart_button: Button
var return_button: Button
var preview
var chapter: Node
var number:=1
var success:=false
var _acted:=false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color=Color(.10,.13,.10,.72)
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=Friendly.make_theme()
	panel=PanelContainer.new();add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=44;panel.offset_right=-44;panel.offset_top=105;panel.offset_bottom=-105
	var skin=Friendly.block(Color("fff8e8"),Color("c9ab7e"),2)
	skin.content_margin_left=30;skin.content_margin_right=30;skin.content_margin_top=24;skin.content_margin_bottom=24
	panel.add_theme_stylebox_override("panel",skin)
	var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",24);panel.add_child(stack)
	chapter_label=_label(stack,"",23);chapter_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",32);stack.add_child(row)
	preview=Preview.new();preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview.size_flags_stretch_ratio=1.35;row.add_child(preview)
	var words=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.size_flags_stretch_ratio=1.0;words.alignment=BoxContainer.ALIGNMENT_CENTER;words.add_theme_constant_override("separation",24);row.add_child(words)
	headline=_label(words,"这次搭建没有通过",33)
	title=_label(words,"",23)
	description=_label(words,"",21)
	restart_button=Button.new();restart_button.custom_minimum_size=Vector2(0,76);Style.button(restart_button,true);restart_button.add_theme_font_size_override("font_size",27);words.add_child(restart_button)
	return_button=Button.new();return_button.text="返回关卡目录";return_button.custom_minimum_size.y=70;Style.button(return_button);return_button.add_theme_font_size_override("font_size",25);words.add_child(return_button)
	var note=_label(words,"返回目录后，再次进入将重新开始。",17);note.modulate=Color("73806d")
	restart_button.pressed.connect(func():
		if _acted:return
		_acted=true
		if success:
			if number<3:next_requested.emit()
			else:return_requested.emit()
		else:restart_requested.emit()
		if is_inside_tree():_acted=false)
	return_button.pressed.connect(func():
		if _acted:return
		_acted=true;return_requested.emit()
		if is_inside_tree():_acted=false)
	visibility_changed.connect(_visibility)
	hide()
func _label(parent: Node, words: String, font_size: int) -> Label:
	var label=Label.new();label.text=words;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label
func bind(owner: Node, index: int, passed: bool) -> void:
	chapter=owner;number=index;success=passed
	chapter_label.text=["第一关 · 龙骨立架","第二关 · 船板合壳","第三关 · 帆樯舾装"][number-1]
	headline.text="✓ 本关搭建完成" if success else "! 这次搭建没有通过"
	headline.add_theme_color_override("font_color",Color("365e4d") if success else Color("a65e25"))
	restart_button.text=("下一关 →" if number<3 else "返回关卡目录") if success else "重新搭建"
	return_button.visible=not success or number<3
	title.visible=not success
	if success:description.text=["龙骨与船肋连接稳固，骨架检查通过。","船板与支撑已装齐，通过试浪检查。","帆樯与舵架就位，左右操舵检查通过。"][number-1]
func open() -> void:
	show();restart_button.grab_focus()
func _visibility() -> void:
	if not is_instance_valid(preview):return
	if is_visible_in_tree():
		_acted=false
		_snapshot.call_deferred()
	else:
		for child in preview.model_root.get_children():child.queue_free()
func _snapshot() -> void:
	if not is_visible_in_tree() or not is_instance_valid(chapter):return
	var source=chapter.view
	var bad_ids: Array=[]
	if not success:
		if number==1:
			for id in chapter.state.placed:
				var record=chapter.state.placed[id]
				if record is Dictionary and (record.get("length","correct")!="correct" or record.get("joint",chapter.Rules.expected_joint(id))!=chapter.Rules.expected_joint(id)):bad_ids.append(id)
		elif number==2:
			bad_ids.append_array(chapter.state.connection_issues())
			bad_ids.append_array(chapter.state.mismatched_joints())
			bad_ids.append_array(source.contact_failures)
	var roots: Array=[]
	if number==3:roots.assign(source.stages)
	else:
		roots.append_array(source.pieces.values())
		if number==2:roots.append_array(source.fixed.values())
	var model=Node3D.new()
	var seen={}
	for branch in roots:
		var emphasize:=false
		for id in bad_ids:
			if source.pieces.get(id)==branch:emphasize=true
		var meshes: Array=branch.find_children("*","MeshInstance3D",true,false)
		if branch is MeshInstance3D:meshes.append(branch)
		for original in meshes:
			if not original.is_visible_in_tree() or original.mesh==null or seen.has(original):continue
			seen[original]=true
			var copy=MeshInstance3D.new();copy.mesh=original.mesh;copy.material_override=original.material_override
			for surface in original.mesh.get_surface_count():copy.set_surface_override_material(surface,original.get_surface_override_material(surface))
			if emphasize:
				var accent=StandardMaterial3D.new();accent.albedo_color=Color("dba34f");accent.roughness=.85;copy.material_overlay=accent
			model.add_child(copy);copy.transform=source.global_transform.affine_inverse()*original.global_transform
	preview.configure(model,Vector3.ZERO,Vector3(4,3,5),5,8)
	preview.frame_model(model,Vector3(4,3,5))
	# This result preview is fixed, so it cannot leak gestures into gameplay.
	preview.orbit.set_process_input(false);preview.orbit.mouse_filter=Control.MOUSE_FILTER_IGNORE
