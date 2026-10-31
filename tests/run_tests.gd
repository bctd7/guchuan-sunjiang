extends SceneTree
const Assembly = preload("res://core/assembly.gd")
const Interaction = preload("res://core/interaction.gd")
const InsertionPath = preload("res://core/insertion_path.gd")
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

func check_unchanged(assembly: Node3D, id: String, before: Transform3D, progress_before: float, label: String) -> void:
	check(assembly.parts[id].transform.is_equal_approx(before), label + ": pose unchanged")
	check(is_equal_approx(float(assembly.progress[id]), progress_before), label + ": progress unchanged")

func check_locked(assembly: Node3D, id: String, label: String) -> void:
	var before: Transform3D = assembly.parts[id].transform
	check(assembly.states[id] == "locked" and assembly.occupied.has(id), label + ": permanently occupied")
	check(not assembly.is_editable(id) and not assembly.is_guided(id), label + ": no mutable state")
	check(not assembly.set_part_pose(id, Transform3D.IDENTITY), label + ": pose input rejected")
	check(not assembly.rotate_part(id, Vector3.UP, 0.2), label + ": rotation rejected")
	check(not assembly.advance_insertion(id, -100.0), label + ": reverse input rejected")
	check(not assembly.begin_insertion(id) and not assembly.insert_part(id, true), label + ": reengagement rejected")
	check(not assembly.can_remove(id), label + ": removal unavailable")
	check(not assembly.remove_part(id) and not assembly.remove_part(id, true), label + ": both removal APIs rejected")
	assembly.cancel_motion()
	check(assembly.parts[id].transform.is_equal_approx(before), label + ": all rejected input retains pose")

func fixture(points: Array = [[3,3,0],[0,3,0],[0,0,0]]) -> Dictionary:
	return {"id":"manual_fixture", "name":"Manual fixture", "parts":[
		{"id":"moving", "mesh":"user://manual_test_box.tres", "fixed":false,
		"assembled_position":points[-1], "start_position":points[0],
		"insertion_path":points, "dependencies":[]}
	]}

func test_path_math() -> void:
	var path := InsertionPath.new([[3,3,0],[3,3,0],[0,3,0],[0,0,0]])
	check(path.valid() and is_equal_approx(path.length, 6.0), "polyline deduplicates repeated points and measures arc length")
	check(path.points.size() == 3, "duplicate path points removed")
	check(path.sample(-100).is_equal_approx(Vector3(3,3,0)), "path sample clamps before entry")
	check(path.sample(100).is_equal_approx(Vector3.ZERO), "path sample clamps beyond end")
	check(path.sample(1.5).is_equal_approx(Vector3(1.5,3,0)), "first-segment interpolation")
	check(path.sample(4.5).is_equal_approx(Vector3(0,1.5,0)), "second-segment interpolation")
	check(path.tangent(0).is_equal_approx(Vector3.LEFT), "entry tangent")
	check(path.tangent(3).is_equal_approx(Vector3.DOWN), "corner uses next segment tangent")
	check(path.tangent(6).is_equal_approx(Vector3.DOWN), "final tangent")
	var forward: Array[Vector3] = path.traversal(1.0, 5.0)
	check(forward.size() == 2 and forward[0].is_equal_approx(Vector3(0,3,0)) and forward[1].is_equal_approx(Vector3(0,1,0)), "forward traversal retains crossed corner")
	var reverse: Array[Vector3] = path.traversal(5.0, 1.0)
	check(reverse.size() == 2 and reverse[0].is_equal_approx(Vector3(0,3,0)) and reverse[1].is_equal_approx(Vector3(2,3,0)), "reverse traversal retains crossed corner")
	check(path.traversal(3.0,3.0).size() == 1, "zero traversal has one stable sample")
	check(not InsertionPath.new([]).valid(), "empty path invalid")
	check(not InsertionPath.new([[0,0,0],[0,0,0]]).valid(), "zero-length path invalid")

