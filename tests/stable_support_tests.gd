extends "res://tests/view_input_tests.gd"

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.stable-support-20261023/"+label+".png") == OK,"save actual fixed-support checkpoint")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var metadata := {}
	for index in demo.catalog.size():
		demo.load_joint(index)
		await process_frame
		await click(demo.science_entry.get_global_rect().get_center())
		var id := str(demo.catalog[index].id)
		var p = demo.dynamic_science if id == "dovetail" else demo.force_gallery
		p.set_process(false)
		var d = p.diagram
		if id == "dovetail":
			var base: PackedVector2Array = d.base_polygon()
			var low := INF
			var high := -INF
			for step in range(361):
				d.elapsed = step/60.0
				check(d.base_polygon() == base,"dovetail base vertices fixed for whole cycle")
				check(d.displacement() >= 0 and d.displacement() <= d.STOP+.00001,"loaded member stays within safe contact range")
				low = minf(low,d.displacement()); high = maxf(high,d.displacement())
			check(high-low > 10,"loaded upper member still visibly animates")
			for phase in [0.0,.8,1.4,2.8,4.3,5.4,5.99]:
				d.elapsed = phase
				d.queue_redraw()
				await process_frame
				await snapshot("dovetail-t%.2f" % phase)
			var s: float = minf(1.0,minf(d.size.x/960.0,d.size.y/480.0)*.86)
			var origin: Vector2 = (d.size-Vector2(960,480)*s)/2+d.global_position
			metadata[id] = {"scale":s,"origin":[origin.x,origin.y]}
		else:
			d._fit(d.view_data())
			var origin: Vector2 = d.draw_origin
			var scale: float = d.draw_scale
			var supports: PackedVector2Array = d.support_points()
			var screen_supports := []
			for point in supports:
				var screen: Vector2 = d.global_position+origin+point*scale
				screen_supports.append([screen.x,screen.y])
			metadata[id] = {"supports":screen_supports}
			var moving := {}
			for load_case in d.profile.modes:
				for part_id in load_case.moving: moving[part_id] = true
			for cycle in range(d.profile.modes.size()*2):
				for step in range(61):
					d.clock.cycles = cycle
					d.clock.elapsed = step/10.0
					d._fit(d.view_data())
					check(d.draw_origin == origin and is_equal_approx(d.draw_scale,scale),id+": fixed picture transform")
					check(d.support_points() == supports,id+": all ground marks constant across cases and fades")
					var load_case: Dictionary = d.profile.modes[d.mode]
					var amount: float = d.load_clock().fraction(false)
					check(amount >= 0 and amount <= 1,id+": loaded motion cannot penetrate or pull apart")
					for part in d.profile.parts:
						if part.id not in load_case.moving:
							check(d.part_offset(part.id,d.displacement()) == Vector3.ZERO,id+": renderer holds support at zero displacement")
						else: check(d.part_offset(part.id,d.displacement()).is_equal_approx(d.displacement()),id+": actual loaded part retains safe feedback")
					if step in [0,8,14,28,43,54] and cycle < d.profile.modes.size():
						d.queue_redraw()
						await process_frame
						await snapshot("%s-load%d-t%.2f" % [id,cycle,step/10.0])
			check(d.profile.modes[0].distance > 0,id+": loaded member animation retained")
		await click(p.close_button.get_global_rect().get_center())
		var stopped_at: float = d.elapsed if id == "dovetail" else d.clock.elapsed
		d.advance(30)
		check(not p.opened and is_equal_approx(stopped_at,d.elapsed if id == "dovetail" else d.clock.elapsed),id+": close stops advancement")
		await click(demo.science_entry.get_global_rect().get_center())
		check(p.opened and (d.playing if id == "dovetail" else d.clock.playing),id+": reopen keeps active animation")
		await click(p.close_button.get_global_rect().get_center())
	var file := FileAccess.open("res://.stable-support-20261023/pixel-probes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	demo.free()
	print("STABLE SUPPORT / ACTIVE LOAD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
