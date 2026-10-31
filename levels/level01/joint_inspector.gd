extends CanvasLayer
## Close-up clones of THIS level's real ship parts; no standalone joint substitutes.
## It observes the level, and never changes its accepted connections.
signal closed
signal joint_chosen(id: String)
signal length_chosen(id: String)
signal lesson_requested
signal install_requested
signal retry_requested
var lesson_button: Button
var install_button: Button
var retry_button: Button
var _review_only:=false
var length_gallery: Control
var stage_surface: Control
const LengthComparison=preload("res://levels/level01/length_measure_panel.gd")
const Trial=preload("res://levels/level01/trial_fit.gd")
const TrialReceiver=preload("res://levels/level01/trial_receiver.gd")
const ReceiverSection=preload("res://levels/level01/receiver_section.gd")
const Lengths=preload("res://levels/level01/length_geometry.gd")
const Look = preload("res://demo/workshop_look.gd")
const Friendly = preload("res://demo/friendly_theme.gd")
const CandidateGeometry = preload("res://levels/level01/candidate_geometry.gd")
const TypeGallery = preload("res://levels/level01/type_gallery.gd")
const CandidatePreview = preload("res://levels/level01/candidate_preview.gd")
const InspectionOrbit = preload("res://levels/level01/assembly_drag_surface.gd")
const LengthGallery = preload("res://levels/level01/length_candidate_gallery.gd")
const COPY := {
	"blind_tenon": ["半榫 · 榫头藏进盲槽", "从侧面对准槽口，沿直线送入。盲槽有底，不能穿透；左右盲槽之间保留实木。"],
	"dovetail": ["燕尾榫 · 沿开放端滑入", "看清宽头窄颈的燕尾形。由槽的开放端滑入，不是从上方压下去。"],
	"through_tenon": ["透榫 · 横撑穿过两侧船肋", "看这根横撑沿通孔穿过船肋。它的截面保持一致，两端都能穿过封闭孔。"]
}
var close_button: Button
var viewport: SubViewport
var source_view: Node3D
var pieces: Dictionary = {}
var animated_piece: Node3D
var animated_piece_id := ""
var opened := false
var animation_finished := false
var root: Control
var camera: Camera3D
var orbit: Control
var world: Node3D
var _motion: Tween
var title: Label
var explanation: Label
var status: Label
var xray_button: Button
var replay_button: Button
var length_buttons: Dictionary = {}
var joint_buttons: Dictionary = {}
var comparison: Control
var candidate_panel: VBoxContainer
var observation_mode := false
var selected_length := ""
var selected_joint := ""
var joint_choices: HBoxContainer
var _length := "correct"
var _animating := false
var _keep_drag_framing:=false
var _framing_settled:=false
var is_animating: bool:
	get: return _animating

func _ready() -> void:
	layer = 20
	_build()
	hide()