func test_catalog(assembly: Node3D, catalog: Array) -> void:
	var models := 0
	var movable := 0
	for definition in catalog:
		assembly.load_definition(definition)
		check(assembly.parts.size() == definition.parts.size(), definition.id + ": all parts loaded")
		var free_ids: Array = []
		for spec in definition.parts:
			models += 1
			check(assembly.parts[spec.id].get_node("Wood").mesh.get_faces().size() > 0, spec.id + ": real triangle geometry")
			if spec.get("fixed", false):
				check_locked(assembly, spec.id, definition.id + " fixed " + spec.id)
				continue
			movable += 1
			free_ids.append(spec.id)
			check(spec.insertion_path.size() >= 2, "path has entry and end")
			check(Assembly.vector(spec.insertion_path[-1]).is_equal_approx(Assembly.vector(spec.assembled_position)), "path terminates at assembled pose")
			check(assembly.paths[spec.id].valid(), "movable path has positive length")
			check(not assembly.can_remove(spec.id) and not assembly.remove_part(spec.id), "free part cannot invoke legacy removal")
			var has_unlocked_dependency := false
			for dependency in spec.get("dependencies", []):
				if assembly.states[dependency] != "locked": has_unlocked_dependency = true
			if has_unlocked_dependency:
				# Predicate fixture only: dependency rejection precedes proximity checks.
				var original: Transform3D = assembly.parts[spec.id].transform
				assembly.parts[spec.id].transform = assembly.entrance_pose(spec.id)
				check(assembly.candidate(spec.id).reason == "dependency", "unlocked dependency rejected")
				check(not assembly.begin_insertion(spec.id), "cannot engage guide out of order")
				assembly.parts[spec.id].transform = original
		var pending := free_ids.duplicate()
		for _round in range(free_ids.size()):
			for id in pending.duplicate():
				var ready := true
				for dependency in assembly.specs[id].get("dependencies", []):
					if assembly.states[dependency] != "locked": ready = false
				if not ready: continue
				check(assembly.set_part_pose(id, assembly.entrance_pose(id)), "collision-safe catalog approach " + id)
				check(assembly.candidate(id).ok, "catalog entry eligible " + id)
				check(assembly.insert_part(id, true), "legacy instant flag only calibrates " + id)
				check(assembly.is_guided(id) and is_zero_approx(float(assembly.progress[id])), "guide starts at zero " + id)
				check(assembly.parts[id].transform.is_equal_approx(assembly.entrance_pose(id)), "engagement does not insert " + id)
				check(not assembly.occupied.has(id) and assembly.moving.is_empty(), "no occupancy or autonomous motion before final input")
				check(not assembly.set_part_pose(id, Transform3D.IDENTITY) and not assembly.rotate_part(id, Vector3.UP, 0.2), "guide forbids off-path editing")
				var length: float = assembly.paths[id].length
				check(assembly.advance_insertion(id, length * 0.2), "manual partial input " + id)
				check(assembly.is_guided(id) and is_equal_approx(float(assembly.progress[id]), length * 0.2), "partial remains unlocked")
				for cycle in range(3):
					check(assembly.advance_insertion(id, length * 0.1), "repeat forward stroke %d" % cycle)
					var paused: Transform3D = assembly.parts[id].transform
					var paused_progress: float = assembly.progress[id]
					assembly.cancel_motion()
					check(assembly.is_guided(id), "pause preserves guided state")
					check_unchanged(assembly, id, paused, paused_progress, "pause")
					check(assembly.begin_insertion(id) and assembly.insert_part(id, true), "repeat API engagement preserves stroke")
					check_unchanged(assembly, id, paused, paused_progress, "reengage")
					check(assembly.advance_insertion(id, -length * 0.05), "reverse before final lock")
					check(assembly.parts[id].position.is_equal_approx(assembly.paths[id].sample(assembly.progress[id])), "position equals model-distance sample")
				check(not assembly.occupied.has(id), "reversed partial stroke never occupies socket")
				check(assembly.advance_insertion(id, length * 100), "large manual stroke clamps to path end")
				check(is_equal_approx(float(assembly.progress[id]), length), "final progress clamps exactly")
				check(assembly.parts[id].transform.is_equal_approx(assembly.assembled_pose(id)), "final exact pose")
				check_locked(assembly, id, definition.id + " completed " + id)
				check(assembly.candidate(id).reason == "occupied", "occupied rejection")
				pending.erase(id)
		check(pending.is_empty(), definition.id + ": dependencies resolvable by manual API")
		assembly.reset()
		for spec in definition.parts:
			if not spec.get("fixed", false):
				check(assembly.states[spec.id] == "free" and not assembly.occupied.has(spec.id), "reset unlocks movable part")
				check(assembly.parts[spec.id].position.is_equal_approx(Assembly.vector(spec.start_position)), "reset restores scattered pose")
		check(assembly.progress.is_empty() and assembly.moving.is_empty(), "reset clears every progress entry")
	check(models == 21 and movable == 12, "nine variants cover all 21 models and 12 movable parts")

