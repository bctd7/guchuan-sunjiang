extends "res://tests/drag_input_tests.gd"

func check_frame(label: String) -> void:
	var camera := demo.camera as Camera3D
	var size := root.get_visible_rect().size
	var area: Rect2 = demo.interaction.orbit.framing_rect
	var assembled_bounds := AABB()
	var has_bounds := false
	for id in demo.assembly.parts:
		var bounds: AABB = demo.assembly.parts[id].get_node("Wood").mesh.get_aabb()
		for index in range(8):
			var point: Vector3 = demo.assembly.assembled_pose(id) * bounds.get_endpoint(index)
			if has_bounds: assembled_bounds = assembled_bounds.expand(point)
			else: assembled_bounds = AABB(point,Vector3.ZERO); has_bounds = true
	check(demo.interaction.target.distance_to(demo.assembly.to_global(assembled_bounds.get_center())) < .0001, label + ": composition preserves assembled pivot")
	var projected_low := Vector2(INF, INF)
	var projected_high := Vector2(-INF, -INF)
	for id in demo.assembly.parts:
		var part: Node3D = demo.assembly.parts[id]
		var mesh: Mesh = part.get_node("Wood").mesh
		var bounds := mesh.get_aabb()
		for index in range(8):
			var point := part.global_transform * bounds.get_endpoint(index)
			check(not camera.is_position_behind(point) and area.grow(.001).has_point(camera.unproject_position(point) / size), label + ": current mesh corner fits")
			for pose in [part.transform, demo.assembly.assembled_pose(id)]:
				var screen := camera.unproject_position(demo.assembly.to_global(pose * bounds.get_endpoint(index))) / size
				projected_low = projected_low.min(screen)
				projected_high = projected_high.max(screen)
	check(((projected_low + projected_high) * .5).distance_to(area.get_center()) < .01, label + ": perspective content bounds centered in usable area")
	var occupancy := (projected_high - projected_low) / area.size
	check(occupancy.x <= .55 and occupancy.y <= .46, label + ": automatic fit targets half-width with under-45-percent height")

func orbit_from(id: String, label: String) -> void:
	var screen := pick_screen(id)
	check(screen.x >= 0, label + ": visible surface")
	if screen.x < 0: return
	await motion(screen)
	await mouse(screen, true)
	check(demo.interaction.mode == "orbit", label + ": hit falls back to orbit")
	var yaw: float = demo.interaction.yaw
	await motion(screen + Vector2(20, 8), Vector2(20, 8))
	check(not is_equal_approx(yaw, demo.interaction.yaw), label + ": actual held motion rotates")
	await mouse(screen + Vector2(20, 8), false)
	check(demo.interaction.mode == "idle", label + ": release clears orbit")

func run() -> void:
	# Exercise actual viewport aspect ratios, independently of project letterboxing.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	demo = load("res://components/teaching/classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	check_frame("first open")
	for resolution in [Vector2i(1440,900), Vector2i(900,1200), Vector2i(1920,800)]:
		root.size = resolution
		await process_frame
		for index in demo.catalog.size():
			demo.picker.select(index)
			demo.load_joint(index)
			demo.interaction.yaw = .68
			demo.interaction.pitch = .42
			demo._update_framing()
			await physics_frame
			var label := "%s %s" % [demo.catalog[index].id, resolution]
			check(is_equal_approx(demo.interaction.orbit.screen_center_x, demo.interaction.orbit.framing_rect.get_center().x), label + ": view centered in free model area")
			check_frame(label)
			var shot_suffix := "" if resolution == Vector2i(1440,900) else "-%dx%d" % [resolution.x,resolution.y]
			if resolution == Vector2i(1440,900) or index == 0: await snapshot(str(demo.catalog[index].id) + "-entry" + shot_suffix)
			var fixed_id := ""
			for spec in demo.assembly.definition.parts:
				if spec.get("fixed",false): fixed_id = spec.id; break
			await orbit_from(fixed_id, label + " fixed")
			demo.interaction.yaw = .68
			demo.interaction.pitch = .42
			demo._update_framing()
			for spec in demo.assembly.definition.parts:
				if spec.get("fixed",false): continue
				var id: String = spec.id
				if not await capture(id,16): await mouse(cursor,false); continue
				var view_before: Transform3D = demo.camera.global_transform
				var distance_before: float = demo.interaction.distance
				await move_to(id,.43)
				await parked(id,label + " partial")
				check(demo.camera.global_transform.is_equal_approx(view_before) and is_equal_approx(distance_before,demo.interaction.distance), label + ": partial drag and pause never refit")
				if await grab(id): await move_to(id,1.03,false)
				check(demo.assembly.states[id] == "locked", label + ": resumed path locks")
				check(demo.camera.global_transform.is_equal_approx(view_before), label + ": lock does not refit while held")
				var held_distance: float = demo.interaction.distance
				await mouse(cursor,false)
				check(demo.interaction.distance >= held_distance - .00001, label + ": completion never automatically pulls camera closer")
			check_frame(label + " assembled")
			if resolution == Vector2i(1440,900) or index == 0: await snapshot(str(demo.catalog[index].id) + "-locked" + shot_suffix)
			# A visible locked member must orbit without allowing disassembly.
			for spec in demo.assembly.definition.parts:
				if not spec.get("fixed",false) and pick_screen(spec.id).x >= 0:
					await orbit_from(spec.id,label + " completed")
					check(demo.assembly.states[spec.id] == "locked", label + ": orbit retains permanent lock")
					break
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			demo.interaction.distance = 1.0
			demo.interaction.update_camera()
			demo.interaction._unhandled_input(wheel)
			check(is_equal_approx(demo.interaction.distance,.9), label + ": inward wheel below three never zooms out")
			demo.interaction.distance = demo.interaction.orbit.minimum_distance
			demo.interaction._unhandled_input(wheel)
			check(is_equal_approx(demo.interaction.distance,demo.interaction.orbit.minimum_distance), label + ": wheel respects shared minimum")
		# UI presses continue to consume pointer ownership.
		demo.interaction.yaw = .68
		demo.interaction.pitch = .42
		demo.load_joint(0)
		# The dovetail-only entry changes the panel layout on model switch.
		await process_frame
		await process_frame
		var fitted_distance: float = demo.interaction.distance
		demo.interaction.distance *= .8
		demo.interaction.update_camera()
		await click(demo.buttons.view.get_global_rect().get_center())
		check(is_equal_approx(demo.interaction.distance,fitted_distance),"actual view reset restores padded boundary fit")
		check_frame("view reset " + str(resolution))
		var yaw: float = demo.interaction.yaw
		await click(demo.buttons.xray.get_global_rect().get_center())
		await process_frame
		check(demo.interaction.mode == "idle" and is_equal_approx(yaw,demo.interaction.yaw), "left UI button does not start orbit")
		check_frame("single panel " + str(resolution))
	demo.free()
	print("VIEW AND HIT INPUT: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
