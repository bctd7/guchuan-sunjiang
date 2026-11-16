extends SceneTree
## Real Viewport GUI events; no direct writes to gameplay state.
var level: Node3D
var passed := 0
var failed := 0
var failures: Array[String]=[]
var requests := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		failures.append(label)
		push_error("FAIL "+label)
func settle(seconds := .15) -> void:
	await create_timer(seconds).timeout
	await process_frame
func mouse(point: Vector2, pressed: bool, device := 0) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	motion.device=device
	root.push_input(motion,true)
	var event:=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed=pressed
	event.device=device
	root.push_input(event,true)
	await process_frame
func click(point: Vector2) -> void:
	await mouse(point,true)
	await mouse(point,false)
	await process_frame
func touch(point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=point
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
func button(control: Button) -> void:
	check(control.is_visible_in_tree() and not control.disabled,"button operable: "+control.text)
	await click(control.get_global_rect().get_center())
func snapshot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/level01"))
	root.get_texture().get_image().save_png("res://tests/evidence/level01/"+label+".png")
func select_piece(id: String) -> void:
	check(level.state.selected==id,"flow identifies current distinct member: "+id)
	await button(level.panel.inspect_button)
	check(level.inspector.observation_mode,"one entry opens actual candidate view")
func choose_joint(kind: String, length: String = "correct") -> void:
	if not level.inspector.visible: await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons[kind])
	check(level.joint_type==kind,"candidate choice belongs only to observation page: "+kind)
	await button(level.inspector.length_buttons[length])
	check(level.tenon_length==length and level.inspector.selected_length==length,"explicit length choice belongs to observation page: "+length)
	await button(level.inspector.close_button)
func finish_review() -> void:
	var elapsed:=0.0
	while level.inspector.is_animating and elapsed<5:
		await settle(.1)
		elapsed+=.1
	check(level.inspector.animation_finished,"manual joint demonstration reaches actual final pose")
	await button(level.inspector.close_button)
	check(level.busy,"return starts visibly labelled automatic assembly")
	elapsed=0
	var animated: Array[String]=[]
	var representative: String=level.state.pending_group
	while level.busy and elapsed<12:
		check(level.panel.check_button.disabled,"stability inspection disabled throughout automatic insertion")
		check(not level.state.pending_group.is_empty(),"group remains pending until its last animation seats")
		check(level.view.animations.size()<=1,"automatic members animate one at a time")
		for id in level.view.animations:
			if not animated.has(id): animated.append(id)
		await settle(.04)
		elapsed+=.04
	check(animated==level.Rules.AUTO_GROUPS[representative],"every automatic member animates in declared order: "+representative)
	check(not level.busy and level.state.pending_group.is_empty() and level.view.animations.is_empty(),"automatic group and its actual animation finish before next task")
func place(id: String, kind: String, use_touch := false) -> void:
	var before: int=level.state.progress_count()
	await select_piece(id)
	await choose_joint(kind)
	var target: Vector2=level.view.socket_screen_position(id)
	check(level.view.pick_socket(target)==id,"only current representative is an interactive socket")
	if use_touch: await touch(target)
	else: await click(target)
	check(level.state.progress_count()==before+1 and level.state.pending_group==id,"player action records exactly one demonstration")
	check(level.busy and level.view.animations.has(id) and level.panel.check_button.disabled,"manual member animates before inspection can pass: "+id)
	level.panel.check_button.pressed.emit()
	check(not level.state.completed,"inspection signal cannot bypass active insertion: "+id)
	await finish_review()
	for auto_id in level.Rules.AUTO_GROUPS[id]:
		check(level.state.placed[auto_id].automatic and level.state.placed[auto_id].demonstrated_by==id,"automatic provenance is explicit: "+auto_id)
		check(level.view.pieces[auto_id].visible and level.view.pieces[auto_id].position.is_zero_approx(),"automatic member seats visibly: "+auto_id)
func geometry_signature(node: Node) -> String:
	var value: String=str(node.transform) if node is Node3D else ""
	if node is MeshInstance3D: value+=str(node.mesh.get_faces())+str(node.visible)
	for child in node.get_children(): value+=geometry_signature(child)
	return value
