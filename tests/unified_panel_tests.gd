extends "res://tests/view_input_tests.gd"

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.unified-panel-20261023/"+label+".png") == OK,"actual unified-panel screenshot")

func use_control(control: Control) -> void:
	demo.workshop_panel.scroll.ensure_control_visible(control)
	await process_frame
	await process_frame
	await click(control.get_global_rect().get_center())

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://components/teaching/classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	await process_frame
	for id in ["advanced","align","insert","remove"]: check(not demo.buttons.has(id),"removed auxiliary action "+id)
	check(demo.get_node("WorkshopUI").get_child_count() == 1,"one sidebar; no independent bottom/legacy panel")
	check(demo.find_children("*","ItemList",true,false).is_empty(),"no part-selection entry/list retained")
	# Scroll hit-testing is verified below with the real renderer. Dummy display
	# runs retain structural/routing/framing coverage without claiming GUI clicks.
	if DisplayServer.get_name() == "headless":
		for resolution in [Vector2i(1440,900),Vector2i(640,480),Vector2i(900,1200),Vector2i(1920,800)]:
			root.size = resolution
			await process_frame
			await process_frame
			check(root.get_visible_rect().encloses(demo.workshop_panel.get_global_rect()),"headless panel bounds")
			for index in demo.catalog.size():
				demo.picker.select(index)
				demo.picker.item_selected.emit(index)
				await physics_frame
				check(demo.assembly.definition.id == demo.catalog[index].id,"headless selector routing")
				check_frame("headless free model area")
				demo._open_education()
				var p = demo.dynamic_science if index == 0 else demo.force_gallery
				check(p.opened,"headless education routing")
				p.close()
				check(demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,"headless input restoration")
		demo.free()
		print("UNIFIED PANEL STRUCTURE (headless, no GUI-click claim): %d passed, %d failed" % [passed,failed])
		quit(0 if failed == 0 else 1)
		return
	for resolution in [Vector2i(1440,900),Vector2i(640,480),Vector2i(900,1200),Vector2i(1920,800)]:
		root.size = resolution
		await process_frame
		await process_frame
		var panel: Control = demo.workshop_panel
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"sidebar fits "+str(resolution))
		if resolution == Vector2i(640,480):
			check(panel.scroll != null,"short window retains scrolling support if needed")
		for index in demo.catalog.size():
			demo.picker.select(index)
			demo.picker.item_selected.emit(index)
			await physics_frame
			await process_frame
			check(demo.assembly.definition.id == demo.catalog[index].id,"real selector signal switches all nine")
			check_frame("unified "+str(resolution)+" "+str(demo.catalog[index].id))
			await use_control(demo.science_entry)
			var p = demo.dynamic_science if index == 0 else demo.force_gallery
			check(p.opened,"left education entry opens correct lesson")
			await click(p.close_button.get_global_rect().get_center())
			check(demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,"close restores model input")
			var fixed_id := str(demo.assembly.definition.parts[0].id)
			await orbit_from(fixed_id,"post-modal "+str(demo.catalog[index].id))
			demo.load_joint(index)
			await physics_frame
			if index == 0:
				await snapshot("workshop-%dx%d" % [resolution.x,resolution.y])
		# All surviving controls are actually clicked through the real Viewport.
		demo.load_joint(0)
		await physics_frame
		check(demo.assembly.has_method("rotate_part"),"core rotation API retained")
		for key in demo.buttons: check(not str(key).begins_with("rotate_"),"no XYZ buttons remain")
		await use_control(demo.buttons.xray)
		check(demo.assembly.xray,"left transparency enables")
		await use_control(demo.buttons.xray)
		check(not demo.assembly.xray,"left transparency disables")
		demo.interaction.yaw = -.2
		demo.interaction.update_camera()
		await use_control(demo.buttons.view)
		check(is_equal_approx(demo.interaction.yaw,.68),"left view reset works")
		check_frame("left view reset "+str(resolution))
		check(await capture("tail",16),"direct drag calibrates without part/auxiliary UI")
		await move_to("tail",.43)
		await parked("tail","unified panel pause")
		if await grab("tail"): await move_to("tail",1.03,false)
		var before_release: float = demo.interaction.distance
		await mouse(cursor,false)
		check(demo.assembly.states.tail == "locked" and not demo.assembly.can_remove("tail"),"permanent completion lock retained")
		check(demo.interaction.distance >= before_release-.00001,"completion never pulls camera closer")
		check_frame("unified completed "+str(resolution))
		await snapshot("completed-%dx%d" % [resolution.x,resolution.y])
		await use_control(demo.buttons.reset)
		check(demo.assembly.states.tail == "free","left restart works")
		# A scroll over the panel must not change the model camera distance.
		var distance: float = demo.interaction.distance
		var wheel := InputEventMouseButton.new()
		wheel.position = panel.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await process_frame
		check(is_equal_approx(distance,demo.interaction.distance),"sidebar scrolling never zooms model")
	demo.free()
	print("UNIFIED LEFT PANEL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