func test_candidates(assembly: Node3D, first: Dictionary) -> void:
	assembly.load_definition(first)
	var id: String = first.parts[1].id
	check(is_equal_approx(assembly.distance_tolerance,0.8) and is_equal_approx(assembly.angle_tolerance_degrees,30.0), "generous default 0.8 unit / 30 degree calibration")
	var value: Transform3D = assembly.entrance_pose(id)
	assembly.parts[id].transform = value
	check(assembly.candidate(id).ok, "correct entry accepted")
	value.origin.x += assembly.distance_tolerance + 0.01
	assembly.parts[id].transform = value
	check(assembly.candidate(id).reason == "distance", "outside distance tolerance rejected")
	value.origin.x -= 0.02
	assembly.parts[id].transform = value
	check(assembly.candidate(id).ok, "inside distance tolerance accepted")
	value = assembly.entrance_pose(id)
	value.basis = Basis(Vector3.UP, deg_to_rad(assembly.angle_tolerance_degrees + 0.1)) * value.basis
	# These direct assignments isolate the matching predicate, not physical movement.
	assembly.parts[id].transform = value
	check(assembly.candidate(id).reason == "angle", "outside angular tolerance rejected")
	value = assembly.entrance_pose(id)
	value.basis = Basis(Vector3.UP, deg_to_rad(assembly.angle_tolerance_degrees - 0.1)) * value.basis
	assembly.parts[id].transform = value
	check(assembly.candidate(id).ok, "inside angular tolerance accepted")
	for other in assembly.parts:
		if other != id: check(assembly.candidate(id, other).reason == "pair", "wrong pair rejection")
	check(assembly.candidate("missing").reason == "unknown", "unknown candidate rejected")
	check(not assembly.begin_insertion("missing") and not assembly.advance_insertion("missing",1), "unknown manual API rejected")
	check(not assembly.can_remove("missing") and not assembly.remove_part("missing"), "unknown removal rejected")
	var custom := first.duplicate(true)
	for spec in custom.parts:
		if spec.id == id:
			spec.connector_position = [0.2,0.3,0.1]
			spec.connector_rotation = [0,15,0]
			var socket: Transform3D = Assembly.pose(spec.insertion_path[0]) * Assembly.pose(spec.connector_position, spec.connector_rotation)
			spec.socket_position = [socket.origin.x,socket.origin.y,socket.origin.z]
			spec.socket_rotation = [0,15,0]
	assembly.load_definition(custom)
	check(assembly.set_part_pose(id, assembly.entrance_pose(id)), "connector fixture safe approach")
	check(assembly.candidate(id).ok and assembly.snap(id), "local connector offset and orientation snap")
	check(assembly.parts[id].transform.is_equal_approx(assembly.entrance_pose(id)), "connector snap preserves correct body pose")
	check(assembly.begin_insertion(id) and assembly.advance_insertion(id, assembly.paths[id].length), "offset connector still permits exact manual route")

