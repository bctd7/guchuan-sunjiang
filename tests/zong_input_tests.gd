extends "res://tests/drag_input_tests.gd"

func run() -> void:
	root.size = Vector2i(1440,900)
	demo = load("res://classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	demo.picker.select(6)
	demo.load_joint(6)
	await physics_frame
	check(demo.assembly.definition.id == "zong_corner","real refined catalog entry")
	check(demo.assembly.specs.xrail.fixed and not demo.assembly.specs.leg.fixed,"rail frame first, leg last")
	check(demo.assembly.candidate("leg").reason == "dependency","cannot install leg before cross rail")
	check(not demo.assembly.begin_manual("leg"),"dependency rejection does not bypass motion guard")
	await snapshot("zong-refined-entry")
	for id in ["zrail","leg"]:
		check(await capture(id,16),"real pointer calibrates " + id)
		print("ZONG_CAPTURE ",id," state=",demo.assembly.states[id]," progress=",demo.assembly.progress.get(id,-1)," cursor=",cursor," last=",demo.interaction.last_screen)
		await move_to(id,.43)
		print("ZONG_PARTIAL ",id," state=",demo.assembly.states[id]," progress=",demo.assembly.progress.get(id,-1)," mode=",demo.interaction.mode)
		await parked(id,"refined " + id + " pause")
		if await grab(id):
			await move_to(id,-.02)
			await mouse(cursor,false)
		check(demo.assembly.states[id] == "free","unfinished refined piece withdraws " + id)
		if not await capture(id,1): await motion(cursor + Vector2(6,0),Vector2(6,0))
		if demo.assembly.is_guided(id): await move_to(id,1.03,false)
		await mouse(cursor,false)
		check(demo.assembly.states[id] == "locked","refined piece permanently locked " + id)
		check(not demo.assembly.remove_part(id),"cannot remove completed refined member " + id)
		await snapshot("zong-refined-" + id + "-locked")
	check(demo.assembly.states.leg == "locked" and demo.assembly.states.zrail == "locked","complete refined connection")
	demo.free()
	print("REFINED ZONG INPUT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
