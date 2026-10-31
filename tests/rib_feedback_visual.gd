extends "res://tests/rib_repair_visual.gd"
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"GPU no focus")
	if not failures.is_empty():quit(2);return
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.2)
	await button(campaign.chapter_buttons[1])
	level=campaign.instances[1]
	await button(level.learning.start_button)
	await button(level.panel.inspect_button)
	var overlay=level.inspector.orbit
	var point: Vector2=overlay.global_position+far_body_point()
	var old: Transform3D=level.inspector.camera.transform
	await stroke(point,point+Vector2(30,25))
	check(old.is_equal_approx(level.inspector.camera.transform) and not level.busy,"unselected real timber press prompts without rotation or install")
	await capture("unselected-timber-prompts")
	await button(level.inspector.joint_buttons.blind_tenon)
	await button(level.inspector.length_buttons.correct)
	await settle(.1)
	point=overlay.global_position+far_body_point()
	var delta: Vector2=overlay.target_screen()-overlay.drag_start_screen()
	await pointer(point,true)
	for i in range(1,10):
		var event:=InputEventMouseMotion.new()
		event.position=point+delta*i/10.0
		event.global_position=event.position
		event.relative=delta/10
		event.button_mask=MOUSE_BUTTON_MASK_LEFT
		surface.push_input(event,true)
		await process_frame
	check(overlay.assembly_dragging and overlay._in_capture_zone(overlay._last_point),"held part ready for original snap threshold")
	await capture("ready-release-feedback")
	await pointer(point+delta*.9,false)
	check(level.busy and level.state.placed.has("rib_l1"),"feedback corresponds to actual release acceptance")
	await settle(2.3)
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"method":"Actual GPU feedback and full-timber GUI mouse events; no native desktop input or physical touchscreen."}
	FileAccess.open(OUT+"feedback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RIB_FEEDBACK ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
