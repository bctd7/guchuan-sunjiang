extends "res://tests/level02_clarity_zoom_tests.gd"
var repeat_samples:=0
func capture(name: String) -> void:
	if not gpu:return
	for i in 3:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/observation-repeat/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/observation-repeat"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU image "+name);images.append(path)
func first_drag(fraction: float,touch:=false) -> void:
	var orbit=level.inspector.orbit
	var start: Vector2=orbit.get_global_transform_with_canvas()*orbit.drag_start_screen()
	var travel: Vector2=orbit.get_global_transform_with_canvas()*orbit.target_screen()-start
	if touch:
		var e:=InputEventScreenTouch.new();e.position=start;e.index=0;e.pressed=true;surface.push_input(e,true);await process_frame
	else:await mouse(start,true)
	for i in range(1,13):
		var point:=start+travel*fraction*float(i)/12
		if touch:
			var e:=InputEventScreenDrag.new();e.position=point;e.relative=travel*fraction/12;e.index=0;surface.push_input(e,true)
		else:
			var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point;e.relative=travel*fraction/12;e.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(e,true)
		await process_frame
	if touch:
		var e:=InputEventScreenTouch.new();e.position=start+travel*fraction;e.index=0;e.pressed=false;surface.push_input(e,true);await process_frame
	else:await mouse(start+travel*fraction,false)
func finish_first() -> void:
	var deadline:=Time.get_ticks_msec()+6000
	while level.busy and Time.get_ticks_msec()<deadline:
		for motion in level.view.animations.values():motion.set_speed_scale(12)
		if is_instance_valid(level.inspector._motion):level.inspector._motion.set_speed_scale(12)
		if level.inspector.opened and not level.inspector.is_animating:
			check(not level.inspector.status.text.contains("未通过") and level.inspector.title.text=="这一处已试装","local review never declares pass/fail early")
			await button(level.inspector.close_button)
		await process_frame
	check(not level.busy,"first chapter manual and repeated motion finishes")
func first_trial(id: String,wrong:=false) -> void:
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons.dovetail if wrong else level.inspector.joint_buttons[level.Rules.expected_joint(id)])
	await button(level.inspector.length_buttons.long if wrong else level.inspector.length_buttons.correct)
	await settle(.5);await first_drag(1.0,id=="bow")
	check(level.state.placed.has(id),"actual first-chapter drag accepts "+id)
	if wrong:
		await settle(.1);await capture("first-wrong-trial-neutral")
		check(not level.state.failed and not level.inspector.status.text.contains("未通过"),"wrong first representative remains unjudged")
	await finish_first()
