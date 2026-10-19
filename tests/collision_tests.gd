extends SceneTree
const Guard = preload("res://core/mesh_collision_guard.gd")
const Assembly = preload("res://core/assembly.gd")
var passed := 0
var failed := 0
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("COLLISION FAIL: " + label)
func at_pose(x: float, y: float = 0, z: float = 0, angle: float = 0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, angle), Vector3(x,y,z))
func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var started := Time.get_ticks_msec()
	var guard = Guard.new()
	guard.register_mesh("small", box(Vector3.ONE * 0.3))
	guard.register_mesh("wall", box(Vector3(0.02,2,2)))
	var obstacles := {"wall": Transform3D.IDENTITY}
	check(not guard.motion_is_safe("small", at_pose(-3), at_pose(3), obstacles), "fast drag cannot tunnel through thin wall with clear endpoint")
	check(not guard.motion_is_safe("small", at_pose(-3), at_pose(0), obstacles), "destination overlap rejected")
	check(guard.motion_is_safe("small", at_pose(-3,2), at_pose(3,2), obstacles), "nearby unobstructed movement permitted")
	guard.register_mesh("solid", box(Vector3.ONE * 2))
	check(not guard.motion_is_safe("small", at_pose(0), at_pose(0), {"solid": Transform3D.IDENTITY}), "fully contained solid detected")
	guard.register_mesh("bar", box(Vector3(4,0.2,0.2)))
	guard.register_mesh("peg", box(Vector3.ONE * 0.2))
	check(not guard.motion_is_safe("bar", at_pose(0), at_pose(0,0,0,PI), {"peg": at_pose(0,0,1.5)}), "rotation sweep cannot pass peg despite clear endpoint")
	check(guard.motion_is_safe("bar", at_pose(0), at_pose(0,0,0,PI), {"peg": at_pose(0,2,1.5)}), "unobstructed rotation accepted")
	guard.register_mesh("post", load("res://models/assets/through_tenon_post.obj"))
	check(guard.motion_is_safe("small", at_pose(-2), at_pose(2), {"post": Transform3D.IDENTITY}), "concave hole is not filled by a convex hull")
	check(not guard.motion_is_safe("small", at_pose(-2,0.8), at_pose(2,0.8), {"post": Transform3D.IDENTITY}), "same sweep outside mortise blocked by real wood")

	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	var assembly := Assembly.new()
	root.add_child(assembly)
	for definition in catalog:
		assembly.load_definition(definition)
		var pending: Array = []
		for spec in definition.parts:
			if not spec.get("fixed", false): pending.append(spec.id)
		for _round in range(pending.size()):
			for id in pending.duplicate():
				var ready := true
				for dep in assembly.specs[id].dependencies:
					if assembly.states[dep] != "locked": ready = false
				if not ready: continue
				check(assembly.set_part_pose(id, assembly.entrance_pose(id)), definition.id + ": clear approach")
				check(assembly.insert_part(id, true), definition.id + ": actual concave insertion path")
				pending.erase(id)
		check(pending.is_empty(), definition.id + ": complete assembly")
		for _round in range(definition.parts.size()):
			for id in assembly.parts:
				if assembly.can_remove(id): check(assembly.remove_part(id, true), definition.id + ": safe reverse path")

	assembly.load_definition(catalog[2])
	var id: String = "beam"
	var before: Transform3D = assembly.parts[id].transform
	var blocked := before
	blocked.origin = Vector3(-4,0.8,0)
	check(not assembly.set_part_pose(id, blocked), "drag across fixed post rejected")
	check(assembly.parts[id].transform.is_equal_approx(before), "rejected drag retains last safe pose")
	check(assembly.set_part_pose(id, assembly.entrance_pose(id)), "safe approach after rejected drag")
	check(assembly.insert_part(id, true), "safe insertion still works")
	check(assembly.remove_part(id, true), "safe removal still works")
	assembly.reset()
	var almost := assembly.entrance_pose(id)
	almost.origin.x += 0.1
	almost.basis = Basis(Vector3.UP, deg_to_rad(5.0))
	check(assembly.set_part_pose(id, almost), "slightly offset/angled clear approach accepted")
	check(assembly.candidate(id).ok and assembly.snap(id), "nearby snap follows checked position and angle correction")
	var wrong_angle := assembly.entrance_pose(id)
	wrong_angle.basis = Basis(Vector3.UP, deg_to_rad(20.0))
	check(assembly.set_part_pose(id, wrong_angle), "wrong-angle fixture remains physically clear")
	check(assembly.candidate(id).reason == "angle" and not assembly.insert_part(id, true), "wrong-angle insertion refused")
	# Synthetic controller fixtures isolate snap/path rejection from catalog shape.
	ResourceSaver.save(box(Vector3.ONE * 0.3), "user://collision_test_small.tres")
	ResourceSaver.save(box(Vector3(0.02,2,2)), "user://collision_test_wall.tres")
	var fixture := {"id":"fixture","name":"fixture","parts":[
		{"id":"wall","mesh":"user://collision_test_wall.tres","fixed":true,"assembled_position":[0,0,0],"start_position":[0,0,0],"insertion_path":[[0,0,0]],"dependencies":[]},
		{"id":"moving","mesh":"user://collision_test_small.tres","fixed":false,"assembled_position":[4,0,0],"start_position":[-3,0,0],"insertion_path":[[3,0,0],[4,0,0]],"dependencies":["wall"]}
	]}
	assembly.load_definition(fixture)
	assembly.distance_tolerance = 10.0
	check(assembly.candidate("moving").ok, "snap fixture inside generous matching tolerance")
	check(not assembly.snap("moving"), "snap approach swept through wood is rejected")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(-3,0,0)), "rejected snap does not teleport")
	check(not assembly.insert_part("moving", true), "instant insertion cannot bypass swept snap guard")
	var installed_fixture: Dictionary = fixture.duplicate(true)
	installed_fixture.parts[0].fixed = false
	installed_fixture.parts[0].start_position = [0,5,0]
	installed_fixture.parts[0].insertion_path = [[0,5,0],[0,0,0]]
	assembly.load_definition(installed_fixture)
	check(assembly.insert_part("wall", true) and assembly.states.wall == "locked", "obstacle installed through real assembly API")
	check(not assembly.set_part_pose("moving", at_pose(3)), "drag cannot cross an already assembled non-fixed piece")
	fixture.parts[1].insertion_path = [[-3,0,0],[4,0,0]]
	assembly.load_definition(fixture)
	check(not assembly.insert_part("moving", true), "configured path crossing solid is rejected before motion")
	check(assembly.moving.is_empty() and assembly.states.moving == "free", "rejected path preserves free state")
	fixture.parts[1].assembled_position = [3,0,0]
	fixture.parts[1].insertion_path = [[-3,0,0],[-3,2,0],[3,2,0],[3,0,0]]
	assembly.load_definition(fixture)
	check(assembly.insert_part("moving", true), "clear multisegment route accepted")
	check(assembly.remove_part("moving", true), "clear multisegment reverse accepted")
	assembly.reset()
	assembly.insertion_speed = 10.0
	check(assembly.insert_part("moving"), "animated detour begins")
	await create_timer(0.65).timeout
	var cancellation_origin: Vector3 = assembly.parts.moving.position
	check(cancellation_origin.x > 0.0 and absf(cancellation_origin.y - 2.0) < 0.01, "cancel begins beyond obstacle after corner")
	assembly.cancel_motion()
	check(assembly.parts.moving.position.is_equal_approx(cancellation_origin), "cancel never instantly teleports across obstacle")
	var reverse_on_segments := true
	for _frame in range(180):
		await create_timer(0.01).timeout
		var position: Vector3 = assembly.parts.moving.position
		if absf(position.y - 2.0) > 0.002 and absf(position.x + 3.0) > 0.002: reverse_on_segments = false
		if assembly.moving.is_empty(): break
	check(reverse_on_segments, "cancel retraces reached segments without corner cutting")
	check(assembly.states.moving == "free" and assembly.parts.moving.position.is_equal_approx(Vector3(-3,0,0)), "cancel returns safely to entrance")
	# Wrong connector geometry cannot be corrected invisibly at animation end.
	fixture.parts[1].connector_rotation = [0,15,0]
	fixture.parts[1].socket_rotation = [0,0,0]
	assembly.load_definition(fixture)
	assembly.angle_tolerance_degrees = 20
	check(not assembly.insert_part("moving", true), "connector/path orientation mismatch rejected")
	assembly.free()
	print("JOINERY COLLISION TESTS: %d passed, %d failed; %d ms" % [passed, failed, Time.get_ticks_msec() - started])
	quit(0 if failed == 0 else 1)
