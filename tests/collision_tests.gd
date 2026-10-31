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
	return Transform3D(Basis(Vector3.UP,angle),Vector3(x,y,z))

func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _initialize() -> void:
	call_deferred("run")

func test_guard() -> void:
	var guard = Guard.new()
	guard.register_mesh("small",box(Vector3.ONE * 0.3))
	guard.register_mesh("wall",box(Vector3(0.02,2,2)))
	var obstacles := {"wall":Transform3D.IDENTITY}
	check(not guard.motion_is_safe("small",at_pose(-3),at_pose(3),obstacles), "fast drag cannot tunnel through thin wall with clear endpoint")
	check(not guard.motion_is_safe("small",at_pose(-3),at_pose(0),obstacles), "destination overlap rejected")
	check(guard.motion_is_safe("small",at_pose(-3,2),at_pose(3,2),obstacles), "nearby unobstructed movement permitted")
	guard.register_mesh("solid",box(Vector3.ONE * 2))
	check(not guard.motion_is_safe("small",at_pose(0),at_pose(0),{"solid":Transform3D.IDENTITY}), "fully contained solid detected")
	guard.register_mesh("bar",box(Vector3(4,0.2,0.2)))
	guard.register_mesh("peg",box(Vector3.ONE * 0.2))
	check(not guard.motion_is_safe("bar",at_pose(0),at_pose(0,0,0,PI),{"peg":at_pose(0,0,1.5)}), "rotation sweep cannot pass peg despite clear endpoint")
	check(guard.motion_is_safe("bar",at_pose(0),at_pose(0,0,0,PI),{"peg":at_pose(0,2,1.5)}), "unobstructed rotation accepted")
	guard.register_mesh("post",load("res://models/assets/through_tenon_post.obj"))
	check(guard.motion_is_safe("small",at_pose(-2),at_pose(2),{"post":Transform3D.IDENTITY}), "concave hole is not filled by convex hull")
	check(not guard.motion_is_safe("small",at_pose(-2,0.8),at_pose(2,0.8),{"post":Transform3D.IDENTITY}), "same sweep outside mortise blocked by real wood")
	var non_rigid := at_pose(-3)
	non_rigid.basis = non_rigid.basis.scaled(Vector3(2,1,1))
	check(not guard.motion_is_safe("small",non_rigid,at_pose(-2),{}), "non-rigid moving pose fails closed")
	check(not guard.motion_is_safe("missing",at_pose(-3),at_pose(-2),{}), "missing moving mesh fails closed")
	check(not guard.motion_is_safe("small",at_pose(-3),at_pose(-2),{"unknown":Transform3D.IDENTITY}), "missing obstacle mesh fails closed")
	# A cached safe pose cannot make a newly moved obstacle invisible.
	check(guard.motion_is_safe("small",at_pose(-3,2),at_pose(3,2),obstacles), "cache fixture initially clear")
	check(not guard.motion_is_safe("small",at_pose(3,2),at_pose(-3,2),{"wall":at_pose(0,2)}), "changed obstacle invalidates previous safe-pose cache")

func test_catalog(assembly: Node3D, catalog: Array) -> void:
	for definition in catalog:
		assembly.load_definition(definition)
		var pending: Array = []
		for spec in definition.parts:
			if not spec.get("fixed",false): pending.append(spec.id)
		for _round in range(pending.size()):
			for id in pending.duplicate():
				var ready := true
				for dep in assembly.specs[id].dependencies:
					if assembly.states[dep] != "locked": ready = false
				if not ready: continue
				check(assembly.set_part_pose(id,assembly.entrance_pose(id)),definition.id + ": clear approach")
				check(assembly.insert_part(id,true),definition.id + ": collision-safe calibration")
				check(assembly.is_guided(id),definition.id + ": legacy instant does not complete")
				var length: float = assembly.paths[id].length
				check(assembly.advance_insertion(id,length*0.75),definition.id + ": actual concave forward stroke")
				check(assembly.advance_insertion(id,-length*0.5),definition.id + ": real reverse path before final lock")
				check(assembly.advance_insertion(id,length),definition.id + ": actual concave final stroke")
				check(assembly.states[id] == "locked" and not assembly.remove_part(id,true),definition.id + ": final permanent lock")
				pending.erase(id)
		check(pending.is_empty(),definition.id + ": complete manual assembly")

