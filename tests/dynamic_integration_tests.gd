extends "res://tests/view_input_tests.gd"

func named_button(panel: Node,text: String) -> Button:
	for node in panel.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	await process_frame
	var p: CanvasLayer = demo.dynamic_science
	check(demo.science_entry.visible and demo.science_entry.text == "燕尾榫受力演示","explicit dovetail-only entry")
	check(not p.opened and not p.panel.visible,"workshop starts with lesson closed")
	var poses := {}
	for id in demo.assembly.parts: poses[id] = demo.assembly.parts[id].transform
	var camera_before: Transform3D = demo.camera.global_transform
	for cycle in range(3):
		await click(demo.science_entry.get_global_rect().get_center())
		check(p.opened and p.panel.visible,"real entry click opens modal")
		check(demo.interaction.process_mode == Node.PROCESS_MODE_DISABLED and demo.interaction.mode == "idle","modal disables background pointer ownership")
		check(p.diagram.playing and p.diagram.elapsed < .3,"opening starts automatic playback")
		p.diagram.advance(p.diagram.CYCLE * 2.0)
		check(p.diagram.playing and p.diagram.completed_cycles >= 2,"integrated animation continues across cycles")
		check(p.panel.find_children("*","Button",true,false).size() == 1,"dovetail has close only")
		await click(p.diagram.get_global_rect().get_center())
		check(demo.interaction.mode == "idle" and demo.camera.global_transform.is_equal_approx(camera_before),"diagram clicks do not orbit background")
		for id in poses: check(demo.assembly.parts[id].transform.is_equal_approx(poses[id]),"modal leaves original wood poses unchanged")
		if cycle == 0:
			p.diagram.elapsed = 3.2
			p.diagram.queue_redraw()
			await snapshot("workshop-dovetail-force")
		await click(p.close_button.get_global_rect().get_center())
		check(not p.opened and not p.panel.visible,"actual close returns to workshop")
		var stopped_at: float = p.diagram.elapsed
		await create_timer(.08).timeout
		check(not p.diagram.playing and is_equal_approx(stopped_at,p.diagram.elapsed),"closing stops hidden animation")
		check(demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,"close restores original interaction processing")
	# Programmatic model switches must also close the reviewed-only explanation.
	await click(demo.science_entry.get_global_rect().get_center())
	demo.picker.select(6)
	demo.load_joint(6)
	await process_frame
	check(not p.opened and demo.science_entry.visible,"different joint closes dovetail and exposes its own lesson")
	check(demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,"model-switch close restores input")
	for index in range(1,demo.catalog.size()):
		demo.picker.select(index)
		demo.load_joint(index)
		check(demo.science_entry.visible and demo.science_entry.text == str(demo.catalog[index].name)+"受力演示","joint-specific force entry for " + str(demo.catalog[index].id))
	demo.picker.select(0)
	demo.load_joint(0)
	await physics_frame
	check(demo.science_entry.visible,"returning to dovetail restores correct entry")
	await click(demo.science_entry.get_global_rect().get_center())
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await process_frame
	check(not p.opened,"actual Escape returns from integrated lesson")
	check(demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,"Escape restores background input")
	check(await capture("tail",16),"original wood capture works after lesson return")
	await move_to("tail",.43)
	await parked("tail","post-modal pause")
	if await grab("tail"): await move_to("tail",1.03,false)
	await mouse(cursor,false)
	check(demo.assembly.states.tail == "locked","original manual completion remains permanently locked")
	await orbit_from("tail","post-modal locked orbit")
	await snapshot("workshop-after-force-return")
	demo.free()
	print("DYNAMIC WORKSHOP INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