func test_manual_edges(assembly: Node3D, first: Dictionary) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.3
	check(ResourceSaver.save(mesh,"user://manual_test_box.tres") == OK, "save deterministic manual fixture")
	assembly.load_definition(fixture())
	check(not assembly.advance_insertion("moving",1), "unengaged motion rejected")
	check(assembly.begin_insertion("moving"), "corner fixture guide engaged")
	var before: Transform3D = assembly.parts.moving.transform
	check(assembly.advance_insertion("moving",0), "zero entry input is safe")
	check_unchanged(assembly,"moving",before,0.0,"zero input")
	check(assembly.advance_insertion("moving",-100), "negative entry input disengages safely")
	check(assembly.is_editable("moving") and not assembly.progress.has("moving") and assembly.parts.moving.transform.is_equal_approx(before), "withdrawal becomes free at exact entrance without teleport")
	check(assembly.begin_insertion("moving"), "withdrawn guide can reengage")
	check(not assembly.advance_insertion("moving",NAN) and not assembly.advance_insertion("moving",INF) and not assembly.advance_insertion("moving",-INF), "non-finite progress refused")
	check_unchanged(assembly,"moving",before,0.0,"invalid input")
	check(assembly.advance_insertion("moving",4.5), "single stroke traverses a corner")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(0,1.5,0)), "multisegment forward exact point")
	check(assembly.advance_insertion("moving",-3), "reverse stroke traverses corner before final")
	check(assembly.parts.moving.position.is_equal_approx(Vector3(1.5,3,0)), "multisegment reverse exact point")
	var paused: Transform3D = assembly.parts.moving.transform
	assembly.cancel_motion()
	await create_timer(0.25).timeout
	check_unchanged(assembly,"moving",paused,1.5,"time elapsed after pause")
	check(assembly.is_guided("moving"), "timed wait never auto-completes guided stroke")
	assembly.begin_insertion("moving")
	await create_timer(0.25).timeout
	check_unchanged(assembly,"moving",paused,1.5,"time elapsed after reengagement")
	check(assembly.advance_insertion("moving",100), "manual final stroke completes")
	check_locked(assembly,"moving","synthetic final lock")
	assembly.reset()
	check(assembly.begin_insertion("moving") and assembly.advance_insertion("moving",1), "new round can reengage")
	assembly.load_definition(first)
	await create_timer(0.1).timeout
	check(not assembly.parts.has("moving") and assembly.progress.is_empty() and assembly.moving.is_empty(), "model switch clears prior guided work without stale callbacks")
	var first_id: String = first.parts[1].id
	check(assembly.states[first_id] == "free", "model switch starts fresh movable state")
	var invalid := fixture([[0,0,0],[0,0,0]])
	assembly.load_definition(invalid)
	check(not assembly.begin_insertion("moving") and assembly.states.moving == "free", "zero-length route cannot silently lock")
	invalid = fixture()
	invalid.parts[0].assembled_position = [1,0,0]
	assembly.load_definition(invalid)
	check(not assembly.begin_insertion("moving"), "mismatched path endpoint rejected rather than teleported")

func test_instances(assembly: Node3D, first: Dictionary) -> void:
	assembly.load_definition(first)
	var id: String = first.parts[1].id
	var instance := Assembly.new()
	root.add_child(instance)
	instance.transform = Transform3D(Basis(Vector3.UP,0.6),Vector3(25,0,0))
	instance.load_definition(first)
	check(assembly.set_part_pose(id,assembly.entrance_pose(id)), "first instance approach")
	check(instance.set_part_pose(id,instance.entrance_pose(id)), "second transformed instance approach")
	check(assembly.begin_insertion(id) and assembly.advance_insertion(id,assembly.paths[id].length), "first instance completes manually")
	check(instance.candidate(id).ok, "instance occupancy isolated")
	check(instance.parts[id].global_position.distance_to(assembly.parts[id].global_position) > 15, "instance transform isolated")
	check(instance.begin_insertion(id) and instance.advance_insertion(id,instance.paths[id].length), "transformed instance completes manually")
	assembly.reset()
	check(instance.states[id] == "locked", "reset instance isolation")
	instance.free()

