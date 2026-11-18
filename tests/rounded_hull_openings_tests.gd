extends "res://tests/inspection_workspace_tests.gd"

func capture(name: String) -> void:
	if not gpu:return
	for index in 4:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/three-groups/"+name+".png"
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/three-groups")
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

func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
	check(level.panel.group_buttons.size()==3 and level.Rules.MANUAL_IDS.size()==4,"three groups, with separate side and top strokes for the interlock")
	await capture("01-three-group-overview")
	# All real board variants remain variants; repetition never replaces a bad
	# opening with the right one. The third row has its own actual path check.
	for option in ["A","C","B"]:
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
	var report:={"passed":passed,"failed":failures.size(),"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/rounded-hull")
	var file:=FileAccess.open("res://tests/evidence/rounded-hull/openings.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("CURVED OPENINGS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
