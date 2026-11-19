extends SceneTree
const Assembly = preload("res://components/teaching/assembly/assembly.gd")
const Interaction = preload("res://components/teaching/assembly/interaction.gd")
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var assembly := Assembly.new()
	root.add_child(assembly)
	var camera := Camera3D.new()
	root.add_child(camera)
	var input := Interaction.new()
	root.add_child(input)
	input.configure(assembly,camera)
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	var fixture: Dictionary = data[0].duplicate(true)
	var id := "tail"
	fixture.parts[0].assembled_position = [0,-100,0]
	fixture.parts[1].start_position = [3,3,0]
	fixture.parts[1].start_rotation = [0,0,0]
	fixture.parts[1].insertion_path = [[3,3,0],[0,3,0],[0,0,0]]
	assembly.load_definition(fixture)
	check(assembly.begin_manual(id), "engage corner fixture")
	input.yaw = 0.68
	input.pitch = 0.42
	input.update_camera()
	check(input.begin_drag(id,camera.unproject_position(assembly.parts[id].global_position)), "corner regrab")
	input.grab_local = Vector3.ZERO
	var first := camera.unproject_position(Vector3(3,3,0))
	var corner := camera.unproject_position(Vector3(0,3,0))
	input._drag_on_path((corner-first) * 10.0)
	check(is_equal_approx(assembly.progress[id],3.0), "huge input stops at bend instead of moving unchosen outgoing segment")
	input._drag_on_path((first-corner) * 0.5)
	check(is_equal_approx(assembly.progress[id],1.5), "reverse at corner follows incoming segment")
	input._drag_on_path((corner-first) * 0.5)
	var end := camera.unproject_position(Vector3.ZERO)
	input._drag_on_path((end-corner) * 0.4)
	check(is_equal_approx(assembly.progress[id],4.2), "next stroke chooses outgoing segment")
	input.release()
	var parked: Transform3D = assembly.parts[id].transform
	await create_timer(0.1).timeout
	check(assembly.parts[id].transform.is_equal_approx(parked), "corner path release parks")
	# Exact end-on projection uses the documented up/down mapping.
	assembly.load_definition(data[0])
	assembly.set_part_pose(id,assembly.entrance_pose(id))
	assembly.begin_manual(id)
	input.yaw = 0.0
	input.orbit.screen_center_x = 0.5
	input.pitch = 0.0
	input.update_camera()
	input.begin_drag(id,camera.unproject_position(assembly.parts[id].global_position))
	input.grab_local = Vector3.ZERO
	input._drag_on_path(Vector2(0,-12))
	check(assembly.progress[id] > 0.0 and assembly.is_guided(id), "end-on upward drag advances safely")
	var progress_before: float = assembly.progress[id]
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom := input.distance
	input._unhandled_input(wheel)
	check(is_equal_approx(input.distance,zoom), "wheel cannot change drag projection while held")
	input._drag_on_path(Vector2(0,6))
	check(assembly.progress[id] < progress_before, "end-on downward drag reverses")
	input.cancel()
	input.begin_drag(id,camera.unproject_position(assembly.parts[id].global_position))
	assembly.reset()
	check(input.mode == "idle", "API reset clears pointer ownership")
	input.free()
	camera.free()
	assembly.free()
	print("INPUT EDGE TESTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