func configure(skeleton: Node3D) -> void:
	source_view=skeleton

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Friendly.make_theme(true)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color("e9dcc2")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=24
	panel.offset_right=-24
	panel.offset_top=24
	panel.offset_bottom=-24
	panel.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("c8b895"),2))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	panel.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	title = _label(head,"看清榫头与槽口",27)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	lesson_button=_button(head,"本关榫卯讲解")
	lesson_button.pressed.connect(func(): lesson_requested.emit())
	retry_button=_button(head,"取回调整")
	retry_button.pressed.connect(func(): retry_requested.emit())
	close_button = _button(head,"返回骨架")
	close_button.pressed.connect(close)
	explanation = _label(stack,"",20)
	explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	joint_choices=TypeGallery.new()
	stack.add_child(joint_choices)
	joint_buttons=joint_choices.buttons
	for candidate in joint_buttons.values():
		candidate.custom_minimum_size.y=40
		_style_neutral_selection(candidate)
	joint_choices.chosen.connect(_choose_joint)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation",16)
	stack.add_child(middle)
	stage_surface=Control.new()
	stage_surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stage_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage_surface.custom_minimum_size=Vector2(0,330)
	middle.add_child(stage_surface)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage_surface.add_child(container)
	candidate_panel=VBoxContainer.new()
	candidate_panel.custom_minimum_size.x=345
	candidate_panel.add_theme_constant_override("separation",6)
	middle.add_child(candidate_panel)
	comparison=LengthComparison.new()
	candidate_panel.add_child(comparison)
	length_gallery=LengthGallery.new()
	candidate_panel.add_child(length_gallery)
	length_buttons=length_gallery.buttons
	length_gallery.chosen.connect(_choose_length)
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.size=Vector2i(1000,490)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	Look.install(world)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.05
	camera.current=true
	world.add_child(camera)
	# The surface belongs only to the main close-up; cards and rulers stay GUI.
	orbit=InspectionOrbit.new()
	orbit.name="InspectionOrbit"
	stage_surface.add_child(orbit)
	orbit.assembly_requested.connect(func(): install_requested.emit())
	orbit.insertion_progress_changed.connect(_sync_trial_receiver)
	orbit.selection_required.connect(_show_choice_hint)
	orbit.drag_feedback.connect(func(message: String):
		if observation_mode:status.text=message)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	stack.add_child(actions)
	status=_label(actions,"",19)
	status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	install_button=_button(actions,"准备试装")
	install_button.pressed.connect(_prepare_install)
	xray_button=_button(actions,"看孔内")
	xray_button.toggle_mode=true
	xray_button.toggled.connect(_set_cutaway)
	replay_button=_button(actions,"再看插入")
	replay_button.pressed.connect(func(): show_connection(animated_piece_id,_length,not observation_mode,selected_joint,_review_only))
	var note := _label(stack,"转一转，看清榫头和槽口。",15)
	note.modulate=Color("73806d")