func second_trial(id: String,mode: String) -> void:
	if level.state.placed.get(id,{}).get("automatic",false):return
	await prepare(id)
	if mode=="wrong_type" and id=="plank_0a":await button(level.panel.joint_buttons.cross_lap);await button(level.panel.opening_buttons.B)
	if mode=="wrong_opening" and id=="plank_0a":await button(level.panel.opening_buttons.A)
	# The aligned fixture exercises the verdict for the former layout variant.
	if mode=="aligned" and id=="plank_1a":level.state.choose_layout("A")
	await settle(.5);await Pointer.drag(surface,level.view,1.0,id=="three_middle");await wait_motion()
	check(level.state.placed.has(id),"manual representative installs "+id)
	if level.Rules.REPEATS.has(id):
		var other: String=level.Rules.REPEATS[id];var a: Dictionary=level.state.placed[id];var b: Dictionary=level.state.placed.get(other,{})
		check(b.get("automatic",false) and b.get("demonstrated_by","")==id and a.joint==b.get("joint") and a.opening==b.get("opening") and a.layout==b.get("layout"),"repeat preserves exact choice, including errors "+id+"/"+mode)
		check(not level.state.checked and not level.state.failed and not level.view.inspected,"repeated pair returns to overview without a verdict")
		if mode=="wrong_type":await capture("second-wrong-pair-"+id)
	else:
		if not level.state.failed and not level.state.completed and level.view.inspected:
			if not level.state.next_in_group().is_empty():await button(level.panel.next_piece_button)
			else:await button(level.panel.overview_button)
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[1]);level=campaign.current_chapter;await button(level.learning.start_button);await button(level.panel.inspect_button)
	var inspector=level.inspector
	await drag_region(inspector.joint_choices.previews.blind_tenon.get_global_rect(),Vector2(55,-15),true)
	check(inspector.selected_joint.is_empty(),"rotating first-chapter candidate does not select")
	await button(inspector.joint_buttons.blind_tenon);await button(inspector.length_buttons.correct)
	await wheel(inspector.stage_surface.get_global_rect().get_center(),true)
	check(inspector.zoom_factor<1 and level.state.progress_count()==0,"first local wheel zoom is observation only")
	await button(inspector.zoom_bar.reset_button);await settle(.5);await first_drag(.25,true)
	var depth: float=inspector.orbit.drag_progress;var pose: Transform3D=inspector.animated_piece.transform
	await button(inspector.length_gallery.inspect_buttons.long)
	check(inspector.magnifier.visible and inspector.selected_length=="correct" and level.state.progress_count()==0,"enlarging another length does not select or install")
	await drag_region(inspector.magnifier.preview.get_global_rect(),Vector2(65,-22),true);await touch_button(inspector.magnifier.zoom_in)
	check(inspector.magnifier.preview.orbit.angles.length()>.02 and inspector.magnifier.preview.zoom_factor<1,"first candidate clone supports touch rotation and visible zoom")
	await capture("first-length-enlarged")
	await button(inspector.magnifier.close_button)
	check(is_equal_approx(inspector.orbit.drag_progress,depth) and inspector.animated_piece.transform.is_equal_approx(pose),"candidate return preserves shallow actual wood")
	for dimensions in [Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2)
		for control in [inspector.zoom_bar.zoom_in,inspector.zoom_bar.zoom_out,inspector.length_gallery.inspect_buttons.long,inspector.joint_choices.inspect_buttons.blind_tenon]:check(surface.get_visible_rect().encloses(control.get_global_rect()) and control.get_global_rect().size.y>=43.9,"first observation controls fit and retain touch height "+str(dimensions))
		await button(inspector.zoom_bar.zoom_in);await capture("first-local-"+str(dimensions.x))
		await button(inspector.joint_choices.inspect_buttons.dovetail);await capture("first-enlarged-"+str(dimensions.x));await button(inspector.magnifier.close_button)
	surface.size=Vector2i(1440,900);await settle(.2);await button(inspector.close_button)
	for id in level.Rules.REPRESENTATIVE_IDS:await first_trial(id,id=="rib_l1")
	check(level.state.failed and level.panel.failure_overlay.visible,"first chapter wrong stock fails only after all automatic groups")
	await capture("first-whole-level-failure");await button(level.panel.failure_restart_button)
	for id in level.Rules.REPRESENTATIVE_IDS:await first_trial(id)
	check(level.state.completed and campaign.completed.get(1,false),"first chapter still completes correctly")
	await button(level.panel.success_panel.return_button)
	await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
	await second_trial("plank_0a","correct");await capture("second-one-operation-two-boards")
	await button(level.panel.undo_button);check(level.state.placed.is_empty() and level.state.selected=="plank_0a","one undo takes back both same-row boards")
	for mode in ["correct","wrong_opening"]:
		for id in level.Rules.MANUAL_IDS:await second_trial(id,mode)
		check(level.state.placed.size()==10 and level.state.placed.values().filter(func(data):return data.get("automatic",false)).size()==6,"four manual strokes retain ten pieces and six repeated records")
		if mode=="correct":
			check(level.state.completed and not level.state.failed,"three-group correct hull passes");await capture("second-repeated-correct-complete")
			await button(level.panel.success_panel.return_button)
			await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
		else:
			check(level.state.failed and not level.state.completed and level.panel.failure_restart_button.visible and level.panel.failure_return_button.visible,"grouped errors wait for whole trial and offer restart/directory "+mode)
			if mode=="wrong_type":check(level.state.mismatched_joints()==["plank_0a","plank_0b"],"wrong representative is never corrected in automatic board")
			if mode=="wrong_opening":check(level.state.mismatched_openings()==level.Rules.GROUPS[0],"wrong opening is retained in automatic board")
			if mode=="aligned":check(not level.state.aligned_rows().is_empty(),"row grouping keeps independent adjacent-row seam decisions")
			await capture("second-grouped-"+mode+"-failure");await button(level.panel.failure_restart_button)
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Actual Viewport mouse/simulated touch: first candidate orbit/magnifier/zoom, neutral wrong review then whole verdict, 3 sizes; second 4 manual/6 repeated pieces, exact wrong propagation, undo, correct/type/opening/aligned full trials. Not physical touchscreen QA."}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/observation-repeat");FileAccess.open("res://tests/evidence/observation-repeat/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("OBSERVATION_REPEAT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