func test_interaction_invariants(assembly: Node3D, first: Dictionary) -> void:
	assembly.load_definition(first)
	var id: String = first.parts[1].id
	var view := Camera3D.new()
	root.add_child(view)
	var input := Interaction.new()
	root.add_child(input)
	input.configure(assembly,view)
	var isolated := Assembly.new()
	root.add_child(isolated)
	isolated.load_definition(first)
	check(input.owns_collider(assembly.parts[id]), "own collider accepted")
	check(not input.owns_collider(isolated.parts[id]), "same ID in another instance rejected")
	check(input.begin_drag(id,Vector2(200,200)), "free drag starts via adapter API")
	check(not input.begin_drag(id,Vector2(300,300)), "second simultaneous drag rejected")
	input.cancel()
	check(input.mode == "idle", "cancel clears adapter mode")
	assembly.transform = Transform3D(Basis(Vector3.UP,0.7),Vector3(2,1,0))
	check(input.begin_drag(id,Vector2(240,220)), "transformed instance drag starts")
	var movement := InputEventMouseMotion.new()
	# A small world-space fixture stays collision-free at every framing distance.
	var press_hit = input.drag_plane.intersects_ray(view.project_ray_origin(Vector2(240,220)),view.project_ray_normal(Vector2(240,220)))
	var intended_hit: Vector3 = press_hit + view.global_basis.x * .02 + view.global_basis.y * .015
	movement.position = view.unproject_position(intended_hit)
	movement.relative = movement.position - Vector2(240,220)
	var expected_hit = input.drag_plane.intersects_ray(view.project_ray_origin(movement.position),view.project_ray_normal(movement.position))
	var expected_local: Vector3 = assembly.to_local(expected_hit + input.drag_offset)
	var yaw_before: float = input.yaw
	input._unhandled_input(movement)
	check(assembly.parts[id].position.is_equal_approx(expected_local), "mouse-motion handler maps world plane to transformed local pose")
	check(is_equal_approx(input.yaw,yaw_before), "free drag and orbit are mutually exclusive")
	input.cancel()
	assembly.transform = Transform3D.IDENTITY
	var other_input := Interaction.new()
	root.add_child(other_input)
	other_input.configure(isolated,view)
	check(not other_input.keyboard_active and input.keyboard_active, "single initial keyboard owner")
	other_input.activate()
	check(other_input.keyboard_active and not input.keyboard_active, "activation transfers keyboard ownership")
	input.activate()
	input.mode = "orbit"
	input.release()
	check(input.mode == "idle", "release clears orbit")
	other_input.free()
	isolated.free()
	input.free()
	view.free()

