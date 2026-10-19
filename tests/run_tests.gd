extends SceneTree
const Assembly = preload("res://core/assembly.gd")
const Interaction = preload("res://core/interaction.gd")
var passed := 0
var failed := 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	if not catalog is Array or catalog.size() != 9:
		push_error("Expected nine catalog entries")
		quit(1)
		return
	var first: Dictionary = catalog[0]
	var assembly := Assembly.new()
	root.add_child(assembly)
	for definition in catalog:
		assembly.load_definition(definition)
		check(assembly.parts.size() == definition.parts.size(), definition.id + ": all parts loaded")
		var free_ids: Array = []
		for spec in definition.parts:
			check(assembly.parts[spec.id].get_node("Wood").mesh.get_faces().size() > 0, spec.id + ": real geometry")
			if spec.get("fixed", false):
				check(not assembly.set_part_pose(spec.id, Transform3D.IDENTITY), "fixed is immovable")
				continue
			free_ids.append(spec.id)
			check(spec.insertion_path.size() >= 2, "path has entry and end")
			check(Assembly.vector(spec.insertion_path[-1]).is_equal_approx(Assembly.vector(spec.assembled_position)), "path terminates at assembly pose")
		# Resolve in dependency order, never relying on dictionary order.
		var pending := free_ids.duplicate()
		for _round in range(free_ids.size()):
			for id in pending.duplicate():
				assembly.set_part_pose(id, assembly.entrance_pose(id))
				if assembly.candidate(id).ok:
					check(assembly.insert_part(id, true), "insert " + id)
					check(assembly.states[id] == "locked", "lock " + id)
					check(not assembly.set_part_pose(id, Transform3D.IDENTITY), "locked cannot move")
					check(assembly.candidate(id).reason == "occupied", "occupied rejection")
					pending.erase(id)
		check(pending.is_empty(), definition.id + ": dependencies resolvable")
		for spec in definition.parts:
			for dependency in spec.get("dependencies", []):
				check(not assembly.can_remove(dependency), "dependent blocks removal")
		pending = free_ids.duplicate()
		for _round in range(free_ids.size()):
			for id in pending.duplicate():
				if assembly.can_remove(id):
					check(assembly.remove_part(id, true), "reverse remove " + id)
					check(assembly.parts[id].transform.is_equal_approx(assembly.withdrawn_pose(id)), "returns to parking pose")
					pending.erase(id)
		check(pending.is_empty(), "reverse dependency removal")
		assembly.reset()
		for spec in definition.parts:
			if not spec.get("fixed", false):
				check(assembly.states[spec.id] == "free", "reset unlock")
				check(assembly.parts[spec.id].position.is_equal_approx(Assembly.vector(spec.start_position)), "reset pose")

	assembly.load_definition(first)
	var id: String = ""
	for spec in first.parts:
		if not spec.get("fixed", false):
			id = spec.id
			break
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	check(assembly.candidate(id).ok, "correct entry accepted")
	var value := assembly.entrance_pose(id)
	value.origin.x += assembly.distance_tolerance + 0.01
	assembly.set_part_pose(id, value)
	check(assembly.candidate(id).reason == "distance", "distance rejection")
	value.origin.x -= 0.02
	assembly.set_part_pose(id, value)
	check(assembly.candidate(id).ok, "distance tolerance boundary")
	value = assembly.entrance_pose(id)
	value.basis = Basis(Vector3.UP, deg_to_rad(assembly.angle_tolerance_degrees + 0.1)) * value.basis
	# Predicate unit fixture: place directly; collision movement is tested separately.
	assembly.parts[id].transform = value
	check(assembly.candidate(id).reason == "angle", "angle rejection")
	value = assembly.entrance_pose(id)
	value.basis = Basis(Vector3.UP, deg_to_rad(assembly.angle_tolerance_degrees - 0.1)) * value.basis
	assembly.parts[id].transform = value
	check(assembly.candidate(id).ok, "angle tolerance boundary")
	for other in assembly.parts:
		if other != id: check(assembly.candidate(id, other).reason == "pair", "wrong pair rejection")
	check(assembly.candidate("missing").reason == "unknown", "unknown part")
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	check(assembly.insert_part(id), "animated insert starts")
	check(not assembly.set_part_pose(id, Transform3D.IDENTITY), "moving input blocked")
	await create_timer(0.05).timeout
	assembly.cancel_motion()
	await create_timer(0.3).timeout
	check(assembly.states[id] == "free" and assembly.moving.is_empty(), "cancel insertion restores free")
	check(assembly.parts[id].transform.is_equal_approx(assembly.entrance_pose(id)), "cancel insertion safe pose")
	assembly.insert_part(id)
	assembly.reset()
	await create_timer(0.15).timeout
	check(assembly.states[id] == "free" and assembly.moving.is_empty(), "reset kills tween")
	var instance := Assembly.new()
	root.add_child(instance)
	instance.transform = Transform3D(Basis(Vector3.UP, 0.6), Vector3(25,0,0))
	instance.load_definition(first)
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	instance.set_part_pose(id, instance.entrance_pose(id))
	assembly.insert_part(id, true)
	check(instance.candidate(id).ok, "instance occupancy isolated")
	check(instance.parts[id].global_position.distance_to(assembly.parts[id].global_position) > 15, "instance transform isolated")
	instance.insert_part(id, true)
	assembly.reset()
	check(instance.states[id] == "locked", "reset instance isolation")
	instance.free()

	# Connector coordinates, not object origin, govern matching.
	var custom := first.duplicate(true)
	for spec in custom.parts:
		if spec.id == id:
			spec.connector_position = [0.2,0.3,0.1]
			spec.connector_rotation = [0,15,0]
			var socket: Transform3D = Assembly.pose(spec.insertion_path[0]) * Assembly.pose(spec.connector_position, spec.connector_rotation)
			spec.socket_position = [socket.origin.x,socket.origin.y,socket.origin.z]
			spec.socket_rotation = [0,15,0]
	assembly.load_definition(custom)
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	check(assembly.candidate(id).ok, "local connector offset and orientation")
	check(assembly.snap(id), "connector snap")
	check(assembly.parts[id].transform.is_equal_approx(assembly.entrance_pose(id)), "connector snap preserves correct body pose")

	# Non-collinear paths must visit the corner instead of cutting across it.
	custom = first.duplicate(true)
	for spec in custom.parts:
		if spec.get("fixed", false): spec.assembled_position = [0,-100,0]
		if spec.id == id:
			spec.insertion_path = [[3,3,0],[0,3,0],[0,0,0]]
			spec.assembled_position = [0,0,0]
	assembly.load_definition(custom)
	assembly.insertion_speed = 30
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	assembly.insert_part(id)
	for frame in range(30):
		await process_frame
		var pos: Vector3 = assembly.parts[id].position
		check(absf(pos.y - 3.0) < 0.001 or absf(pos.x) < 0.001, "motion stays on configured segments")
	await create_timer(0.4).timeout
	check(assembly.states[id] == "locked", "animated path completed")
	assembly.remove_part(id)
	await create_timer(0.03).timeout
	assembly.cancel_motion()
	await create_timer(0.3).timeout
	check(assembly.states[id] == "locked" and assembly.occupied.has(id), "cancel removal restores occupancy")
	check(assembly.parts[id].transform.is_equal_approx(assembly.assembled_pose(id)), "cancel removal safe pose")

	var view := Camera3D.new()
	root.add_child(view)
	var input := Interaction.new()
	root.add_child(input)
	input.configure(assembly, view)
	var isolated := Assembly.new()
	root.add_child(isolated)
	isolated.load_definition(first)
	check(input.owns_collider(assembly.parts[id]), "own collider accepted")
	check(not input.owns_collider(isolated.parts[id]), "same ID in another instance rejected")
	isolated.free()
	assembly.reset()
	assembly.select_part(id)
	check(input.begin_drag(id, Vector2(200,200)), "drag begins")
	check(not input.begin_drag(id, Vector2(300,300)), "cannot begin second drag")
	var before: Transform3D = assembly.parts[id].transform
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	input.cancel()
	check(input.mode == "idle" and assembly.parts[id].transform.is_equal_approx(before), "cancel drag restores safe pose")
	assembly.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(2,1,0))
	var start_screen := Vector2(240,220)
	check(input.begin_drag(id, start_screen), "transformed instance drag starts")
	var movement := InputEventMouseMotion.new()
	movement.position = Vector2(280,250)
	movement.relative = Vector2(40,30)
	var expected_hit = input.drag_plane.intersects_ray(view.project_ray_origin(movement.position), view.project_ray_normal(movement.position))
	var expected_local: Vector3 = assembly.to_local(expected_hit + input.drag_offset)
	var yaw_before: float = input.yaw
	input._unhandled_input(movement)
	check(assembly.parts[id].position.is_equal_approx(expected_local), "drag maps world plane into transformed assembly")
	check(is_equal_approx(input.yaw, yaw_before), "drag and orbit mutually exclusive")
	var distance_before: float = input.distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	input._unhandled_input(wheel)
	check(is_equal_approx(input.distance, distance_before), "wheel cannot move camera during part drag")
	input.cancel()
	assembly.transform = Transform3D.IDENTITY
	var other_assembly := Assembly.new()
	root.add_child(other_assembly)
	other_assembly.load_definition(first)
	var other_input := Interaction.new()
	root.add_child(other_input)
	other_input.configure(other_assembly, view)
	check(not other_input.keyboard_active and input.keyboard_active, "only one keyboard owner initially")
	other_input.activate()
	check(other_input.keyboard_active and not input.keyboard_active, "activation transfers keyboard ownership")
	input.activate()
	other_input.free()
	other_assembly.free()
	input.mode = "orbit"
	input.release()
	check(input.mode == "idle", "release clears orbit")
	input.free()
	view.free()
	var events: Array[String] = []
	assembly.connection_succeeded.connect(func(part_id: String): events.append("insert:"+part_id))
	assembly.disassembled.connect(func(part_id: String): events.append("remove:"+part_id))
	assembly.reset_completed.connect(func(): events.append("reset"))
	assembly.reset()
	check(events == ["reset"], "reset semantic signal")
	assembly.set_part_pose(id, assembly.entrance_pose(id))
	assembly.insert_part(id, true)
	check(events == ["reset","insert:"+id], "successful connection semantic signal")
	assembly.insert_part(id, true)
	check(events.size() == 2, "rejected duplicate emits no connection signal")
	assembly.remove_part(id, true)
	check(events == ["reset","insert:"+id,"remove:"+id], "disassembly semantic signal")
	assembly.free()
	print("JOINERY TESTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
