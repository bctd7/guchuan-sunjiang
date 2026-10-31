extends "res://tests/view_input_tests.gd"
## Host input and actual engine-rendered frames; no claim of human mouse testing.
var graphical := DisplayServer.get_name() != "headless"


# Reference zong renders two loads inside one 13.2 s cycle; its inherited
# cycles-based `mode` property is not the load used by the renderer.
func displayed_mode(diagram) -> int:
	return diagram.clock.mode_index() if diagram.reference_active else diagram.mode

func snapshot(label: String) -> void:
	if not graphical: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.force-local-20261023/"+label+".png") == OK,"save real rendered checkpoint")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	var gallery = demo.force_gallery
	check(gallery.profiles.size() == 8,"exactly eight additional local profiles")
	for resolution in [Vector2i(1440,900),Vector2i(900,1200),Vector2i(1920,800),Vector2i(640,480)]:
		root.size = resolution
		await process_frame
		for index in demo.catalog.size():
			demo.picker.select(index)
			demo.load_joint(index)
			await physics_frame
			await process_frame
			var id := str(demo.catalog[index].id)
			var camera_before: Transform3D = demo.camera.global_transform
			var poses := {}
			for part_id in demo.assembly.parts: poses[part_id] = demo.assembly.parts[part_id].transform
			await click(demo.science_entry.get_global_rect().get_center())
			var presenter = demo.dynamic_science if id == "dovetail" else gallery
			check(presenter.opened and presenter.panel.visible,id+": real button opens routed lesson")
			check(presenter.panel.find_children("*","Button",true,false).size() == 1,id+": close is the only button")
			check(demo.interaction.process_mode == Node.PROCESS_MODE_DISABLED,id+": background input suspended")
			if id != "dovetail":
				check(gallery.joint_id == id,id+": correct profile")
				var diagram = gallery.diagram
				var count: int = diagram.profile.modes.size()
				for mode_index in count:
					diagram.clock.cycles = mode_index
					diagram.clock.elapsed = diagram.clock.LEAD + diagram.clock.STAGE*mode_index if diagram.reference_active else 0.0
					check(displayed_mode(diagram) == mode_index,id+": mode routing")
					check(diagram.clock.playing,id+": auto plays")
					diagram.advance(diagram.clock.DURATION*count*3.0)
					check(diagram.clock.playing and diagram.clock.cycles >= 3,id+": continuous cycles")
					var m: Dictionary = diagram.profile.modes[mode_index]
					check(not m.removable,id+": no removal case in retained data")
					for phase in [.0,.8,1.4,3.4,4.4,5.95]:
						diagram.clock.elapsed = diagram.clock.LEAD + diagram.clock.STAGE*mode_index + minf(phase, diagram.clock.STAGE-.001) if diagram.reference_active else phase
						diagram.clock.playing = false
						diagram.queue_redraw()
						check(not diagram.clock.touching(m.removable) if m.removable else true,id+": no false removal reaction")
						if phase == 3.4:
							await snapshot("%s-mode%d-%dx%d" % [id,mode_index,resolution.x,resolution.y])
						else: await process_frame
						check(diagram.draw_scale > 0 and diagram.draw_scale < INF,id+": finite framing")
					# Real contact / paths in exact extracted section, not idealized boxes.
					if not diagram.view_data().iso and not m.removable:
						var fixed: Array = []
						var moving: Array = []
						for part in diagram.view_data().parts:
							for ring in diagram.rings(part,diagram.view_data()):
								if part.id in m.moving: moving.append(ring)
								else: fixed.append(ring)
						for path in m.paths:
							for segment in range(path.size()-1):
								for sample in range(21):
									var point: Vector2 = diagram.project(diagram.v3(path[segment]).lerp(diagram.v3(path[segment+1]),float(sample)/20),diagram.view_data())
									var inside := false
									for ring in fixed:
										if Geometry2D.is_point_in_polygon(point,ring): inside = true
										for edge in ring.size():
											if point.distance_to(Geometry2D.get_closest_point_to_segment(point,ring[edge],ring[(edge+1)%ring.size()])) < .012: inside = true
									check(inside,id+": load path within fixed solid")
						for contact in m.contacts:
							var point: Vector2 = diagram.project(diagram.v3(contact),diagram.view_data())
							var closest := INF
							for ring in moving:
								var shift: Vector2 = diagram.project(diagram.v3(m.initial)+diagram.v3(m.direction)*float(m.distance),diagram.view_data())
								for edge in ring.size(): closest = minf(closest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,ring[edge]+shift,ring[(edge+1)%ring.size()]+shift)))
							check(closest < .012,id+": highlighted contact reaches actual moving boundary")
					diagram.clock.elapsed = (diagram.clock.LEAD + diagram.clock.STAGE if diagram.reference_active and mode_index == 0 else diagram.clock.DURATION)-.001
					diagram.clock.playing = true
					diagram.advance(.002)
					check(displayed_mode(diagram) == (mode_index+1)%count,id+": automatic next load at smooth loop boundary")
				check(displayed_mode(diagram) == 0,id+": modes wrap")
			await click(presenter.close_button.get_global_rect().get_center())
			check(not presenter.opened and demo.interaction.process_mode == Node.PROCESS_MODE_INHERIT,id+": close restores input")
			if id != "dovetail":
				var elapsed: float = gallery.diagram.clock.elapsed
				await create_timer(.03).timeout
				check(not gallery.diagram.clock.playing and is_equal_approx(elapsed,gallery.diagram.clock.elapsed),id+": closed clock stops")
			check(demo.camera.global_transform.is_equal_approx(camera_before),id+": modal does not change camera")
			for part_id in poses: check(demo.assembly.parts[part_id].transform.is_equal_approx(poses[part_id]),id+": modal does not change wood")
			if resolution == Vector2i(1440,900):
				var fixed_id := ""
				var free_id := ""
				for spec in demo.assembly.definition.parts:
					if spec.get("fixed",false): fixed_id = spec.id
					elif free_id.is_empty(): free_id = spec.id
				await orbit_from(fixed_id,id+": post-modal fixed-part orbit")
				check(await capture(free_id,16),id+": post-modal actual free-part capture")
				await mouse(cursor,false)
				check(demo.interaction.mode == "idle",id+": post-modal release")
			await click(demo.science_entry.get_global_rect().get_center())
			check(presenter.opened,id+": repeated open works")
			# Switching while open must close both modules and release input.
			demo.load_joint((index+1)%demo.catalog.size())
			check(not demo.dynamic_science.opened and not gallery.opened and not demo.education_input_suspended,id+": model switch releases modal ownership")
	# Exercise a full natural-time cycle under the real application process.
	demo.load_joint(1)
	await process_frame
	await click(demo.science_entry.get_global_rect().get_center())
	var cycles_before: int = gallery.diagram.clock.cycles
	await create_timer(7.4).timeout
	check(gallery.diagram.clock.cycles > cycles_before and gallery.diagram.clock.playing,"live process naturally loops without manual advance")
	await click(gallery.close_button.get_global_rect().get_center())
	# Existing smaller framing and permanent-lock regressions run separately.
	demo.free()
	print("FORCE GALLERY HOST: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