func test_real_approach(assembly: Node3D, catalog: Array) -> void:
	assembly.load_definition(catalog[2])
	var id := "beam"
	var before: Transform3D = assembly.parts[id].transform
	var blocked := before
	blocked.origin = Vector3(-4,0.8,0)
	check(not assembly.set_part_pose(id,blocked), "drag across fixed post rejected")
	check(assembly.parts[id].transform.is_equal_approx(before), "rejected drag retains last safe pose")
	check(assembly.set_part_pose(id,assembly.entrance_pose(id)), "safe approach after rejected drag")
	check(assembly.begin_insertion(id), "safe calibration still works")
	check(assembly.advance_insertion(id,assembly.paths[id].length), "safe manual insertion still works")
	check(not assembly.remove_part(id,true), "completed real joint cannot be dismantled")
	assembly.reset()
	var almost: Transform3D = assembly.entrance_pose(id)
	almost.origin.x += 0.1
	almost.basis = Basis(Vector3.UP,deg_to_rad(5.0))
	check(assembly.set_part_pose(id,almost), "slightly offset/angled clear approach accepted")
	check(assembly.candidate(id).ok and assembly.snap(id), "nearby snap checks position and angle correction")
	# Predicate-only wrong-angle fixture. Physical angular sweeps are above.
	var wrong_angle: Transform3D = assembly.entrance_pose(id)
	wrong_angle.basis = Basis(Vector3.UP,deg_to_rad(assembly.capture_angle_degrees + 0.1))
	assembly.parts[id].transform = wrong_angle
	check(assembly.candidate(id).reason == "angle" and not assembly.insert_part(id,true), "outside capture angle cannot engage")