func show_connection(piece_id: String, length: String = "", animate: bool = false, joint_type: String = "", review_installed: bool = false, released_pose: Variant = null) -> void:
	if not is_instance_valid(source_view) or not source_view.pieces.has(piece_id) or piece_id == "keel": return
	length=length if length in ["short","correct","long"] else ""
	var preserve_angle := opened and animated_piece_id == piece_id
	_keep_drag_framing=preserve_angle and released_pose is Transform3D and not piece_id.begins_with("rib_")
	_framing_settled=false
	if is_instance_valid(_motion): _motion.kill()
	for part in pieces.values():
		world.remove_child(part)
		part.queue_free()
	pieces.clear()
	animated_piece_id=piece_id
	_length=length
	selected_length=length
	selected_joint=joint_type
	observation_mode=not animate and not review_installed
	_review_only=review_installed
	_animating=false
	animation_finished=review_installed and not animate
	var joint_id := "blind_tenon" if piece_id.begins_with("rib_") else ("through_tenon" if piece_id.begins_with("beam") else "dovetail")
	var ids: Array[String]=["keel",piece_id]
	if piece_id.begins_with("beam"):
		ids=["rib_l"+piece_id.right(1),"rib_r"+piece_id.right(1),piece_id]
	for id in ids:
		var copy: Node3D=source_view.duplicate_part(id) if id==piece_id else source_view.pieces[id].duplicate()
		copy.name="Closeup_"+id
		copy.transform=Transform3D.IDENTITY if id==piece_id else source_view.pieces[id].transform
		copy.visible=true
		_clone_materials(copy)
		if id==piece_id:
			source_view.apply_fit_geometry(copy,id,joint_type,length if not length.is_empty() else "correct")
			if not observation_mode:copy.transform=source_view.trial_pose(id,length,joint_type)
		world.add_child(copy)
		pieces[id]=copy
	animated_piece=pieces[piece_id]
	Lengths.set_fasteners_visible(animated_piece,false)
	# Normalize display-only surface direction and opacity; source resources stay intact.
	for part in pieces.values(): CandidatePreview.solidify(part)
	title.text=COPY[joint_id][0]
	explanation.text=COPY[joint_id][1]
	if not observation_mode:
		title.text="试装 · "+str(TypeGallery.TYPES.get(joint_type,"木料"))
		explanation.text="看看接合处，再决定继续搭建还是取回调整。"
	if observation_mode:
		title.text="观察船肋与龙骨" if piece_id.begins_with("rib_") else ("观察横撑与船肋" if piece_id.begins_with("beam") else "观察龙骨端接")
		if piece_id.begins_with("rib_"):
			explanation.text="转一转，看看槽口，再挑一个能接上的榫头。"
		elif piece_id.begins_with("beam"):
			explanation.text="横梁要穿过两侧船肋。转一转，看看另一侧的出口。"
		else:
			explanation.text="看看燕尾形状，找准滑槽的开口。"
	xray_button.set_pressed_no_signal(false)
	_set_cutaway(false)
	status.text="先看榫头、孔口与进入方向。"
	candidate_panel.visible=observation_mode
	comparison.configure(piece_id,selected_length)
	length_gallery.visible=observation_mode
	if observation_mode:
		length_gallery.configure(source_view,piece_id,joint_type)
		length_gallery.set_selected(selected_length)
		length_buttons=length_gallery.buttons
	lesson_button.visible=observation_mode
	joint_choices.visible=observation_mode
	if observation_mode:
		joint_choices.configure(source_view,piece_id,length)
		joint_choices.set_selected(joint_type)
	for id in joint_buttons:
		joint_buttons[id].set_pressed_no_signal(id == joint_type)
	replay_button.text="重新观察" if observation_mode else "再看插入"
	replay_button.disabled=false
	status.modulate=Color("325c4d")
	if observation_mode: _show_choice_hint()

	if not _keep_drag_framing:_focus_connection(piece_id,not preserve_angle)
	close_button.text="返回骨架"
	opened=true
	show()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	retry_button.visible=not observation_mode
	retry_button.disabled=animate
	if observation_mode:
		var preview_offset: Vector3=source_view.insertion_offset(piece_id)
		if piece_id.begins_with("rib_"):
			var tip: MeshInstance3D=animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
			preview_offset=preview_offset.normalized()*maxf(1.50,tip.mesh.get_aabb().size.x+.25)
		elif piece_id in ["bow","stern"]:preview_offset=preview_offset.normalized()*1.1
		if not joint_type.is_empty() and joint_type!=joint_id_for(piece_id):
			animated_piece.transform=source_view.trial_pose(piece_id,length,joint_type)
			preview_offset=preview_offset.normalized()*(1.5 if piece_id.begins_with("rib_") else (1.1 if piece_id in ["bow","stern"] else 2.0))
		animated_piece.position+=preview_offset
		# Start every actual tip visibly outside its entry mouth, including a
		# longer wrong tip. Pointer travel ends at this mouth; animation finishes
		# the rest of the slide through the frame.
		var outward: Vector3=source_view.insertion_offset(piece_id).normalized()
		var gap: float=(_tip_front()-_entry_mouth()).dot(outward)
		animated_piece.position+=outward*maxf(0.0,.75-gap)
	if not joint_type.is_empty() and joint_type!=joint_id_for(piece_id) and not _keep_drag_framing:_frame_trial_candidate()
	_configure_drag()
	if not observation_mode:_sync_trial_receiver(1.0)
	install_button.visible=observation_mode
	install_button.disabled=false
	install_button.text="先选榫头" if selected_joint.is_empty() else ("先选木料" if selected_length.is_empty() else "准备试装")
	if animate:
		var final: Transform3D=source_view.trial_pose(piece_id,length,joint_type)
		animated_piece.transform=_safe_trial_entry(final)
		if released_pose is Transform3D:
			animated_piece.transform=released_pose
			animated_piece.set_meta("trial_release_start",released_pose)
		if joint_type!=joint_id_for(piece_id) and not _keep_drag_framing:_frame_trial_candidate()
		_animating=true
		status.text="沿着槽口试着装入……"
		_motion=create_tween()
		var slide_time:=1.8
		if released_pose is Transform3D:slide_time=clampf(released_pose.origin.distance_to(final.origin)*.24,.12,.55)
		_motion.tween_interval(.04 if released_pose is Transform3D else .3)
		_motion.tween_property(animated_piece,"transform",final,slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if not Trial.is_stable(piece_id,length,joint_type):
			var outward: Vector3=source_view.insertion_offset(piece_id).normalized()*.055
			for pulse in 3:
				_motion.tween_property(animated_piece,"position",final.origin+outward,.10)
				_motion.tween_property(animated_piece,"position",final.origin,.10)
		_motion.tween_callback(_finish_trial_review)
	elif not observation_mode:_finish_trial_review()

func _finish_trial_review() -> void:
	if _keep_drag_framing and not _framing_settled:
		_framing_settled=true
		var previous_center: Vector3=orbit._center
		var previous_size: float=camera.size
		var previous_direction: Vector3=orbit._direction
		_focus_connection(animated_piece_id,false)
		if selected_joint!=joint_id_for(animated_piece_id):_frame_trial_candidate()
		var final_center: Vector3=orbit._center
		var final_size: float=camera.size
		orbit.configure(camera,previous_center,previous_direction,false)
		camera.size=previous_size
		_motion=create_tween().set_parallel(true)
		_motion.tween_property(orbit,"_center",final_center,.38).set_trans(Tween.TRANS_SINE)
		_motion.tween_property(camera,"size",final_size,.38).set_trans(Tween.TRANS_SINE)
		_motion.chain().tween_callback(_finish_trial_review)
		return
	_animating=false
	animation_finished=true
	retry_button.disabled=false
	# The approach can start well outside the receiver. Recenter on contact so
	# the final joint is not left at the edge of its approach framing.
	if selected_joint!=joint_id_for(animated_piece_id) and not _keep_drag_framing:_frame_trial_candidate()
	Lengths.set_fasteners_visible(animated_piece,selected_joint==joint_id_for(animated_piece_id))
	if Trial.is_stable(animated_piece_id,_length,selected_joint):
		title.text="这一处接好了！"
		status.text="接上了！继续搭建，最后再检查整段骨架。"
	else:
		title.text="接合处有点松"
		status.text="木料在晃动。可以取回换件，再试一次。"
	close_button.text="返回船架" if _review_only else "继续搭建"

func _collect_trial_corners(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh and node.visible:
		var bounds: AABB=node.mesh.get_aabb()
		for index in 8:points.append(node.to_global(bounds.get_endpoint(index)))
	for child in node.get_children():_collect_trial_corners(child,points)

func _frame_trial_candidate() -> void:
	# Keep the entire tested wood and receiving mouth visible; no geometry scaling.
	var points: Array[Vector3]=[]
	_collect_trial_corners(animated_piece,points)
	var mouth: Vector3=source_view.connection_center(animated_piece_id)
	for offset in [Vector3(-.4,-.4,0),Vector3(.4,.4,0)]:points.append(mouth+offset)
	var center: Vector3=orbit._center
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for point in points:
		var relative: Vector3=point-center
		var projected:=Vector2(relative.dot(camera.basis.x),relative.dot(camera.basis.y))
		low=low.min(projected)
		high=high.max(projected)
	var mid: Vector2=(low+high)*.5
	var span: Vector2=high-low
	var aspect: float=maxf(stage_surface.size.x/maxf(stage_surface.size.y,1),1.2)
	camera.size=maxf(camera.size,maxf(span.y,span.x/aspect)*1.22)
	orbit.configure(camera,center+camera.basis.x*mid.x+camera.basis.y*mid.y,orbit._direction,false)



func _sync_trial_receiver(progress: float) -> void:
	if not is_instance_valid(animated_piece) or selected_joint.is_empty() or selected_joint==joint_id_for(animated_piece_id):return
	var changed:=false
	if progress<=.001:
		if not observation_mode or not animated_piece.has_meta("trial_receiver_reliefs"):return
		for id in pieces:
			if id!=animated_piece_id:
				ReceiverSection.restore(pieces[id])
				TrialReceiver.restore(pieces[id])
		animated_piece.remove_meta("trial_receiver_reliefs")
		changed=true
	elif not animated_piece.has_meta("trial_receiver_reliefs"):
		var relieved:=0
		var final: Transform3D=source_view.trial_pose(animated_piece_id,_length,selected_joint)
		var entry: Transform3D=orbit._rest_pose if observation_mode else _safe_trial_entry(final)
		for id in pieces:
			if id!=animated_piece_id:
				ReceiverSection.restore(pieces[id])
				relieved+=TrialReceiver.apply(pieces[id],animated_piece,final,_receiver_tip(),entry)
		animated_piece.set_meta("trial_receiver_reliefs",relieved)
		changed=true
	if changed:_set_cutaway(xray_button.button_pressed)

func _safe_trial_entry(final: Transform3D) -> Transform3D:
	var previous: Transform3D=animated_piece.transform
	animated_piece.transform=final
	animated_piece.position+=source_view.trial_entry_offset(animated_piece_id,_length,selected_joint)
	if animated_piece_id in ["bow","stern"] or animated_piece_id.begins_with("beam"):
		var outward: Vector3=source_view.insertion_offset(animated_piece_id).normalized()
		var gap: float=(_tip_front()-_entry_mouth()).dot(outward)
		animated_piece.position+=outward*maxf(0.0,.75-gap)
	var result: Transform3D=animated_piece.transform
	animated_piece.transform=previous
	return result

func _receiver_tip() -> MeshInstance3D:
	if animated_piece.has_meta("candidate_tip_path"):return animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	if animated_piece_id.begins_with("rib_"):return animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	return animated_piece.get_child(0).get_child(0) as MeshInstance3D if animated_piece_id in ["bow","stern"] else animated_piece.get_child(0) as MeshInstance3D

func _grab_point() -> Vector3:
	var tip: MeshInstance3D
	if animated_piece.has_meta("candidate_tip_path"):
		tip=animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	elif animated_piece_id.begins_with("rib_"):
		tip=animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	elif animated_piece_id in ["bow","stern"]:
		tip=animated_piece.get_child(0).get_child(0) as MeshInstance3D
	else:
		tip=animated_piece.get_child(0) as MeshInstance3D
	if tip==null: return Vector3.ZERO
	var point: Vector3=tip.mesh.get_aabb().get_center()
	if animated_piece_id.begins_with("beam") and not animated_piece.has_meta("candidate_tip_path"):
		point.x=-Lengths.span(animated_piece_id,_length)*.5+.2
	return animated_piece.to_local(tip.to_global(point))

func _configure_drag() -> void:
	var enabled: bool=observation_mode and not selected_joint.is_empty() and not selected_length.is_empty()
	var seated: Transform3D=source_view.trial_pose(animated_piece_id,_length,selected_joint)
	var contact_local: Vector3=animated_piece.to_local(world.to_global(_tip_front()))
	orbit.configure_assembly(animated_piece,seated,_grab_point(),enabled,world.to_global(_entry_mouth()),contact_local)
	orbit.preview_limit=1.0

func _tip_front() -> Vector3:
	var tip: MeshInstance3D
	if animated_piece.has_meta("candidate_tip_path"):
		tip=animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	elif animated_piece_id.begins_with("rib_"):
		tip=animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	else:
		tip=animated_piece.get_child(0).get_child(0) as MeshInstance3D if animated_piece_id in ["bow","stern"] else animated_piece.get_child(0) as MeshInstance3D
	var outward: Vector3=source_view.insertion_offset(animated_piece_id).normalized()
	var nearest:=INF
	var total:=Vector3.ZERO
	var count:=0
	for vertex in tip.mesh.get_faces():
		var point: Vector3=world.to_local(tip.to_global(vertex))
		var distance: float=point.dot(outward)
		if distance<nearest-.0001:
			nearest=distance
			total=point
			count=1
		elif absf(distance-nearest)<.0001:
			total+=point
			count+=1
	return total/maxi(count,1)

func _entry_mouth() -> Vector3:
	var mouth: Vector3=source_view.connection_center(animated_piece_id)
	if animated_piece_id.begins_with("rib_"):mouth.x=-.55 if animated_piece_id.begins_with("rib_l") else .55
	elif animated_piece_id in ["bow","stern"]:mouth.z=-4.45 if animated_piece_id=="bow" else 4.45
	else:mouth.x=2.97
	return mouth

func _prepare_install() -> void:
	if not observation_mode: return
	if selected_joint.is_empty() or selected_length.is_empty():
		_show_choice_hint()
		return
	# This button only restores a clear working angle. It never installs a part.
	_focus_connection(animated_piece_id,true)
	_frame_trial_candidate()
	_configure_drag()
	status.text="抓住木料，沿箭头往槽内推。推入后松手，往回拖可抽出；拖空白处转动查看。"
	install_button.text="拖动木料试装"

func reject_install(message: String) -> void:
	show_connection(animated_piece_id,selected_length,false,selected_joint)
	status.text=message+" 可换一种榫头，再拖动试装。"
	status.modulate=Color("8b4835")

func _show_choice_hint() -> void:
	if not observation_mode:
		status.text="木料正在装入，稍等一下。" if _animating else "想换一块，可以点“取回调整”。"
		return
	if selected_joint.is_empty():
		status.text="先点上方，挑一个榫头。" if selected_length.is_empty() else "木料 %s 已选好，再点上方挑一个榫头，就能拖动试装。"%LengthComparison.LABELS[selected_length]
	elif selected_length.is_empty():
		status.text="榫头选好了，再点右侧挑一块木料。"
	else:
		status.text="抓住木料，沿箭头推入；往回拖可以抽出。拖空白处转动查看。"

func _choose_joint(id: String) -> void:
	if not observation_mode: return
	var preserve_xray: bool=xray_button.button_pressed
	show_connection(animated_piece_id,_length,false,id)
	xray_button.set_pressed(preserve_xray)
	joint_chosen.emit(id)

func _choose_length(id: String) -> void:
	if not observation_mode: return
	var preserve_xray: bool=xray_button.button_pressed
	show_connection(animated_piece_id,id,false,selected_joint)
	xray_button.set_pressed(preserve_xray)
	length_chosen.emit(id)

func joint_id_for(id: String) -> String:
	return "blind_tenon" if id.begins_with("rib_") else ("through_tenon" if id.begins_with("beam") else "dovetail")

func _focus_connection(id: String, reset_orbit: bool = true) -> void:
	var center: Vector3=source_view.connection_center(id)
	var direction := Vector3(5,3.3,5)
	camera.size=3.9
	if id.begins_with("rib_"):
		var side := -1.0 if id.begins_with("rib_l") else 1.0
		center+=Vector3(side*.55,.5,0)
		direction=Vector3(side*5,3.2,4)
		camera.size=4.1
	elif id.begins_with("beam"):
		center=Vector3(3.5 if observation_mode else 0.0,1.8,center.z)
		direction=Vector3(4,3.7,8)
		camera.size=6.2 if observation_mode else 5.5
	else:
		direction=Vector3(4,3.8,-5 if id == "bow" else 5)
		camera.size=3.1
	orbit.configure(camera,center,direction,reset_orbit)

func _clone_materials(node: Node) -> void:
	if node is MeshInstance3D and node.material_override:
		node.material_override=node.material_override.duplicate()
	for child in node.get_children(): _clone_materials(child)

func _set_cutaway(enabled: bool) -> void:
	var opaque_section: bool=animated_piece_id in ["bow","stern"] or animated_piece_id.begins_with("beam")
	for id in pieces:
		ReceiverSection.restore(pieces[id])
		_set_transparent(pieces[id],enabled and id!=animated_piece_id and not opaque_section)
		if enabled and opaque_section and id!=animated_piece_id:
			ReceiverSection.apply(animated_piece_id,pieces[id],animated_piece,source_view.trial_pose(animated_piece_id,_length,selected_joint),_receiver_tip(),camera)
	if enabled and animated_piece_id.begins_with("rib_") and pieces.has("keel"):
		var web=pieces.keel.find_child("BlindSlotWeb",true,false)
		if web:_set_transparent(web,false)

func _set_transparent(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mat:=node.material_override as StandardMaterial3D
		if mat:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a=.24 if enabled else 1.0
	for child in node.get_children(): _set_transparent(child,enabled)

func close() -> void:
	if is_instance_valid(_motion): _motion.kill()
	if is_instance_valid(orbit): orbit.deactivate()
	_animating=false
	opened=false
	if is_instance_valid(viewport): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	hide()
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _label(parent: Node, words: String, size: int) -> Label:
	var label := Label.new()
	label.text=words
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, words: String) -> Button:
	var button := Button.new()
	button.text=words
	button.custom_minimum_size=Vector2(140,52)
	parent.add_child(button)
	return button

func _style_neutral_selection(button: Button) -> void:
	for state in ["pressed","hover_pressed"]:
		button.add_theme_stylebox_override(state,Friendly.block(Color("dbe4e5"),Color("7b9098"),2))
