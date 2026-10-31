extends SceneTree
## End-to-end Viewport events: never move or install a real test part through core APIs.
var demo
var passed := 0
var failed := 0
var checkpoints: Array = []
var cursor := Vector2.ZERO

func check(ok: bool,description: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func motion(position: Vector2,relative := Vector2.ZERO) -> void:
	cursor = position
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	root.push_input(event, true)
	await process_frame

func mouse(position: Vector2,pressed: bool) -> void:
	cursor = position
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func click(position: Vector2) -> void:
	await motion(position)
	await mouse(position,true)
	await mouse(position,false)

func wait_idle() -> bool:
	var deadline := Time.get_ticks_msec()+8000
	while not demo.assembly.moving.is_empty() and Time.get_ticks_msec()<deadline:
		await create_timer(0.02).timeout
	return demo.assembly.moving.is_empty()

func pick_screen(id: String) -> Vector2:
	var part: Node3D = demo.assembly.parts[id]
	var mesh: Mesh = part.get_node("Wood").mesh
	var faces := mesh.get_faces()
	var center: Vector2 = demo.camera.unproject_position(part.global_transform*mesh.get_aabb().get_center())
	var points: Array[Vector2] = []
	for i in range(0,faces.size(),3):
		var world: Vector3 = part.global_transform*((faces[i]+faces[i+1]+faces[i+2])/3.0)
		if demo.camera.is_position_behind(world): continue
		var screen: Vector2 = demo.camera.unproject_position(world)
		var size := root.get_visible_rect().size
		if screen.x > 16 and screen.x < size.x - 16 and screen.y > 16 and screen.y < size.y - 16 and not demo.workshop_panel.get_global_rect().has_point(screen): points.append(screen)
	points.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(center)<b.distance_squared_to(center))
	for screen in points:
		var origin: Vector3 = demo.camera.project_ray_origin(screen)
		var direction: Vector3 = demo.camera.project_ray_normal(screen)
		var hit: Dictionary = demo.camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*100))
		if not hit.is_empty() and hit.collider == part: return screen
	return Vector2(-1,-1)

func grab(id: String) -> bool:
	await physics_frame
	var start := pick_screen(id)
	check(start.x >= 0, "visible actual surface: " + id)
	if start.x < 0: return false
	await motion(start)
	await mouse(start, true)
	var ok: bool = demo.interaction.mode == "drag" and demo.interaction.drag_id == id
	check(ok, "real press owns: " + id)
	return ok

func capture(id: String, steps: int) -> bool:
	if not await grab(id): return false
	var start := cursor
	var entrance: Transform3D = demo.assembly.global_transform * demo.assembly.entrance_pose(id)
	var target: Vector2 = demo.camera.unproject_position(entrance * demo.interaction.grab_local)
	if start.distance_to(target) < 6.0: target += Vector2(6, 0)
	for index in range(1, steps + 1):
		await motion(start.lerp(target, float(index) / steps), (target - start) / steps)
		if demo.assembly.is_guided(id): break
	if not demo.assembly.is_guided(id):
		print("CAPTURE_DIAGNOSTIC ", id, " start=", start, " target=", target, " mode=", demo.interaction.mode, " candidate=", demo.assembly.capture_candidate(id), " panel=", demo.workshop_panel.get_global_rect())
	check(demo.assembly.is_guided(id), "held entrance calibrates: " + id)
	return demo.assembly.is_guided(id)

func move_to(id: String, fraction: float, slow: bool = true) -> void:
	var total: float = demo.assembly.path_length(id)
	var desired := total * fraction
	for iteration in range(160):
		if not demo.assembly.is_guided(id): break
		var progress: float = demo.assembly.path_progress[id]
		var difference := desired - progress
		if absf(difference) < .00001: break
		var amount := clampf(difference, -total / 12.0, total / 12.0) if slow else difference
		# Estimate a visible drag from the current projected piece toward its desired
		# location, then correct on subsequent input; no core motion API is called.
		var next: Transform3D = demo.assembly.path_pose(id, clampf(progress + amount, 0.0, total))
		var current: Transform3D = demo.assembly.parts[id].transform
		var first: Vector3 = demo.assembly.to_global(current * demo.interaction.grab_local)
		var last: Vector3 = demo.assembly.to_global(next * demo.interaction.grab_local)
		var movement: Vector2 = demo.camera.unproject_position(last) - demo.camera.unproject_position(first)
		if movement.length() < .00001 or fraction < 0 and progress < .00001:
			var points: Array = demo.assembly.specs[id].insertion_path
			var start: Vector3 = demo.assembly.vector(points[0])
			var end: Vector3 = demo.assembly.vector(points[1])
			movement = demo.camera.unproject_position(demo.assembly.to_global(end)) - demo.camera.unproject_position(demo.assembly.to_global(start))
			movement = movement.normalized() * (-3.0 if fraction < 0 else 3.0)
		# A real finish stroke crosses the endpoint by a visible pixel. Avoid an
		# asymptotic sub-pixel test stroke being rounded away in wide viewports.
		if (fraction >= 1.0 or fraction < 0.0) and movement.length() > 0.0 and movement.length() < 1.0:
			movement = movement.normalized()
		await motion(cursor + movement, movement)
	check((fraction < 0 and demo.assembly.states[id] == "free") or (fraction >= 1 and demo.assembly.states[id] == "locked") or (demo.assembly.is_guided(id) and absf(float(demo.assembly.path_progress[id]) - desired) < .002), "mouse reaches requested path progress: " + id + " / " + str(fraction))