func test_orbit(assembly: Node3D, catalog: Array) -> void:
	var view := Camera3D.new()
	root.add_child(view)
	var input := Interaction.new()
	root.add_child(input)
	input.configure(assembly,view)
	for definition in catalog:
		assembly.load_definition(definition)
		input.fit_model()
		var bounds := AABB()
		var has_bounds := false
		var framing_points: Array[Vector3] = []
		for id in assembly.parts:
			var visual: MeshInstance3D = assembly.parts[id].get_node("Wood")
			var mesh_bounds: AABB = visual.mesh.get_aabb()
			for corner in range(8):
				var local: Vector3 = visual.transform * mesh_bounds.get_endpoint(corner)
				var point: Vector3 = assembly.assembled_pose(id) * local
				if has_bounds: bounds = bounds.expand(point)
				else:
					bounds = AABB(point,Vector3.ZERO)
					has_bounds = true
				framing_points.append(assembly.to_global(point))
				framing_points.append(assembly.parts[id].global_transform * local)
		var expected: Vector3 = assembly.to_global(bounds.get_center())
		check(input.target.is_equal_approx(expected),definition.id + ": orbit pivot is assembled mesh bounds center")
		check(absf(view.unproject_position(input.target).x / root.size.x - input.orbit.screen_center_x) < 0.001,definition.id + ": sidebar composition does not move pivot")
		var framed := true
		for point in framing_points:
			var projected: Vector2 = view.unproject_position(point)
			if view.is_position_behind(point) or projected.x < 0 or projected.x > root.size.x or projected.y < 0 or projected.y > root.size.y:
				framed = false
		check(framed,definition.id + ": loose and assembled bounds fit viewport")
		var id: String = definition.parts[1].id
		# Direct far-away fixture proves loose-piece layout cannot shift the orbit pivot.
		assembly.parts[id].position += Vector3(50,20,-30)
		input.update_camera()
		check(input.target.is_equal_approx(expected),definition.id + ": loose-part movement does not drag orbit center")
		input.yaw += 0.6
		input.pitch = -0.7
		input.distance *= 1.2
		input.update_camera()
		check(input.target.is_equal_approx(expected),definition.id + ": orbit and zoom retain geometric center")
		check(absf(view.global_position.distance_to(input.target) - input.distance) < 0.001,definition.id + ": orbit remains at radial distance")
		check(absf(view.unproject_position(input.target).x / root.size.x - input.orbit.screen_center_x) < 0.001,definition.id + ": composition survives orbit and zoom")
		assembly.transform = Transform3D(Basis(Vector3.UP,0.7),Vector3(8,3,-5))
		input.update_camera()
		check(input.target.is_equal_approx(assembly.to_global(bounds.get_center())),definition.id + ": orbit follows transformed assembly center")
		assembly.transform = Transform3D.IDENTITY
	input.free()
	view.free()

