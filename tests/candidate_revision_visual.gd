extends "res://tests/resumed_level01_visual.gd"
const DEST="res://tests/evidence/candidate-revision/"

func capture(label: String) -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path:=DEST+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual pixels "+label)
	images.append(path)

func pointer(point: Vector2,down: bool,touch:=false,canceled:=false) -> void:
	if touch:
		var event:=InputEventScreenTouch.new()
		event.position=point
		event.index=0
		event.pressed=down
		event.canceled=canceled
		surface.push_input(event,true)
	else:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		surface.push_input(event,true)
	await process_frame

func stroke(start: Vector2,end: Vector2,touch:=false,cancelled:=false) -> void:
	await pointer(start,true,touch)
	var last:=start
	for i in range(1,11):
		var point:=start.lerp(end,i/10.0)
		if touch:
			var event:=InputEventScreenDrag.new()
			event.position=point
			event.relative=point-last
			event.index=0
			surface.push_input(event,true)
		else:
			var event:=InputEventMouseMotion.new()
			event.position=point
			event.global_position=point
			event.relative=point-last
			event.button_mask=MOUSE_BUTTON_MASK_LEFT
			surface.push_input(event,true)
		last=point
		await process_frame
	await pointer(end,false,touch,cancelled)
	await settle(.1)

func drag_part(touch:=false,amount:=1.0,cancelled:=false) -> void:
	var overlay: Control=level.inspector.orbit
	var start: Vector2=overlay.global_position+overlay.drag_start_screen()
	var target: Vector2=overlay.global_position+overlay.target_screen()
	check(overlay.get_global_rect().has_point(start) and overlay.get_global_rect().has_point(target),"grab and target visible")
	await stroke(start,start.lerp(target,amount),touch,cancelled)

func candidates(id: String) -> void:
	await button(level.panel.inspect_button)
	check(level.inspector.selected_joint.is_empty() and level.inspector.selected_length.is_empty(),"no answer selected "+id)
	check(not level.inspector.orbit.assembly_enabled,"unchosen cannot install")
	await capture(id+"-unselected")
	for kind in ["blind_tenon","dovetail","through_tenon"]:
		await button(level.inspector.joint_buttons[kind])
		for length in ["long","short","correct"]:
			await button(level.inspector.length_buttons[length])
			check(level.joint_type==kind and level.tenon_length==length,"explicit choice "+id+kind+length)
			check(level.inspector.orbit.assembly_enabled,"selection enables drag")
			if length=="correct": await capture(id+"-"+kind)
	await button(level.inspector.joint_buttons[level.Rules.expected_joint(id)])

func gesture_install(id: String,length: String,touch:=false) -> void:
	await button(level.inspector.length_buttons[length])
	var before: int=level.state.placed.size()
	await button(level.inspector.install_button)
	check(level.state.placed.size()==before,"prepare button never installs")
	await drag_part(touch,.4)
	check(not level.state.placed.has(id),"partial stroke returns")
	await settle(.5)
	if touch:
		await drag_part(true,1.0,true)
		check(not level.state.placed.has(id),"canceled finger cannot install")
		await settle(.5)
	await drag_part(touch)
	check(level.state.placed.has(id) and level.busy,"gesture installs "+id)
	await settle(2.3)
	await button(level.inspector.close_button)
	await wait_motion()
	await settle(.5)

func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"GPU without focus")
	if not failures.is_empty(): quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.3)
	await button(campaign.chapter_buttons[1])
	level=campaign.instances[1]
	await button(level.learning.start_button)
	await capture("main-natural-guidance")
	for id in level.Rules.REPRESENTATIVE_IDS:
		await candidates(id)
		var inspector=level.inspector
		var overlay=inspector.orbit
		var start: Vector2=overlay.global_position+Vector2(50,60)
		var angles: Vector2=overlay.target_angles
		await stroke(start,start+Vector2(55,25),id=="bow")
		check(overlay.target_angles!=angles,"background rotates "+id)
		await settle(.5)
		await capture(id+"-rotated")
		await button(inspector.replay_button)
		await settle(.5)
		await button(inspector.joint_buttons["dovetail" if id!="bow" else "blind_tenon"])
		await drag_part()
		check(level.state.placed.has(id) and level.busy and not inspector.observation_mode,"wrong shape is accepted as an unstable trial "+id)
		await settle(3.0)
		await button(inspector.retry_button)
		check(not level.state.placed.has(id) and inspector.observation_mode,"unstable shape can be taken back for another choice "+id)
		await button(inspector.joint_buttons[level.Rules.expected_joint(id)])
		await gesture_install(id,"long" if id!="rib_l1" else "short",id=="bow")
	check(level.state.automatic_count()==7,"seven automatic members retained")
	await button(level.panel.check_button)
	check(not level.state.completed,"wrong lengths install but unstable")
	await capture("wrong-length-instability")
	await wait_motion()
	await button(level.panel.restart_button)
	for id in level.Rules.REPRESENTATIVE_IDS:
		await button(level.panel.inspect_button)
		await button(level.inspector.joint_buttons[level.Rules.expected_joint(id)])
		await gesture_install(id,"correct",id=="beam1")
	await button(level.panel.check_button)
	check(level.state.completed,"correct mouse/touch snapped frame completes")
	await button(level.panel.success_close_button)
	await capture("completed-frame")
	check(not root.has_focus(),"host still without focus")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"method":"Actual GPU pixels and Viewport-dispatched mouse/touch sequences. Hidden NO_FOCUS host, no desktop input. Not human or physical touchscreen play."}
	FileAccess.open(DEST+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CANDIDATE_REVISION ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
