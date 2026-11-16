extends "res://tests/level02_clarity_zoom_tests.gd"
## Ship-connected local context. Public GUI mouse and simulated touch, not State writes.
func capture(name: String) -> void:
	if not gpu:return
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/hull-structure/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/hull-structure"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU image "+name);images.append(path)
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
	await capture("overview-start")
	for id in level.Rules.IDS:
		if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):continue
		await prepare(id)
		if id in ["cross_upper","three_middle","three_upper","bulkhead"]:
			check(level.view.local_context.visible and level.view.local_context.get_child_count()>0,"actual ship context accompanies the connection "+id)
			check(solid_wood(level.view.local_context),"context shares opaque grain with actual wood "+id)
			await capture("local-"+id+"-before")
			if id=="cross_upper":
				for dimensions in [Vector2i(1100,800),Vector2i(960,600)]:
					surface.size=dimensions;await settle(.2);await capture("local-cross-"+str(dimensions.x))
					var frame:=workspace_rect().grow(1)
					check(level.view.inspection_focus_corners().all(func(point):return frame.has_point(level.view.project_point(point))),"mating members fit "+str(dimensions))
				surface.size=Vector2i(1440,900);await settle(.2)
				await button(level.panel.transparent_button)
				check(not solid_wood(level.view.local_context) and solid_wood(level.view.pieces[id]),"optional reveal dims context, never held wood")
				await button(level.panel.zoom_reset_button)
				await drag_region(workspace_rect(),Vector2(40,18));await button(level.panel.zoom_in_button);await capture("cross-rotated-zoomed")
				await button(level.panel.zoom_reset_button)
		await settle(.5);await Pointer.drag(surface,level.view,1.0,id in ["cross_upper","three_middle","bulkhead"]);await wait_motion()
		check(level.state.placed.has(id),"actual drag installs "+id)
		if id in ["cross_upper","three_middle","three_upper"]:await capture("local-"+id+"-seated")
		if not level.state.completed and level.view.inspected:
			if not level.state.next_in_group().is_empty():await button(level.panel.next_piece_button)
			else:
				await button(level.panel.overview_button)
				check(not level.view.local_context.visible,"local mesh duplicates hidden on overview")
	check(level.state.completed and level.state.placed.size()==10,"unchanged complete hull passes after sea trial")
	await button(level.panel.success_panel.get_child(0).get_child(3));await capture("overview-complete")
	await button(level.panel.bulkhead_button);check(level.bulkhead_lesson.opened,"existing science page remains available")
	await button(level.bulkhead_lesson.close_button);check(not level.bulkhead_lesson.opened and not level.view.local_context.visible,"science return preserves overview and context lifecycle")
	await button(level.panel.restart_button)
	# A same-type wrong cross pocket stays on the frame until the wave; severe wrong
	# type suites cover both alternatives on every target and every animation frame.
	for id in level.Rules.IDS:
		if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):continue
		await prepare(id)
		if id=="cross_upper":
			await button(level.panel.joint_buttons.cross_lap);await button(level.panel.opening_buttons.A)
		await settle(.5);await Pointer.drag(surface,level.view,1.0,false)
		if id=="cross_upper":await verify_cross_motion()
		else:await wait_motion()
		if id=="cross_upper":
			check(not level.state.checked and not level.state.failed and level.state.placed[id].joint=="cross_lap" and level.state.placed[id].opening=="A","same-type wrong pocket retains its supported trial pose")
			await capture("wrong-cross-trial-on-frame")
		if not level.state.failed and level.view.inspected:
			if not level.state.next_in_group().is_empty():await button(level.panel.next_piece_button)
			else:await button(level.panel.overview_button)
	check(level.state.failed and level.panel.failure_restart_button.visible and level.panel.failure_return_button.visible,"mixed wrong trial fails only at end and offers restart/directory")
	await capture("mixed-wrong-final-verdict")
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Actual Viewport mouse/simulated touch through correct and mixed wrong full hulls, ship-connected local context, rotation, zoom, 3 sizes, science return. Not human hardware QA."}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/hull-structure")
	FileAccess.open("res://tests/evidence/hull-structure/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("HULL_STRUCTURE_GUI ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func verify_cross_motion() -> void:
	var probe=load("res://tests/stock_clearance.gd").new()
	var deadline:=Time.get_ticks_msec()+3000
	while level.busy and Time.get_ticks_msec()<deadline:
		check(level.view.pieces.cross_upper.basis.is_equal_approx(Basis.IDENTITY),"half-lap mouths stay aligned through descent")
		probe.sample(level)
		await process_frame
	check(not level.busy and absf(level.view.pieces.cross_upper.position.y-1.31118)<.002,"shallow upper notch bears on lower notch floor")
	check(probe.violations.is_empty(),"independent geometry stays clear through cross approach: "+str(probe.violations.keys()))
	probe.free()