func report(path: String, title: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"failures":failures,"renderer":DisplayServer.get_name(),"host_no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"host_had_focus":root.has_focus(),"method":"Viewport mouse/touch injection, not human hardware input"},"  "))
	print(title,": ",passed," passed, ",failed," failed")
	level.free()
	quit(0 if failed==0 else 1)
func run() -> void:
	root.size=Vector2i(1440,900)
	level=load("res://levels/level01/level01.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await settle()
	level.interaction.socket_requested.connect(func(_id: String): requests+=1)
	check(level.state.placed.size()==1 and level.state.placed.has("keel") and level.state.progress_count()==0,"fixed foundation starts outside manual progress")
	check(level.view.pieces.keel.visible and not level.view.ghosts.keel.visible and not level.view.slots.keel.visible,"fixed foundation has neither choice nor target")
	check(level.panel.piece_buttons.is_empty() and level.panel.joint_buttons.is_empty() and level.panel.length_buttons.is_empty(),"main page contains no duplicate selectors")
	check(level.panel.check_button.disabled,"incomplete structure cannot request stability inspection")
	check(level.panel.undo_button.disabled and level.joint_type.is_empty() and level.tenon_length.is_empty(),"fresh game has no undo or default type/length answer")
	check(level.state.progress_count()==0 and level.state.automatic_count()==0,"manual and automatic progress start empty")
	await snapshot("01-start-three-demonstrations")
	await select_piece("rib_l1")
	check(level.inspector.selected_joint.is_empty() and not level.inspector.orbit.assembly_enabled,"reference is visible but no type is preselected")
	check(level.inspector.length_buttons.size()==3 and level.inspector.candidate_panel.visible and level.inspector.selected_length.is_empty(),"three measurable lengths appear without a default")
	for length_button in level.inspector.length_buttons.values(): check(not length_button.button_pressed,"no length button starts selected")
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	check(level.state.progress_count()==0 and level.state.placed.size()==1,"neutral observation cannot install without choices")
	await select_piece("rib_l1")
	await button(level.inspector.joint_buttons["blind_tenon"])
	check(level.tenon_length.is_empty(),"selecting a type does not silently select length")
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	check(level.state.progress_count()==0 and not level.busy,"type alone cannot bypass explicit length choice")
	await select_piece("rib_l1")
	check(level.inspector.selected_joint=="blind_tenon" and level.inspector.selected_length.is_empty(),"reopen preserves chosen type and neutral length")
	await choose_joint("dovetail")
	await click(level.view.socket_screen_position("rib_l1"))
	check(level.state.placed.has("rib_l1") and level.state.placed.rib_l1.joint=="dovetail" and level.busy,"wrong type starts a real trial without becoming stable")
	await settle(3.0)
	check(not level.state.failed and not level.panel.failure_overlay.visible,"wrong representative never ends an incomplete level")
	await button(level.inspector.close_button)
	var trial_deadline:=Time.get_ticks_msec()+10000
	while level.busy and Time.get_ticks_msec()<trial_deadline: await process_frame
	check(level.state.automatic_count()==5 and not level.state.failed,"wrong choices propagate through the full automatic group before verdict")
	await button(level.panel.restart_button)
	check(level.state.progress_count()==0 and level.state.placed.size()==1 and not level.busy and not level.state.failed,"failure restart restores the first task")
	await choose_joint("blind_tenon")
	var target: Vector2=level.view.socket_screen_position("rib_l1")
	await mouse(level.panel.inspect_button.get_global_rect().get_center(),true)
	await mouse(target,false)
	check(level.state.progress_count()==0,"GUI press released over wood cannot place it")
	await mouse(target+Vector2(80,0),true)
	await mouse(target,false)
	check(level.state.progress_count()==0,"drag is not an accidental placement tap")
	await click(target)
	check(level.busy and level.state.progress_count()==1 and level.state.automatic_count()==0,"manual review precedes all automatic work")
	await button(level.inspector.close_button)
	check(level.busy and level.state.automatic_count()==0 and level.view.animations.has("rib_l1"),"closing review early waits for the actual representative insertion")
	var wait_for_automatic:=0.0
	while level.busy and level.state.automatic_count()==0 and wait_for_automatic<2:
		check(level.panel.check_button.disabled and level.view.animations.size()==1,"early-close wait keeps stability gated and one member moving")
		await settle(.04)
		wait_for_automatic+=.04
	check(level.state.automatic_count()>0 and level.panel.feedback_label.text.contains("同类木料"),"approved copy explicitly identifies same-kind automatic members while provenance remains automatic")
	check(not level.view.animations.has("rib_l1") and level.view.animations.size()==1,"automatic repeat starts only after representative tween finishes")
	await snapshot("02-automatic-labelled")
	await button(level.panel.undo_button)
	await settle(1.2)
	check(not level.busy and level.state.placed.size()==1 and level.state.placement_order.is_empty(),"undo cancels manual plus partially automated group without late callbacks")
	check(level.view.pieces.keel.visible and level.view.animations.is_empty(),"undo preserves fixed base and cancels animation handles")
	await place("rib_l1","blind_tenon",true)
	check(level.state.progress_count()==1 and level.state.automatic_count()==5 and level.state.installed_count()==6,"one half-tenon action produces three complete symmetric pairs")
	check(level.state.selected=="bow" and level.joint_type.is_empty() and level.tenon_length.is_empty(),"next unique task has no inherited type or length answer")
	var saved: Dictionary=level.state.placed.duplicate(true)
	await button(level.panel.inspect_button)
	await button(level.inspector.lesson_button)
	await settle(.4)
	check(level.learning.opened and level.learning.lesson_buttons.size()==3,"revisit opens this chapter's three-lesson introduction")
	await button(level.learning.lesson_buttons.blind_tenon)
	check(is_instance_valid(level.learning.workshop) and level.learning.workshop.catalog.size()==3,"chapter classroom filters to three original lessons")
	check(level.learning.workshop.assembly.definition.id=="blind_tenon","clicked original lesson is selected")
	await button(level.learning.back_button)
	check(level.learning.opened and level.learning.workshop==null,"classroom back returns to introduction")
	await button(level.learning.start_button)
	await settle(.2)
	check(level.state.placed==saved and level.state.selected=="bow","classroom return preserves manual and automatic connections")
	await place("bow","dovetail")
	check(level.state.progress_count()==2 and level.state.automatic_count()==6,"one open-end dovetail action automatically mirrors the other end")
	await place("beam1","through_tenon")
	check(level.state.progress_count()==3 and level.state.automatic_count()==7 and level.state.placed.size()==11,"three actions complete the original eleven-member skeleton")
	check(level.state.is_stable(),"full structure remains required")
	await button(level.panel.check_button)
	check(level.state.completed and level.panel.success_panel.visible,"explicit final inspection passes complete symmetric structure")
	await snapshot("05-complete-three-demonstrations")
	await button(level.panel.undo_button)
	check(not level.state.completed and not level.state.placed.has("beam1") and not level.state.placed.has("beam3"),"undo after victory removes through-tenon demonstration and its repeat")
	check(level.state.progress_count()==2 and level.state.automatic_count()==6,"group undo never credits removed automatic work")
	await place("beam1","through_tenon")
	await button(level.panel.check_button)
	check(level.state.completed,"group undo can be corrected and completed again")
	await button(level.panel.restart_button)
	check(level.state.placed.size()==1 and level.state.progress_count()==0 and level.joint_type.is_empty() and level.tenon_length.is_empty(),"reset preserves base and clears all choices/history")
	await select_piece("rib_l1")
	await choose_joint("blind_tenon")
	await click(level.view.socket_screen_position("rib_l1"))
	await button(level.inspector.close_button)
	await settle(.12)
	await button(level.panel.restart_button)
	await settle(1.2)
	check(not level.busy and level.state.placed.size()==1 and level.state.pending_group.is_empty(),"reset during automatic motion cannot resurrect any repeat")
	report("res://tests/level01_input_report.json","LEVEL01 INPUT")
