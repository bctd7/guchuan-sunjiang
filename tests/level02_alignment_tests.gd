extends "res://tests/level02_clarity_zoom_tests.gd"
## Reproduce the user's wrong cross-lap at the bottom-row tail, then correct stock.
func capture(name: String) -> void:
	if not gpu:return
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/alignment/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/alignment"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU image "+name);images.append(path)
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
	await Navigation.open_local(surface,level,"plank_0a")
	await button(level.panel.joint_buttons.tongue_groove);await button(level.panel.opening_buttons.B)
	await capture("plank-context-100")
	for i in 5:await button(level.panel.zoom_in_button)
	check(level.view.framing.zoom_factor<.41 and level.view.framing.zoom_factor>.39,"reproduce approximately 249 percent zoom")
	check(level.view.pick_drag_piece(level.view.drag_grab_screen())=="plank_0a","real plank stock remains pickable when enlarged")
	await capture("plank-context-249")
	await settle(.5);await Pointer.drag(surface,level.view,.24,true)
	check(level.view.preview_progress>.15 and level.state.placed.is_empty(),"touch shallow approach at enlarged scale does not install")
	await Pointer.drag(surface,level.view,-.24,true)
	check(level.state.placed.is_empty() and not level.state.failed and level.view.framing.zoom_factor<.41,"withdraw retains current observation scale")
	await button(level.panel.zoom_reset_button)
	await prepare("plank_0a");await capture("correct-tongue-facing-receiver")
	await settle(.5);await Pointer.drag(surface,level.view,1.0,false);await wait_motion()
	check(level.state.placed.has("plank_0a") and level.state.mismatched_joints().is_empty(),"correct original stock still seats normally")
	await Navigation.open_local(surface,level,level.state.next_id())
	var saved: Dictionary=level.state.placed.duplicate(true)
	for kind in ["cross_lap","three_way_lap"]:
		await button(level.panel.gallery.inspect_buttons[kind]);await capture("type-"+kind+"-exploded")
		var demo=level.panel.magnifier.demonstration
		check(demo.visible and demo.parts.size()==(2 if kind=="cross_lap" else 3),"type explanation uses two versus three real component meshes")
		await button(demo.part_buttons.UpperStock)
		check(demo.parts.UpperStock.visible and not demo.parts.LowerStock.visible,"upper pocket can be observed without other stock occlusion")
		await capture("type-"+kind+"-upper-pocket")
		if kind=="three_way_lap":
			await button(demo.part_buttons.MiddleStock);await capture("three-middle-top-pocket");await button(demo.flip_button);await capture("three-middle-bottom-pocket")
		var phases: Array[String]=[];demo.phase_changed.connect(func(part: String):phases.append(part),CONNECT_ONE_SHOT if kind=="cross_lap" else 0)
		await button(demo.play_button)
		var deadline:=Time.get_ticks_msec()+3000
		while is_instance_valid(demo.motion) and demo.motion.is_running() and Time.get_ticks_msec()<deadline:await process_frame
		check(phases==(["UpperStock"] if kind=="cross_lap" else ["MiddleStock","UpperStock"]),"actual copy demonstrates one-step cross-lap versus sequential three-member engagement")
		check(demo.parts.values().all(func(node):return node.position.is_zero_approx()),"demonstration closes real parts to their assembled transforms")
		await capture("type-"+kind+"-closed");await button(demo.split_button)
		check(demo.parts.UpperStock.position.y>0 and level.state.placed==saved,"split restores only display copy without installing or changing progress")
		await button(level.panel.magnifier.close_button)
	for dimensions in [Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2);await capture("aligned-local-"+str(dimensions.x))
		check(surface.get_visible_rect().encloses(level.panel.zoom_in_button.get_global_rect()),"zoom stays reachable "+str(dimensions))
		await button(level.panel.gallery.inspect_buttons.three_way_lap)
		var demo=level.panel.magnifier.demonstration
		check(demo.visible and surface.get_visible_rect().encloses(demo.play_button.get_global_rect()) and demo.play_button.get_global_rect().size.y>=43.9,"geometry explanation controls fit and remain touchable "+str(dimensions))
		await button(demo.part_buttons.UpperStock);await capture("three-upper-pocket-"+str(dimensions.x));await button(level.panel.magnifier.close_button)
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Actual Viewport mouse and simulated touch; first plank 249 percent touch approach and withdrawal, correct stock, three-size framing and distinct type models."}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/alignment")
	FileAccess.open("res://tests/evidence/alignment/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("ALIGNMENT_GUI ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