func test_controller_fixtures(assembly: Node3D) -> void:
	check(ResourceSaver.save(box(Vector3.ONE * 0.3),"user://collision_test_small.tres") == OK, "save small fixture")
	check(ResourceSaver.save(box(Vector3(0.02,2,2)),"user://collision_test_wall.tres") == OK, "save wall fixture")
	var fixture := {"id":"fixture","name":"fixture","parts":[
		{"id":"wall","mesh":"user://collision_test_wall.tres","fixed":true,"assembled_position":[0,0,0],"start_position":[0,0,0],"insertion_path":[[0,0,0]],"dependencies":[]},
		{"id":"moving","mesh":"user://collision_test_small.tres","fixed":false,"assembled_position":[4,0,0],"start_position":[-3,0,0],"insertion_path":[[3,0,0],[4,0,0]],"dependencies":["wall"]}
	]}
	assembly.load_definition(fixture)
	assembly.distance_tolerance = 10.0
	assembly.capture_distance = 10.0
	check(assembly.candidate("moving").ok, "blocked calibration fixture lies in matching tolerance")
	check(not assembly.snap("moving"), "calibration swept through wood is rejected")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(-3,0,0)), "rejected calibration does not teleport")
	check(not assembly.insert_part("moving",true), "legacy instant cannot bypass calibration sweep")
	check(assembly.states.moving == "free" and not assembly.progress.has("moving"), "blocked calibration preserves free state")
	var installed: Dictionary = fixture.duplicate(true)
	installed.parts[0].fixed = false
	installed.parts[0].start_position = [0,5,0]
	installed.parts[0].insertion_path = [[0,5,0],[0,0,0]]
	assembly.load_definition(installed)
	check(assembly.begin_insertion("wall") and assembly.advance_insertion("wall",5), "obstacle installed by real manual assembly API")
	check(assembly.states.wall == "locked", "installed obstacle permanently locked")
	check(not assembly.set_part_pose("moving",at_pose(3)), "drag cannot cross installed non-fixed piece")
	fixture.parts[1].insertion_path = [[-3,0,0],[4,0,0]]
	assembly.load_definition(fixture)
	check(not assembly.begin_insertion("moving"), "configured route crossing solid fails preflight")
	check(assembly.moving.is_empty() and assembly.states.moving == "free", "blocked path never starts motion")
	fixture.parts[1].assembled_position = [3,0,0]
	fixture.parts[1].insertion_path = [[-3,0,0],[-3,2,0],[3,2,0],[3,0,0]]
	assembly.load_definition(fixture)
	check(assembly.begin_insertion("moving"), "safe multisegment detour engages")
	check(assembly.advance_insertion("moving",9.5), "large forward stroke traverses both detour corners")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(3,0.5,0)), "forward stroke reaches exact distance")
	check(assembly.advance_insertion("moving",-9), "large reverse stroke retraces both corners before lock")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(-3,0.5,0)), "reverse stroke reaches exact distance")
	# Explicit test setup moves a fixed obstacle after preflight. User APIs do not permit this.
	assembly.parts.wall.transform = at_pose(0,2)
	var paused: Transform3D = assembly.parts.moving.transform
	var progress_before: float = assembly.progress.moving
	check(not assembly.advance_insertion("moving",9), "per-input guard catches obstacle introduced after calibration")
	check(assembly.parts.moving.transform.is_equal_approx(paused) and is_equal_approx(assembly.progress.moving,progress_before), "blocked multisegment input commits neither first segment nor progress")
	assembly.parts.wall.transform = Transform3D.IDENTITY
	check(assembly.advance_insertion("moving",9), "restored clear route permits forward motion")
	assembly.parts.wall.transform = at_pose(0,2)
	paused = assembly.parts.moving.transform
	progress_before = assembly.progress.moving
	check(not assembly.advance_insertion("moving",-9), "per-input guard also checks reverse traversal")
	check(assembly.parts.moving.transform.is_equal_approx(paused) and is_equal_approx(assembly.progress.moving,progress_before), "blocked reverse retains last safe pose and distance")
	assembly.parts.wall.transform = Transform3D.IDENTITY
	assembly.cancel_motion()
	await create_timer(0.3).timeout
	check(assembly.parts.moving.transform.is_equal_approx(paused) and is_equal_approx(assembly.progress.moving,progress_before), "pause never rewinds or advances across obstacle")
	check(assembly.begin_insertion("moving") and assembly.advance_insertion("moving",-9), "reengagement can manually retrace checked corners")
	check(assembly.advance_insertion("moving",-100), "reverse beyond entrance withdraws before lock")
	check(assembly.states.moving == "free" and assembly.parts.moving.position.is_equal_approx(Vector3(-3,0,0)), "withdrawal ends at exact entrance, never scattered-position teleport")
	check(assembly.begin_insertion("moving") and assembly.advance_insertion("moving",100), "fresh complete stroke follows safe detour")
	check(assembly.parts.moving.transform.is_equal_approx(assembly.assembled_pose("moving")), "final detour exact assembled pose")
	check(not assembly.advance_insertion("moving",-100) and not assembly.remove_part("moving",true), "final detour lock denies reverse/removal bypass")
	# Wrong connector geometry must not be silently corrected at completion.
	fixture.parts[1].connector_rotation = [0,15,0]
	fixture.parts[1].socket_rotation = [0,0,0]
	assembly.load_definition(fixture)
	check(not assembly.begin_insertion("moving"), "connector/path orientation mismatch rejected")
	assembly.distance_tolerance = 0.8
	assembly.capture_distance = 1.25

func run() -> void:
	var started := Time.get_ticks_msec()
	test_guard()
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	var assembly := Assembly.new()
	root.add_child(assembly)
	test_catalog(assembly,catalog)
	test_real_approach(assembly,catalog)
	await test_controller_fixtures(assembly)
	assembly.free()
	print("JOINERY COLLISION TESTS: %d passed, %d failed; %d ms" % [passed,failed,Time.get_ticks_msec()-started])
	quit(0 if failed == 0 else 1)
