extends "res://tests/view_input_tests.gd"

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.cross-view-20261023/"+label+".png") == OK,"real cross-lap render checkpoint")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	demo = load("res://classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	var original: Dictionary
	for value in JSON.parse_string(FileAccess.get_file_as_string("res://.cross-view-20261023/backup/education/force_gallery/profiles.json")):
		if value.id == "cross_lap": original = value
	for resolution in [Vector2i(1432,920),Vector2i(1440,900),Vector2i(900,1200),Vector2i(640,480)]:
		root.size = resolution
		demo.load_joint(3)
		await physics_frame
		await process_frame
		var camera_before: Transform3D = demo.camera.global_transform
		await click(demo.science_entry.get_global_rect().get_center())
		var p = demo.force_gallery
		var d = p.diagram
		p.set_process(false)
		if resolution == Vector2i(1432,920):
			d.configure(original)
			d.clock.elapsed = 0
			await snapshot("before-cross-lap-1432x920")
			d.configure(p.profiles.cross_lap)
		check(p.opened and p.joint_id == "cross_lap","actual route is two-member cross lap")
		check(d.profile.projection == "high_oblique" and d.profile.iso,"fixed high view with complete OBJ members")
		check(d.profile.modes.size() == 1 and not d.profile.modes[0].removable,"only original downward bearing case")
		check(d.project(Vector3.DOWN,d.profile).is_equal_approx(Vector2(0,.57)),"downward load projects world Y with honest foreshortening")
		check(p.panel.find_children("*","Button",true,false).size() == 1,"only close button")
		for phase in [0.0,1.8,3.4,6.8]:
			d.clock.elapsed = phase
			d.queue_redraw()
			await process_frame
			await snapshot("after-cross-lap-%dx%d-%.1f" % [resolution.x,resolution.y,phase])
			for part in d.profile.parts:
				for vertex in part.vertices:
					var screen: Vector2 = d.project(d.v3(vertex),d.profile)*d.draw_scale+d.draw_origin
					check(root.get_visible_rect().grow(-16).has_point(screen),"both complete crossed members remain in bounds")
		await click(p.close_button.get_global_rect().get_center())
		check(not p.opened and not d.clock.playing,"close stops lesson")
		check(demo.camera.global_transform.is_equal_approx(camera_before),"original 3D camera untouched")
		await orbit_from("lower","original fixed member orbit after lesson")
		check(await capture("upper",16),"original upper-member drag after lesson")
		await mouse(cursor,false)
		await click(demo.science_entry.get_global_rect().get_center())
		check(p.opened and d.clock.playing and d.clock.elapsed < .3,"reopen restarts same high view")
		await click(p.close_button.get_global_rect().get_center())
	demo.free()
	print("CROSS LAP HIGH VIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
