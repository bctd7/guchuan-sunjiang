extends CanvasLayer
const StepGuide=preload("res://components/ui/step_guide.gd")
var step_guide: Control
const ExhibitLayout=preload("res://components/ui/exhibition_layout.gd")
## Close-up clones of THIS level's real ship parts; no standalone joint substitutes.
## It observes the level, and never changes its accepted connections.
signal closed
signal joint_chosen(id: String)
signal length_chosen(id: String)
signal lesson_requested
signal install_requested
signal trial_finished
signal retry_requested
var lesson_button: Button
var retry_button: Button
var _review_only:=false
var magnifier: Control
var zoom_bar: Control
var zoom_factor:=1.0
var _zoom_base_size:=4.0
var _zoom_center:=Vector3.ZERO
var _zoom_direction:=Vector3.ONE
var length_gallery: Control
var stage_surface: Control
const Magnifier=preload("res://components/preview/model_magnifier.gd")
const ZoomBar=preload("res://components/preview/inspection_zoom_bar.gd")
const Workspace=preload("res://components/ui/inspection_workspace.gd")
const LengthComparison=preload("res://components/ui/measurements/length_measure_panel.gd")
const Trial=preload("res://models/ship/keel/trial_fit.gd")
const TrialReceiver=preload("res://models/ship/keel/trial_receiver.gd")
const ReceiverSection=preload("res://models/ship/keel/receiver_section.gd")
const Lengths=preload("res://models/ship/keel/length_geometry.gd")
const Look = preload("res://components/teaching/classroom/display/workshop_look.gd")
const Friendly = preload("res://components/ui/friendly_theme.gd")
const InspectionGeometry = preload("res://levels/level01/inspector/inspection_geometry.gd")
const TypeGallery = preload("res://levels/level01/type_gallery.gd")
const InspectionOrbit = preload("res://levels/level01/assembly_drag_surface.gd")
const LengthGallery = preload("res://levels/level01/length_candidate_gallery.gd")
const COPY := {
	"blind_tenon": "半榫 · 榫头藏进盲槽",
	"dovetail": "燕尾榫 · 沿开放端滑入",
	"through_tenon": "透榫 · 横撑穿过两侧船肋"
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
	hide()
	set_process(false)
	get_viewport().size_changed.connect(_fit_observation_layout)
	tree_entered.connect(_fit_observation_layout.call_deferred)
	visibility_changed.connect(_sync_observation)
	_fit_observation_layout()

func configure(skeleton: Node3D) -> void:
	source_view=skeleton

func _build() -> void:
	root=Workspace.new()
	add_child(root)
	var head: HBoxContainer=root.header
	title=root.title
	title.text="看清榫头与槽口"
	lesson_button=_button(head,"本关榫卯讲解")
	lesson_button.pressed.connect(func():lesson_requested.emit())
	retry_button=_button(head,"取回调整")
	retry_button.pressed.connect(func():retry_requested.emit())
	close_button=_button(head,"返回骨架")
	close_button.pressed.connect(close)
	joint_choices=TypeGallery.new()
	root.candidates.add_child(joint_choices)
	joint_buttons=joint_choices.buttons
	for candidate in joint_buttons.values():
		candidate.custom_minimum_size.y=40
		_style_neutral_selection(candidate)
	joint_choices.chosen.connect(_choose_joint)
	joint_choices.inspect_requested.connect(func(id: String):_magnify(joint_choices.previews[id],TypeGallery.TYPES[id]))
	stage_surface=root.stage_surface
	var container: SubViewportContainer=root.viewport_container
	candidate_panel=root.options
	comparison=LengthComparison.new()
	candidate_panel.add_child(comparison)
	length_gallery=LengthGallery.new()
	candidate_panel.add_child(length_gallery)
	length_buttons=length_gallery.buttons
	length_gallery.chosen.connect(_choose_length)
	length_gallery.inspect_requested.connect(func(id: String):_magnify(length_gallery.previews[id],"长度候选 · 木料 "+LengthGallery.option_label(id)))
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.size=Vector2i(1000,490)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.05
	camera.current=true
	world.add_child(camera)
	Look.install(world,camera)
	camera.environment.background_color=Color("fff7e9")
	# The surface belongs only to the main close-up; cards and rulers stay GUI.
	orbit=InspectionOrbit.new()
	orbit.name="InspectionOrbit"
	stage_surface.add_child(orbit)
	orbit.zoom_requested.connect(_zoom_observation)
	orbit.assembly_requested.connect(func(): install_requested.emit())
	orbit.insertion_progress_changed.connect(_sync_trial_receiver)
	orbit.selection_required.connect(_show_choice_hint)
	var actions: HBoxContainer=root.actions
	status=root.status
	step_guide=StepGuide.new();root.add_child(step_guide)
	xray_button=_button(actions,"看孔内")
	xray_button.toggle_mode=true
	xray_button.toggled.connect(_set_cutaway)
	replay_button=_button(actions,"再看插入")
	replay_button.pressed.connect(func(): show_connection(animated_piece_id,_length,not observation_mode,selected_joint,_review_only))
	zoom_bar=ZoomBar.new();stage_surface.add_child(zoom_bar)
	root.mount_camera_tools(zoom_bar)
	zoom_bar.zoom_requested.connect(_zoom_observation);zoom_bar.reset_requested.connect(_reset_observation_zoom)
	magnifier=Magnifier.new();root.add_child(magnifier)
	step_guide.blocker=magnifier
	orbit.guidance_blocker=magnifier
	magnifier.visibility_changed.connect(_sync_observation)

func _sync_observation() -> void:
	if viewport == null:
		return
	var running: bool = visible and opened and not magnifier.visible
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if running else SubViewport.UPDATE_DISABLED
	orbit.set_process(running)
	orbit.set_process_input(running)
	set_process(visible and opened)
	for preview in joint_choices.previews.values() + length_gallery.previews.values():
		preview.set_suspended(not running)

func show_connection(piece_id: String, length: String = "", animate: bool = false, joint_type: String = "", review_installed: bool = false, released_pose: Variant = null, audible := false) -> void:
	if not is_instance_valid(source_view) or not source_view.pieces.has(piece_id) or piece_id == "keel": return
	if root == null:
		_build()
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
	pieces.merge(InspectionGeometry.create_parts(source_view,world,piece_id,length,joint_type,observation_mode))
	animated_piece=pieces[piece_id]
	title.text=COPY[joint_id]
	if not observation_mode:
		title.text="试装 · "+str(TypeGallery.TYPES.get(joint_type,"木料"))
	if observation_mode:
		title.text="观察船肋与龙骨" if piece_id.begins_with("rib_") else ("观察横撑与船肋" if piece_id.begins_with("beam") else "观察龙骨端接")
	xray_button.set_pressed_no_signal(false)
	_set_cutaway(false)
	status.text=""
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


	if not _keep_drag_framing:_focus_connection(piece_id,not preserve_angle)
	close_button.text="返回骨架"
	opened=true
	show()
	_sync_observation()
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
	_remember_zoom_frame()
	_fit_observation_layout()
	if animate:
		var final: Transform3D=source_view.trial_pose(piece_id,length,joint_type)
		animated_piece.transform=_safe_trial_entry(final)
		if released_pose is Transform3D:
			animated_piece.transform=released_pose
			animated_piece.set_meta("trial_release_start",released_pose)
		if joint_type!=joint_id_for(piece_id) and not _keep_drag_framing:_frame_trial_candidate()
		_animating=true
		status.text="木料正在装入。"
		_motion=create_tween()
		var slide_time:=1.8
		if released_pose is Transform3D:slide_time=clampf(released_pose.origin.distance_to(final.origin)*.24,.12,.55)
		_motion.tween_interval(.04 if released_pose is Transform3D else .3)
		_motion.tween_property(animated_piece,"transform",final,slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if audible:_motion.tween_callback(func():preload("res://audio/seating_audio.gd").play(self))
		_motion.tween_callback(_finish_trial_review)
	elif not observation_mode:_finish_trial_review()
	_update_guide()

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
	title.text="这一处已试装"
	status.text=""
	_remember_zoom_frame()
	close_button.text="返回船架" if _review_only else "继续搭建"
	_update_guide()
	trial_finished.emit()

func _collect_trial_corners(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.mesh and node.visible:
		var bounds: AABB=node.mesh.get_aabb()
		for index in 8:points.append(node.to_global(bounds.get_endpoint(index)))
	for child in node.get_children():_collect_trial_corners(child,points)

func _frame_trial_candidate(include_context := false) -> void:
	# Keep the entire tested wood and receiving mouth visible; no geometry scaling.
	var points: Array[Vector3]=[]
	if include_context:
		for member in pieces.values():_collect_trial_corners(member,points)
	else:
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
	return InspectionGeometry.receiver_tip(animated_piece,animated_piece_id)

func _grab_point() -> Vector3:
	return InspectionGeometry.grab_point(animated_piece,animated_piece_id,_length)

func _configure_drag() -> void:
	var enabled: bool=observation_mode and not selected_joint.is_empty() and not selected_length.is_empty()
	var seated: Transform3D=source_view.trial_pose(animated_piece_id,_length,selected_joint)
	var contact_local: Vector3=animated_piece.to_local(world.to_global(_tip_front()))
	orbit.configure_assembly(animated_piece,seated,_grab_point(),enabled,world.to_global(_entry_mouth()),contact_local)
	orbit.preview_limit=1.0

func _tip_front() -> Vector3:
	return InspectionGeometry.tip_front(animated_piece,animated_piece_id,source_view,world)

func _entry_mouth() -> Vector3:
	return InspectionGeometry.entry_mouth(animated_piece_id,source_view)

func reject_install(message: String) -> void:
	show_connection(animated_piece_id,selected_length,false,selected_joint)
	status.text=message
	status.modulate=Color("8b4835")

func _show_choice_hint() -> void:
	status.text="木料正在装入。" if _animating else ""

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
	InspectionGeometry.clone_materials(node)

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
	InspectionGeometry.set_transparent(node,enabled)

func close() -> void:
	if root == null:
		return
	preload("res://audio/seating_audio.gd").cancel(self)
	magnifier.close()
	if is_instance_valid(_motion): _motion.kill()
	if is_instance_valid(orbit): orbit.deactivate()
	_animating=false
	opened=false
	if is_instance_valid(viewport): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	hide()
	_sync_observation()
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		if magnifier.visible:magnifier.close()
		else:close()
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
	button.custom_minimum_size=Vector2(140,60)
	parent.add_child(button)
	return button

func _style_neutral_selection(button: Button) -> void:
	Workspace.neutral_selection(button)

func _remember_zoom_frame() -> void:
	zoom_factor=1.0;_zoom_base_size=camera.size;_zoom_center=orbit._center;_zoom_direction=orbit._direction
	zoom_bar.update_zoom(zoom_factor)
func _zoom_observation(factor: float) -> void:
	if not opened or _animating or orbit.assembly_dragging or magnifier.visible:return
	zoom_factor=clampf(zoom_factor*factor,.25,1.6)
	orbit._center=_zoom_center.lerp(_entry_mouth(),clampf((1.0-zoom_factor)/.75,0.0,1.0))
	orbit._apply_camera();camera.size=_zoom_base_size*zoom_factor;zoom_bar.update_zoom(zoom_factor)
func _reset_observation_zoom() -> void:
	if not opened or _animating or orbit.assembly_dragging or magnifier.visible:return
	zoom_factor=1.0;orbit._center=_zoom_center;orbit._direction=_zoom_direction
	orbit.angles=Vector2.ZERO;orbit.target_angles=Vector2.ZERO;orbit._apply_camera()
	camera.size=_zoom_base_size;zoom_bar.update_zoom(zoom_factor)
func _magnify(source: Control,caption: String) -> void:
	if not opened or _animating or orbit.assembly_dragging:return
	orbit.suspend_gesture()
	orbit.set_process_input(false)
	magnifier.open(source,caption)
func _fit_observation_layout() -> void:
	if not is_inside_tree() or not is_instance_valid(root) or not is_instance_valid(zoom_bar):return
	var dimensions:=get_viewport().get_visible_rect().size
	var factor:=ExhibitLayout.factor(dimensions)
	root.fit_screen()
	zoom_bar.set_display_scale(factor);magnifier.set_display_scale(factor)
	root.layout_camera_tools(root.scale.x)
	for card in joint_choices.buttons.values():
		card.fit_inspect_button(factor)
	for button in length_gallery.inspect_buttons.values():button.custom_minimum_size=Vector2(maxf(56,60/factor),60/factor)

func _process(_delta: float) -> void:
	_update_guide()

func _update_guide() -> void:
	if not opened or not is_instance_valid(step_guide):return
	var area: Control
	if not _animating:
		if not observation_mode:area=close_button
		elif selected_joint.is_empty():area=joint_choices
		elif selected_length.is_empty():area=length_gallery
	var candidates: Array = joint_buttons.values() if area == joint_choices else length_buttons.values() if area == length_gallery else []
	step_guide.show_target(area, candidates)
	for button in [lesson_button,close_button,xray_button,replay_button,zoom_bar.zoom_in,zoom_bar.zoom_out,zoom_bar.reset_button]:button.disabled=_animating
	StepGuide.action(retry_button,not observation_mode and not _animating and not _review_only)
	retry_button.visible=retry_button.modulate.a>0
	_completion_layout(not observation_mode and not _animating and animation_finished)


func _completion_layout(done: bool) -> void:
	var changed: bool=close_button.get_parent()!=root.actions if done else close_button.get_parent()!=root.header
	if done:
		if retry_button.get_parent()!=root.actions:retry_button.reparent(root.actions)
		if close_button.get_parent()!=root.actions:close_button.reparent(root.actions)
		retry_button.text="取回重选"
		close_button.text="继续搭建"
	else:
		if retry_button.get_parent()!=root.header:retry_button.reparent(root.header)
		if close_button.get_parent()!=root.header:close_button.reparent(root.header)
		retry_button.text="取回调整"
	xray_button.visible=not done
	replay_button.visible=not done
	zoom_bar.visible=not done
	root.options.get_parent().visible=not done and candidate_panel.visible
	status.visible=not done
	for child in root.camera_actions.get_children():
		if child is VSeparator:child.visible=not done
	root.actions.alignment=BoxContainer.ALIGNMENT_END if done else BoxContainer.ALIGNMENT_CENTER
	zoom_bar.reset_button.text="重置视角"
	if done and changed:_fit_completed_view.call_deferred()

func _fit_completed_view() -> void:
	if not opened or observation_mode or _animating:return
	_frame_trial_candidate(true)
	_remember_zoom_frame()