func parked(id: String, label: String) -> void:
	var before: Transform3D = demo.assembly.parts[id].transform
	await mouse(cursor, false)
	await create_timer(.06).timeout
	check(demo.assembly.parts[id].transform.is_equal_approx(before), label + ": release/time cannot animate")
	check(demo.interaction.mode == "idle", "release clears ownership")

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/evidence/manual-" + label + ".png")

func run() -> void:
	root.size = Vector2i(1440, 900)
	demo = load("res://demo/workshop.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	await snapshot("entry")
	for view in [Vector2(.68,.42), Vector2(-.55,.55), Vector2(1.25,.65)]:
		for index in demo.catalog.size():
			demo.load_joint(index)
			demo.interaction.yaw = view.x
			demo.interaction.pitch = view.y
			# Each reference view is framed before input. An arbitrary unrefitted
			# orbit may legitimately place the entrance under a GUI control.
			demo.interaction.fit_model()
			await physics_frame
			for spec in demo.assembly.definition.parts:
				if spec.get("fixed", false): continue
				var id: String = spec.id
				if not await capture(id, 16):
					await mouse(cursor, false)
					continue
				await parked(id, "captured entrance")
				check(demo.assembly.is_guided(id) and is_zero_approx(demo.assembly.path_progress[id]), "release cannot auto-insert")
				if not await grab(id): continue
				await move_to(id, .43)
				await parked(id, "partial insertion")
				if index == 0 and view.x == .68: await snapshot("parked")
				if not await grab(id): continue
				await move_to(id, -.02)
				await mouse(cursor, false)
				check(demo.assembly.states[id] == "free", "unfinished part can reverse and exit")
				# Click alone near entrance must not capture or advance.
				await click(pick_screen(id))
				check(demo.assembly.states[id] == "free", "click alone only selects")
				if not await capture(id, 1):
					# After exiting at the exact entrance use a small held movement to express intent.
					await motion(cursor + Vector2(6,0), Vector2(6,0))
				check(demo.assembly.is_guided(id), "re-entry after withdrawal")
				if demo.assembly.is_guided(id): await move_to(id, 1.03, false)
				await parked(id, "finished")
				check(demo.assembly.states[id] == "locked" and not demo.assembly.can_remove(id), "final lock prevents removal")
				if index == 0 and view.x == .68: await snapshot("locked")
			checkpoints.append({"model": demo.catalog[index].id, "view": [view.x, view.y]})
			print("MANUAL INPUT ROUND ", demo.catalog[index].id, " view=", view)
	# Regrabbing a partially inserted piece must reach the exact lock endpoint.
	demo.load_joint(0)
	demo.interaction.yaw = .68
	demo.interaction.pitch = .42
	demo.interaction.update_camera()
	check(await capture("tail", 16), "partial regrab regression calibrates")
	await move_to("tail", .43)
	await parked("tail", "partial regrab regression")
	if await grab("tail"):
		await move_to("tail", 1.03, false)
		await parked("tail", "partial regrab reaches permanent lock")
	check(demo.assembly.states.tail == "locked", "partial regrab cannot stall at rounded 100 percent")
	# Removed auxiliary UI is replaced by the direct held calibration path.
	demo.load_joint(0)
	check(await capture("tail",16),"direct drag starts manual calibration without auxiliary UI")
	await mouse(cursor,false)
	var before: Transform3D = demo.assembly.parts.tail.transform
	await create_timer(.15).timeout
	check(demo.assembly.parts.tail.transform.is_equal_approx(before), "entry button has no autonomous motion")
	if await grab("tail"):
		await move_to("tail", .35)
		var safe: Transform3D = demo.assembly.parts.tail.transform
		demo.interaction.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(demo.interaction.mode == "idle" and demo.assembly.parts.tail.transform.is_equal_approx(safe), "focus loss parks guided piece")
		if await grab("tail"):
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			root.push_input(escape)
			await process_frame
			check(demo.interaction.mode == "idle" and demo.assembly.parts.tail.transform.is_equal_approx(safe), "Esc parks guided piece")
		if await grab("tail"):
			await mouse(Vector2(50,100), false)
			check(demo.interaction.mode == "idle" and demo.assembly.parts.tail.transform.is_equal_approx(safe), "release over panel parks guided piece")
	await click(demo.buttons.reset.get_global_rect().get_center())
	check(demo.assembly.states.tail == "free", "real reset button restarts")
	var report := {"passed":passed, "failed":failed, "checkpoints":checkpoints, "human_mouse_verified":false, "display":DisplayServer.get_name()}
	FileAccess.open("res://tests/drag_input_report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	demo.free()
	print("MANUAL VIEWPORT INPUT: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
