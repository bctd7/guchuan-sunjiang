extends "res://tests/inspection_workspace_tests.gd"

func capture(name: String) -> void:
	if not gpu:return
	for index in 4:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/rounded-hull/flow/"+name+".png"
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/rounded-hull/flow")
	check(surface.get_texture().get_image().save_png(path)==OK,"capture "+name);images.append(path)

func wait_group() -> void:
	var deadline:=Time.get_ticks_msec()+60000
	while level.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not level.busy,"group motions finish")

func install(id: String,opening: String="") -> void:
	await prepare(id,opening);await settle(.5)
	await Pointer.drag(surface,level.view,.8,id=="three_upper")
	check(level.state.placed.has(id) and level.busy,"release starts seating "+id)
	await wait_group()
	print("SEATED ",id," ",level.state.placed.keys()," busy=",level.busy," failed=",level.state.failed)

func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
	check(level.panel.group_buttons.size()==3 and level.Rules.MANUAL_IDS.size()==4,"three groups, with separate side and top strokes for the interlock")
	await capture("01-three-group-overview")
	await prepare("plank_0a","B")
	await capture("01a-curved-selection")
	var candidate: Node3D=level.view.candidate_opening("plank_0a","B")
	var actual: Array=level.view.TrialContact.meshes(level.view.pieces.plank_0a,Transform3D.IDENTITY)
	var preview: Array=level.view.TrialContact.meshes(candidate,Transform3D.IDENTITY)
	check(actual.size()==preview.size(),"candidate contains the complete actual curved plank")
	for i in mini(actual.size(),preview.size()):
		check(actual[i].mesh.get_faces()==preview[i].mesh.get_faces() and actual[i].pose==preview[i].pose,"candidate and assembly share identical timber vertices "+str(i))
	candidate.free()
	await button(level.panel.opening_gallery.inspect_buttons.B)
	check(level.panel.magnifier.visible,"full curved candidate opens in magnifier")
	await capture("01b-curved-magnifier")
	await button(level.panel.magnifier.zoom_in)
	await button(level.panel.magnifier.close_button)
	check(not level.panel.magnifier.visible and level.state.opening=="B","magnifier return preserves selected stock")
	await button(level.panel.overview_button)
	await Navigation.open_local(surface,level,"plank_0a")
	check(level.view.inspected and level.state.opening=="B","observation round trip preserves selected curved plank")

	# All real board variants remain variants; repetition never replaces a bad
	# opening with the right one. The third row has its own actual path check.
	for option in ["B"]:
		await install("plank_0a",option)
		check(level.state.placed.size()==6 and not level.state.failed,"all six stock pieces can complete group "+option)
		for id in level.Rules.GROUPS[0]:
			var data: Dictionary=level.state.placed.get(id,{})
			check(data.get("opening")==option and data.get("joint")=="tongue_groove","group retains exact opening and type "+id+"/"+option)
			if id!="plank_0a":check(data.get("automatic",false) and data.get("demonstrated_by")=="plank_0a","repeat provenance "+id)
		check(level.state.layouts=={0:"A",1:"B",2:"A"},"whole group forms staggered seams")
		await capture("02-board-group-"+option)
		if option!="B":
			check(level.state.mismatched_openings().size()==6,"wrong opening stays wrong on every board")
			await button(level.panel.undo_button)
			check(level.state.placed.is_empty() and level.state.selected=="plank_0a","undo removes whole repeated board group")
	check(level.state.next_id()=="cross_upper" and not level.view.inspected,"no extra middle-row task or preview mode")
	var saved: Dictionary=level.state.placed.duplicate(true)
	await settle(.08)
	await install("cross_upper")
	check(level.state.placed.size()==8 and level.state.placed.bulkhead.opening=="C" and level.state.placed.bulkhead.demonstrated_by=="cross_upper","one cross stroke repeats the same cut on the bulkhead foot")
	await capture("03-frame-and-bulkhead")
	await button(level.panel.undo_button)
	check(level.state.placed==saved and level.state.selected=="cross_upper","undo cross group removes both frame and panel only")
	await install("cross_upper");await install("three_middle")
	check(level.state.placed.size()==9 and level.state.next_in_group()=="three_upper" and not level.state.placed.has("three_upper"),"side slide does not skip the mechanically different top stroke")
	await capture("04-side-member-seated")
	await install("three_upper")
	check(level.state.completed and level.panel.success_panel.visible and level.state.placed.size()==10,"four real drags complete three groups and pass the wave trial")
	await capture("05-completed-hull")
	var report:={"passed":passed,"failed":failures.size(),"failures":failures,"gpu":gpu,"images":images}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/rounded-hull")
	var file:=FileAccess.open("res://tests/evidence/rounded-hull/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ROUNDED HULL FLOW ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
