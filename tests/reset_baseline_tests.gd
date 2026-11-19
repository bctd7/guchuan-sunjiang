extends "res://tests/view_input_tests.gd"
var measured: Array = []

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.reset-baseline-20261023/"+label+".png") == OK,"save actual reset baseline frame")

func press_reset() -> void:
	await click(demo.buttons.view.get_global_rect().get_center())

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://components/teaching/classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	await process_frame
	check(not demo.workshop_panel.has_signal("rotation_requested"),"no UI rotation signal remains")
	for key in demo.buttons: check(not str(key).begins_with("rotate_"),"no XYZ button remains")
	check(demo.assembly.has_method("rotate_part"),"core rotation capability remains")
	for resolution in [Vector2i(1440,900),Vector2i(640,480),Vector2i(900,1200),Vector2i(1920,800)]:
		root.size = resolution
		await process_frame
		await process_frame
		for index in demo.catalog.size():
			demo.picker.select(index)
			demo.load_joint(index)
			await physics_frame
			await process_frame
			await press_reset()
			var id := str(demo.catalog[index].id)
			var entering: float = demo.interaction.distance
			var original_poses := {}
			for part_id in demo.assembly.parts: original_poses[part_id] = demo.assembly.parts[part_id].transform
			demo.interaction.distance = entering*.45
			demo.interaction.yaw = -.5
			demo.interaction.pitch = .8
			demo.interaction.update_camera()
			await press_reset()
			check(is_equal_approx(demo.interaction.distance,entering),id+": entry reset restores baseline after manual zoom")
			check(is_equal_approx(demo.interaction.yaw,.68) and is_equal_approx(demo.interaction.pitch,.42),id+": default angle restored")
			check_frame(id+" entry reset "+str(resolution))
			if index in [0,5,6]: await snapshot("%s-entry-%dx%d" % [id,resolution.x,resolution.y])
			for part_id in original_poses: check(demo.assembly.parts[part_id].transform == original_poses[part_id],"view reset never moves actual free parts")
			# Isolated completed-pose fixture; full real drag completion is checked
			# separately by view_input_tests.gd, not claimed by this fixture.
			for part_id in demo.assembly.parts:
				demo.assembly.parts[part_id].transform = demo.assembly.assembled_pose(part_id)
				demo.assembly.states[part_id] = "locked"
			demo.assembly.hide_ghost()
			demo.assembly.changed.emit()
			demo.interaction._connection_finished("")
			demo.interaction.release()
			check(demo.interaction.distance >= entering-.00001,id+": automatic completion remains no-closer")
			demo.interaction.distance *= .45 if index%2 == 0 else 1.6
			demo.interaction.update_camera()
			await press_reset()
			var reset: float = demo.interaction.distance
			check(is_equal_approx(reset,entering),id+": completed reset uses same entry distance, not smaller assembled bounds")
			check(camera_projection_ok(),"perspective FOV retained")
			for part_id in demo.assembly.parts:
				check(demo.assembly.states[part_id] == "locked" and demo.assembly.parts[part_id].transform.is_equal_approx(demo.assembly.assembled_pose(part_id)),"camera reset preserves completed locks and exact poses")
			check_frame(id+" completed reset "+str(resolution))
			if index in [0,5,6]: await snapshot("%s-completed-reset-%dx%d" % [id,resolution.x,resolution.y])
			measured.append({"id":id,"viewport":[resolution.x,resolution.y],"entry":entering,"completed_reset":reset})
	# Reset a paused real drag without changing its safe progress or pose.
	demo.load_joint(0)
	await physics_frame
	check(await capture("tail",16),"direct capture after UI removal")
	await move_to("tail",.43)
	await parked("tail","baseline reset pause")
	var pose: Transform3D = demo.assembly.parts.tail.transform
	await press_reset()
	check(demo.assembly.is_guided("tail") and demo.assembly.parts.tail.transform.is_equal_approx(pose),"view reset preserves a paused guided part")
	if await grab("tail"): await move_to("tail",1.03,false)
	await mouse(cursor,false)
	check(demo.assembly.states.tail == "locked","drag resumes and locks after view reset")
	var file := FileAccess.open("res://.reset-baseline-20261023/distances.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measured,"  "))
	demo.free()
	print("ENTRY BASELINE RESET: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)

func camera_projection_ok() -> bool:
	return demo.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(demo.camera.fov,42.0)
