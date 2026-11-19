extends "res://tests/inspection_workspace_tests.gd"

func capture(name: String) -> void:
	if not gpu:return
	for index in 4:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/three-groups/"+name+".png"
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/three-groups")
	check(surface.get_texture().get_image().save_png(path)==OK,"capture "+name);images.append(path)

func wait_group() -> void:
	var deadline:=Time.get_ticks_msec()+12000
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
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
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
	var saved: Dictionary=level.state.placed.duplicate(true)
	await settle(.08)
	await button(campaign.back_button);await button(campaign.chapter_buttons[2]);await button(level.learning.start_button)
	check(level.state.placed==saved,"directory return retains the six real installation records")
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
	await button(level.panel.success_panel.get_child(0).get_child(3));await button(level.panel.restart_button)
	for choices in [["A","B"],["B","A"]]:
		await install("plank_0a",choices[0]);await install("cross_upper",choices[1])
		check(level.state.placed.bulkhead.opening==choices[1] and not level.state.failed,"loose repeated frame never silently substitutes its panel opening")
		await install("three_middle");await install("three_upper")
		check(level.state.failed and not level.state.completed and level.state.placed.size()==10 and level.state.checked,"seatable wrong opening reaches the real whole-hull wave verdict")
		await capture("wrong-openings-"+choices[0]+"-"+choices[1])
		await button(level.panel.failure_restart_button)
	# Restart in the middle of a multi-piece repeat: no stale callback can
	# install the remaining automatic pieces into the new run.
	await prepare("plank_0a");await settle(.5);await Pointer.drag(surface,level.view,.8)
	var deadline:=Time.get_ticks_msec()+4500
	while not level.view.animations.has("plank_1a") and Time.get_ticks_msec()<deadline:await process_frame
	check(level.view.animations.has("plank_1a") and level.busy,"automatic second row has its own seating motion")
	await button(level.panel.restart_button);await settle(1.0)
	check(level.state.placed.is_empty() and not level.busy and level.view.animations.is_empty(),"restart cancels every remaining repeated member")
	# A new, real obstruction only in the second board's path must prevent
	# automatic completion. This does not mock the geometry/path return value.
	await prepare("plank_0a");await settle(.5);await Pointer.drag(surface,level.view,.8)
	var wall:=Node3D.new();level.view.add_child(wall)
	level.view.G.box(wall,Vector3(3,3,3),Vector3(2,1,1.2),level.view.wood)
	level.view.fixed["test_obstruction"]=wall
	await wait_group()
	check(level.state.failed and level.state.placed.size()==1 and level.state.failure_result().piece_id=="plank_0b","impossible automatic path stops the group at the real obstruction")
	check(level.panel.failure_overlay.visible and level.view.inspected,"blocked automatic member remains visible with the failure dialog")
	level.view.fixed.erase("test_obstruction");wall.free()
	await button(level.panel.failure_restart_button)
	# First wrong family still finishes locally before error, and never repeats.
	await prepare("plank_0a");await button(level.panel.joint_buttons.cross_lap);await button(level.panel.opening_buttons.B);await settle(.5)
	await Pointer.drag(surface,level.view,.8);check(not level.state.failed,"wrong family waits for actual final seating")
	await wait_group()
	check(level.state.failed and level.state.placed.size()==1 and level.panel.failure_overlay.title.text=="拼装错误","complete wrong first family stops before automatic group")
	await capture("06-wrong-family-local-error")
	if gpu:check(not root.has_focus(),"GPU fixture keeps user focus")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Real Viewport buttons and mouse/touch drags; three-group repeat, exact wrong choices, undo, reentry, cancellation and full wave trial"}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/three-groups")
	FileAccess.open("res://tests/evidence/three-groups/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("THREE_GROUPS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
