extends "res://tests/view_input_tests.gd"

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.zong-cutaway-20261023/"+label+".png") == OK,"save real zong transition frame")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	demo = load("res://demo/workshop.tscn").instantiate()
	root.add_child(demo)
	for resolution in [Vector2i(1497,930),Vector2i(1440,900),Vector2i(900,1200),Vector2i(640,480)]:
		root.size = resolution
		demo.load_joint(6)
		await physics_frame
		await process_frame
		await click(demo.science_entry.get_global_rect().get_center())
		var p = demo.force_gallery
		p.set_process(false)
		var d = p.diagram
		check(p.opened and p.panel.find_children("*","Button",true,false).size() == 1,"same host scene, close only")
		var camera_before: Transform3D = demo.camera.global_transform
		d._fit(d.view_data())
		var origin: Vector2 = d.draw_origin
		var scale: float = d.draw_scale
		for turn in range(8):
			for phase in [0.0,.45,.9,1.55,2.4,3.4,4.45,4.95,5.55,5.99]:
				d.clock.cycles = turn
				d.clock.elapsed = phase
				d.queue_redraw()
				await process_frame
				d._fit(d.view_data())
				check(d.draw_origin.is_equal_approx(origin) and is_equal_approx(d.draw_scale,scale),"continuous whole/cut view uses same projection and framing")
				check(d.cutaway_alpha() >= 0 and d.cutaway_alpha() <= 1,"bounded shell opacity")
				if turn < 2: await snapshot("zong-load%d-t%.2f-%dx%d" % [turn,phase,resolution.x,resolution.y])
			# A whole cycle boundary has no pose, force, opacity or camera jump.
			d.clock.elapsed = d.clock.DURATION-.001
			var before: Vector3 = d.displacement()
			var alpha: float = d.cutaway_alpha()
			d.advance(.002)
			check(before.distance_to(d.displacement()) < .00001 and absf(alpha-d.cutaway_alpha()) < .00001,"seamless load/cycle boundary")
		for turn in [0,1]:
			d.clock.cycles = turn
			for edge in [.45,1.55,4.45,5.55]:
				d.clock.elapsed = edge-.0001
				var a: float = d.cutaway_alpha()
				d.clock.elapsed = edge+.0001
				check(absf(a-d.cutaway_alpha()) < .00001,"smooth shell fade endpoint")
		check(demo.camera.global_transform.is_equal_approx(camera_before),"host 3D camera never changes")
		await click(p.close_button.get_global_rect().get_center())
		var elapsed: float = d.clock.elapsed
		d.advance(20)
		check(not p.opened and elapsed == d.clock.elapsed,"close stops shell/force clock")
		await click(demo.science_entry.get_global_rect().get_center())
		check(d.mode == 0 and d.cutaway_alpha() == 0 and d.clock.playing,"reopen begins whole assembly")
		await click(p.close_button.get_global_rect().get_center())
		await orbit_from("xrail","original orbit after cutaway")
		if resolution == Vector2i(1440,900):
			check(await capture("zrail",16),"original rail drag after cutaway")
			await mouse(cursor,false)
	demo.free()
	print("ZONG WHOLE/CUT TRANSITION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
