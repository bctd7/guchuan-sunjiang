extends SceneTree
## End-to-end acceptance: only real Viewport mouse/touch intents mutate the game.
var level: Node3D
var passed := 0
var failures: Array[String] = []
var completion_count := 0
var return_count := 0
const Rules = preload("res://levels/level03/connection_rules.gd")
const G = preload("res://models/ship/rigging/ship_geometry.gd")
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ",label)
	else:
		failures.append(label)
		push_error("FAIL "+label)
func settle(seconds := .15) -> void:
	await create_timer(seconds).timeout
	await process_frame
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await process_frame
func touch(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle(.5)
func button(control: Button) -> void:
	check(control.is_visible_in_tree() and not control.disabled,"operable GUI "+control.text)
	await click(control.get_global_rect().get_center())
	await settle(.1)
func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/level03_evidence")
	root.get_texture().get_image().save_png("res://tests/level03_evidence/"+label+".png")
func install(id: String, use_touch := false) -> void:
	check(level.state.selected == id,"current ship member "+id)
	check(level.state.candidate.is_empty(),"no default candidate "+id)
	for kind in Rules.candidates(id):
		check(level.panel.gallery.specimens.has(kind),"actual candidate visible before selection "+id+" "+kind)
	await snapshot(id+"-candidates")
	var expected: String = Rules.SPECS[id].joint
	await button(level.panel.candidate_buttons[expected])
	check(level.state.candidate == expected,"candidate click chooses "+expected)
	var point: Vector2 = level.view.socket_screen_position(id)
	check(Rect2(345,190,1075,400).has_point(point),"socket inside scene viewport "+id)
	check(level.view.pick_socket(point) == id,"root-coordinate socket pick "+id)
	var count: int = level.state.placed.size()
	if use_touch: await touch(point)
	else: await click(point)
	check(level.state.placed.size() == count+1,"pointer installs "+id)
	check(level.busy,"installation animates "+id)
	await snapshot(id+"-inserting")
	await settle(1.65)
	check(not level.busy,"animation finishes "+id)
	check(level.view.animations.is_empty(),"animation released "+id)
	await snapshot(id+"-seated")
func run() -> void:
	root.size = Vector2i(1440,900)
	level = load("res://levels/level03/level03.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	level.level_completed.connect(func(): completion_count += 1)
	level.return_requested.connect(func(): return_count += 1)
	await settle(.7)
	check(level.state.placed.is_empty(),"starts with no player-installed pieces")
	check(is_equal_approx(G.BEARING_RADIUS-G.SHAFT_RADIUS,.03),"radial bearing clearance .03")
	var dependency := Rules.evaluate("leg","leg","zong_corner",[],0)
	check(dependency.code == "dependency","corner leg cannot precede horizontal rails")
	var bad_socket := Rules.evaluate("zrail","leg","zong_corner",[],0)
	check(bad_socket.code == "wrong_socket","different socket rejected")
	await click(level.view.socket_screen_position("zrail"))
	check(level.state.last_outcome.code == "unselected","unselected type rejected by real click")
	await button(level.panel.candidate_buttons["l_through"])
	await click(level.view.socket_screen_position("zrail"))
	check(level.state.last_outcome.code == "wrong_joint" and level.state.placed.is_empty(),"wrong type rejects without installation")
	await snapshot("wrong-zong-candidate-rejected")
	# Clear chosen candidate with the real reset button before normal acceptance.
	await button(level.panel.restart_button)
	await install("zrail")
	await click(level.view.socket_screen_position("zrail"))
	check(level.state.last_outcome.code == "duplicate" and level.state.placed.size() == 1,"duplicate click never installs twice")
	await button(level.panel.next_button)
	await install("leg",true)
	await button(level.panel.undo_button)
	check(level.state.selected == "leg" and level.state.placed == ["zrail"],"undo removes corner leg and preserves rail")
	await install("leg")
	await button(level.panel.next_button)
	await install("mast",true)
	await button(level.panel.next_button)
	check(level.state.stage_idx == 1,"next workbench is mast-top clamp")
	await install("apron")
	await button(level.panel.next_button)
	await button(level.panel.inspect_button)
	await snapshot("clamp-top-real-bottom-sockets")
	await button(level.panel.inspect_button)
	await install("top",true)
	await button(level.panel.next_button)
	check(level.state.stage_idx == 2,"next workbench is stern rudder")
	check(not level.state.turn_rudder(30),"cannot turn before blade assembly")
	await install("lbrace")
	await button(level.panel.next_button)
	await install("rudder",true)
	check(not level.view.pieces.rudder.has_node("RudderBlade"),"wide blade does not travel through small round bearing")
	check(level.view.pieces.rudder.has_node("TopThrustShoulder"),"shaft has upper thrust shoulder")
	await button(level.panel.next_button)
	await install("blade")
	check(level.view.pieces.blade.get_node("SideCap").position.is_zero_approx(),"split collar closes after side insertion")
	var frame_before: Transform3D = level.view.stages[2].get_node("SternPostSteppedSocket").global_transform
	var brace_before: Transform3D = level.view.pieces.lbrace.global_transform
	await button(level.panel.left_button)
	check(level.state.rudder_angle == -30 and level.state.tested_left,"left rudder -30 degrees")
	check(is_equal_approx(level.view.rudder_pivot.rotation_degrees.y,-30),"round shaft and blade pivot rotates left")
	await snapshot("rudder-left-30")
	await button(level.panel.right_button)
	check(level.state.rudder_angle == 30 and level.state.tested_right,"right rudder +30 degrees")
	check(frame_before.is_equal_approx(level.view.stages[2].get_node("SternPostSteppedSocket").global_transform),"fixed stern post never rotates")
	check(brace_before.is_equal_approx(level.view.pieces.lbrace.global_transform),"L through tenon brace never rotates")
	check(level.state.completed and completion_count == 1,"completion emitted once after both steering tests")
	level.panel.success_panel.hide()
	await snapshot("rudder-right-30")
	await button(level.panel.center_button)
	check(completion_count == 1,"repeat steering does not emit completion twice")
	await button(level.panel.undo_button)
	check(not level.state.completed and not level.state.placed.has("blade"),"undo completion requires blade reassembly")
	await button(level.panel.return_button)
	check(return_count == 1,"directory return emits public signal")
	var report := {"passed":passed,"failed":failures.size(),"failures":failures,"input":"Viewport mouse and touchscreen","bearing_radial_clearance":.03,"steering_range_degrees":[-30,30]}
	var file := FileAccess.open("res://tests/level03_input_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("LEVEL03_REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
