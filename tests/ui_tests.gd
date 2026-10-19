extends SceneTree
var failed := 0
var passed := 0
func check(value: bool, description: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var demo = load("res://demo/workshop.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	check(demo.catalog.size() == 9, "nine menu entries")
	for index in range(demo.catalog.size()):
		demo.load_joint(index)
		await process_frame
		check(demo.part_list.item_count == demo.catalog[index].parts.size(), "all parts in selector")
	check(demo.status.get_global_rect().end.y < 900, "UI must fit default viewport")
	# Real event dispatch through Viewport: controls must consume the press.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = demo.picker.get_global_rect().get_center()
	root.push_input(press)
	await process_frame
	check(demo.interaction.mode == "idle", "UI press must not orbit/drag world")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	# Start orbit away from geometry, then release on UI.
	press.position = Vector2(1400,850)
	root.push_input(press)
	await process_frame
	check(demo.interaction.mode == "orbit", "blank press starts orbit")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(50,100)
	root.push_input(release)
	await process_frame
	check(demo.interaction.mode == "idle", "release over UI ends orbit")
	var id: String = demo.assembly.selected
	var initial: Transform3D = demo.assembly.parts[id].transform
	check(demo.interaction.begin_drag(id,Vector2(1200,800)), "part drag starts for UI release check")
	var displaced := initial
	displaced.origin += Vector3(0.2,0,0)
	demo.assembly.set_part_pose(id,displaced)
	var over_panel := InputEventMouseMotion.new()
	over_panel.position = Vector2(50,100)
	root.push_input(over_panel)
	await process_frame
	root.push_input(release)
	await process_frame
	check(demo.interaction.mode == "idle" and demo.assembly.parts[id].transform.is_equal_approx(initial), "release over UI cancels part drag without snapping")
	demo.interaction.mode = "orbit"
	demo.interaction.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(demo.interaction.mode == "idle", "focus loss clears input mode")
	demo.free()
	print("JOINERY UI TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
