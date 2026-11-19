extends SceneTree
const Assembly = preload("res://components/teaching/assembly/assembly.gd")
const Interaction = preload("res://components/teaching/assembly/interaction.gd")
var passed := 0
var failed := 0

func check(value: bool, description: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("CAMERA: " + description)

func _initialize() -> void:
	call_deferred("run")

# Independent reference: mesh instance transforms are recovered from the scene,
# then substituted into assembled poses. Never reuse the orbit implementation.
func corners(assembly: JoineryAssembly, assembled: bool, world: bool = true) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for id in assembly.parts:
		var part: Node3D = assembly.parts[id]
		for visual in part.find_children("*", "MeshInstance3D", true, false):
			if visual.mesh == null: continue
			var mesh_in_part: Transform3D = part.global_transform.affine_inverse() * visual.global_transform
			var pose: Transform3D = assembly.assembled_pose(id) if assembled else part.transform
			var transform := pose * mesh_in_part
			if world: transform = assembly.global_transform * transform
			var bounds: AABB = visual.mesh.get_aabb()
			for index in range(8): result.append(transform * bounds.get_endpoint(index))
	return result

func expected_target(assembly: JoineryAssembly) -> Vector3:
	var points := corners(assembly, true, false)
	if points.is_empty(): return assembly.global_position
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for point in points:
		low = low.min(point)
		high = high.max(point)
	return assembly.to_global((low + high) * 0.5)

func assert_pivot(input: JoineryInteraction, description: String) -> void:
	var orbit = input.orbit
	var expected := expected_target(input.assembly)
	check(orbit.target.distance_to(expected) < 0.0001, description + ": assembled world pivot")
	check(absf(input.camera.global_position.distance_to(expected) - orbit.distance) < 0.0002, description + ": geometric orbit radius")
	check(input.camera.global_basis.z.dot((input.camera.global_position - expected).normalized()) > 0.99999, description + ": optical axis targets true pivot")
	var screen := input.camera.unproject_position(expected)
	var size := input.camera.get_viewport().get_visible_rect().size
	check(absf(screen.x / size.x - orbit.screen_center_x) < 0.00001, description + ": horizontal composition independent of pivot")
	check(absf(screen.y / size.y - 0.5) < 0.00001, description + ": vertical composition remains centered")

func assert_framed(input: JoineryInteraction, description: String) -> void:
	var size := input.camera.get_viewport().get_visible_rect().size
	var center: float = input.orbit.screen_center_x
	var half_width := minf(center, 1.0 - center)
	var left := (center - half_width) * size.x
	var right := (center + half_width) * size.x
	for assembled in [false, true]:
		var visible := true
		for point in corners(input.assembly, assembled):
			var projected := input.camera.unproject_position(point)
			visible = visible and not input.camera.is_position_behind(point)
			visible = visible and projected.x >= left - 0.1 and projected.x <= right + 0.1
			visible = visible and projected.y >= -0.1 and projected.y <= size.y + 0.1
			var depth := (point - input.camera.get_camera_transform().origin).dot(-input.camera.global_basis.z)
			visible = visible and depth >= input.camera.near and depth <= input.camera.far
		check(visible, description + (": assembled bounds fit" if assembled else ": all loose bounds fit outside sidebar"))

func motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event

func run() -> void:
	root.size = Vector2i(1440, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var assembly := Assembly.new()
	stage.add_child(assembly)
	var camera := Camera3D.new()
	camera.fov = 42.0
	stage.add_child(camera)
	var input := Interaction.new()
	stage.add_child(input)
	input.configure(assembly, camera)
	input.orbit.screen_center_x = 0.63
	check(input.orbit.get_parent() == input, "interaction owns orbit node lifecycle")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	check(catalog.size() == 9, "test every catalog model")
	await process_frame
	for cycle in range(3):
		for definition in catalog:
			assembly.load_definition(definition)
			input.orbit.yaw = 0.68
			input.orbit.pitch = 0.42
			input.fit_model()
			var label := "%s switch cycle %d" % [definition.id, cycle]
			assert_pivot(input, label)
			assert_framed(input, label)
			var original_pivot: Vector3 = input.target
			var original_distance: float = input.distance
			input.fit_model()
			check(absf(input.distance - original_distance) < 0.0001, label + ": repeated fit is deterministic")
			for step in range(8):
				input.yaw += 0.83
				input.pitch = [-1.1, -0.45, 0.0, 0.42, 0.9, 1.28, 0.63, -0.2][step]
				input.distance *= 0.82 if step % 2 == 0 else 1.23
				input.update_camera()
				assert_pivot(input, label + ": orbit/zoom %d" % step)
				check(input.target.distance_to(original_pivot) < 0.0001, label + ": no pivot drift after orbit/zoom")
				input.fit_model()
				assert_framed(input, label + ": orbit refit %d" % step)
			assembly.reset()
			input.yaw = 0.68
			input.pitch = 0.42
			input.fit_model()
			check(absf(input.distance - original_distance) < 0.0001, label + ": reset/refit restores framing")

	# Model coordinates need not be centered or axis-aligned. Include a nested
	# mesh-local transform and distant loose pieces to catch origin/scatter bias.
	var fixture: Dictionary = catalog[0].duplicate(true)
	for index in range(fixture.parts.size()):
		fixture.parts[index].assembled_position = [8.0 + index * 2.0, 4.0, -6.0]
		fixture.parts[index].assembled_rotation = [15.0 + index * 20.0, 35.0, 10.0]
		fixture.parts[index].start_position = [-25.0 + index * 60.0, 18.0, 12.0]
	assembly.load_definition(fixture)
	var body: Node3D = assembly.parts[fixture.parts[1].id]
	var wood: MeshInstance3D = body.get_node("Wood")
	var nested := Node3D.new()
	body.add_child(nested)
	nested.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.6, -0.1)), Vector3(1.1, 0.3, -0.5))
	wood.reparent(nested, false)
	wood.position = Vector3(0.2, -0.1, 0.4)
	input.fit_model()
	assert_pivot(input, "nonzero assembled poses and nested mesh")
	assert_framed(input, "distant scattered fixture")
	var local_center := assembly.to_local(input.target)
	check(local_center.length() > 5.0, "fixture rejects accidental origin-centered pivot")
	for transform_index in range(4):
		stage.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.35, -0.12)), Vector3(-4, 2, 8))
		assembly.transform = Transform3D(Basis.from_euler(Vector3(0.25, 0.7 * transform_index, -0.2)).scaled(Vector3(1.2, 0.8, 1.6)), Vector3(15.0 + transform_index * 2.0, 3.0, -7.0))
		input.update_camera()
		check(input.target.distance_to(assembly.to_global(local_center)) < 0.0002, "assembly transform moves world pivot without refit")
		assert_pivot(input, "transformed assembly %d" % transform_index)
		input.fit_model()
		assert_framed(input, "transformed assembly %d" % transform_index)

	stage.transform = Transform3D.IDENTITY
	assembly.transform = Transform3D.IDENTITY
	assembly.load_definition(catalog[0])
	input.yaw = 0.68
	input.pitch = 0.42
	for placement in [0.5, 0.63, 0.32, 0.85]:
		input.orbit.screen_center_x = placement
		for aspect_mode in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
			camera.keep_aspect = aspect_mode
			input.fit_model()
			assert_pivot(input, "composition %.2f aspect mode %d" % [placement, aspect_mode])
			assert_framed(input, "composition %.2f aspect mode %d" % [placement, aspect_mode])
	input.orbit.screen_center_x = 0.63
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	for resolution in [Vector2i(900, 1440), Vector2i(1920, 800), Vector2i(1440, 900)]:
		root.size = resolution
		await process_frame
		assert_pivot(input, "resized viewport offset updates automatically")
		input.fit_model()
		assert_framed(input, "resized viewport refit")

	# Real interaction dispatch: moving a loose part or advancing its guide must
	# never move the orbit center, camera, or zoom to follow that individual part.
	var id: String = catalog[0].parts[1].id
	assembly.reset()
	input.fit_model()
	var stable_pivot: Vector3 = input.target
	var stable_camera := camera.global_transform
	var loose_before: Transform3D = assembly.parts[id].transform
	var start := camera.unproject_position(assembly.parts[id].global_position)
	var entry_screen := camera.unproject_position(assembly.to_global(assembly.entrance_pose(id).origin))
	var away := (start - entry_screen).normalized() * 80.0
	check(input.begin_drag(id, start), "free pointer drag begins")
	input._unhandled_input(motion(start + away, away))
	check(not assembly.parts[id].transform.is_equal_approx(loose_before), "free pointer drag actually moves a piece")
	check(not assembly.is_guided(id), "free fixture stays outside capture radius")
	input.update_camera()
	check(input.target.distance_to(stable_pivot) < 0.0001, "free drag never recenters pivot")
	check(camera.global_transform.is_equal_approx(stable_camera), "free drag never moves camera")
	input.release()
	assert_pivot(input, "free drag release")
	input.fit_model()
	check(input.target.distance_to(stable_pivot) < 0.0001, "refit after free drag changes distance only")
	assert_framed(input, "refit after free drag")
	assembly.reset()
	input.fit_model()
	check(assembly.set_part_pose(id, assembly.entrance_pose(id)), "guided fixture reaches entry safely")
	check(assembly.begin_manual(id), "guided fixture engages manual path")
	start = camera.unproject_position(assembly.parts[id].global_position)
	check(input.begin_drag(id, start), "guided pointer drag begins")
	var finish := camera.unproject_position(assembly.to_global(assembly.assembled_pose(id).origin))
	var along := (finish - start) * 0.2
	stable_camera = camera.global_transform
	input._unhandled_input(motion(start + along, along))
	check(float(assembly.progress.get(id, 0.0)) > 0.0, "guided pointer drag advances path")
	check(assembly.is_guided(id), "guided drag remains partially assembled")
	input.update_camera()
	check(input.target.distance_to(stable_pivot) < 0.0001, "guided drag never recenters pivot")
	check(camera.global_transform.is_equal_approx(stable_camera), "guided drag never moves camera")
	input.release()
	var stopped: Transform3D = assembly.parts[id].transform
	await process_frame
	check(assembly.parts[id].transform.is_equal_approx(stopped), "release does not animate guided piece")
	assert_pivot(input, "guided drag pause")
	input.mode = "orbit"
	input._unhandled_input(motion(Vector2(900, 300), Vector2(55, -20)))
	input.release()
	assert_pivot(input, "actual orbit dispatch after guided release")
	check(input.target.distance_to(stable_pivot) < 0.0001, "orbit after guided drag preserves assembled pivot")
	assembly.reset()
	input.fit_model()
	assert_pivot(input, "final reset/refit")
	assert_framed(input, "final reset/refit")
	stage.free()
	print("JOINERY CAMERA TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