func send_motion(input: Node, movement: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = movement
	event.position = input.last_screen + movement
	input._unhandled_input(event)

func projected_segment(assembly: Node3D, view: Camera3D, start: Vector3, finish: Vector3, grab: Vector3) -> Vector2:
	return view.unproject_position(assembly.to_global(finish + grab)) - view.unproject_position(assembly.to_global(start + grab))

func test_guided_input(assembly: Node3D) -> void:
	assembly.load_definition(fixture())
	var view := Camera3D.new()
	root.add_child(view)
	var input := Interaction.new()
	root.add_child(input)
	input.configure(assembly,view)
	assembly.select_part("moving")
	var grab := Vector3(0.1,0.07,0.05)
	var grab_world: Vector3 = assembly.parts.moving.global_transform * grab
	var pointer: Vector2 = view.unproject_position(grab_world)
	var entry: Transform3D = assembly.parts.moving.transform
	check(input.begin_drag("moving",pointer,grab_world), "real-grab adapter entry starts")
	check(input.grab_local.is_equal_approx(grab), "adapter retains actual local grab position")
	input.release(pointer)
	check(assembly.is_editable("moving") and assembly.parts.moving.transform.is_equal_approx(entry), "click-release without motion does not calibrate or insert")
	var signals := {"locked":0,"disassembled":0,"reset":0}
	var locked_callback := func(_id: String): signals.locked += 1
	var removed_callback := func(_id: String): signals.disassembled += 1
	var reset_callback := func(): signals.reset += 1
	assembly.connection_succeeded.connect(locked_callback)
	assembly.disassembled.connect(removed_callback)
	assembly.reset_completed.connect(reset_callback)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	input._unhandled_input(enter)
	check(assembly.is_guided("moving") and is_zero_approx(float(assembly.progress.moving)), "Enter only calibrates, never auto-inserts")
	check(signals.locked == 0, "calibration emits no connection success")
	var first_segment := projected_segment(assembly,view,Vector3(3,3,0),Vector3(0,3,0),grab)
	var second_segment := projected_segment(assembly,view,Vector3(0,3,0),Vector3.ZERO,grab)
	check(input.begin_drag("moving",pointer,grab_world), "guided piece can be regrabbed")
	send_motion(input,first_segment * 0.4)
	check(is_equal_approx(float(assembly.progress.moving),1.2), "projected pointer motion advances model distance")
	var paused: Transform3D = assembly.parts.moving.transform
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = input.last_screen
	input._input(release)
	check(input.mode == "idle", "mouse release ends guided input ownership")
	await create_timer(0.12).timeout
	check_unchanged(assembly,"moving",paused,1.2,"released pointer wait")
	grab_world = assembly.parts.moving.global_transform * grab
	pointer = view.unproject_position(grab_world)
	check(input.begin_drag("moving",pointer,grab_world), "partial guide regrab starts without jump")
	check_unchanged(assembly,"moving",paused,1.2,"pointer regrab")
	send_motion(input,-first_segment * 0.2)
	check(is_equal_approx(float(assembly.progress.moving),0.6), "pointer can reverse before final lock")
	paused = assembly.parts.moving.transform
	input.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(input.mode == "idle" and assembly.is_guided("moving"), "focus loss pauses guide")
	check_unchanged(assembly,"moving",paused,0.6,"focus loss")
	grab_world = assembly.parts.moving.global_transform * grab
	check(input.begin_drag("moving",view.unproject_position(grab_world),grab_world), "focus-paused guide regrab")
	send_motion(input,first_segment)
	check(is_equal_approx(float(assembly.progress.moving),3.0) and assembly.parts.moving.position.is_equal_approx(Vector3(0,3,0)), "one pointer event stops at corner without cutting")
	send_motion(input,second_segment * 0.5)
	check(is_equal_approx(float(assembly.progress.moving),4.5), "next pointer stroke follows outgoing corner segment")
	paused = assembly.parts.moving.transform
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	input._input(escape)
	check(input.mode == "idle" and assembly.is_guided("moving"), "Escape pauses guided input")
	check_unchanged(assembly,"moving",paused,4.5,"Escape")
	grab_world = assembly.parts.moving.global_transform * grab
	check(input.begin_drag("moving",view.unproject_position(grab_world),grab_world), "Escape-paused guide regrab")
	send_motion(input,-second_segment)
	check(is_equal_approx(float(assembly.progress.moving),3.0), "reverse pointer stroke stops at previous corner")
	send_motion(input,-first_segment * 0.2)
	check(is_equal_approx(float(assembly.progress.moving),2.4), "reverse pointer chooses incoming segment at exact corner")
	send_motion(input,first_segment)
	send_motion(input,second_segment)
	check(assembly.states.moving == "locked" and signals.locked == 1, "final pointer stroke locks and emits success exactly once")
	input.release()
	check(not input.begin_drag("moving",pointer), "permanent lock cannot be regrabbed")
	check(not assembly.advance_manual("moving",-10) and not assembly.remove_part("moving"), "compatibility APIs cannot reverse final lock")
	check(signals.disassembled == 0 and signals.locked == 1, "denied removal never emits disassembly or repeated success")
	assembly.reset()
	check(signals.reset == 1 and assembly.is_editable("moving"), "reset signals and restores free round")
	assembly.connection_succeeded.disconnect(locked_callback)
	assembly.disassembled.disconnect(removed_callback)
	assembly.reset_completed.disconnect(reset_callback)
	input.free()
	view.free()

func run() -> void:
	root.size = Vector2i(1440,900)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	if not catalog is Array or catalog.size() != 9:
		push_error("Expected nine catalog entries")
		quit(1)
		return
	var assembly := Assembly.new()
	root.add_child(assembly)
	test_path_math()
	test_catalog(assembly,catalog)
	test_candidates(assembly,catalog[0])
	await test_manual_edges(assembly,catalog[0])
	test_instances(assembly,catalog[0])
	test_interaction_invariants(assembly,catalog[0])
	test_orbit(assembly,catalog)
	await test_guided_input(assembly)
	assembly.free()
	print("JOINERY TESTS: %d passed, %d failed (manual API and injected adapter events; not human pointer validation)" % [passed,failed])
	quit(0 if failed == 0 else 1)
