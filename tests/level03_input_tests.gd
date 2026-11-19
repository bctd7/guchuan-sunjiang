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
func drag(fraction:=1.0,use_touch:=false) -> void:
	await preload("res://tests/hull_pointer.gd").drag_assembly(root,level.panel.orbit,fraction,use_touch)

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
	check(level.panel.workspace.viewport_container.get_global_rect().has_point(point),"socket inside scene viewport "+id)
	check(level.view.pick_socket(point) == id,"root-coordinate socket pick "+id)
	if Rules.SETTINGS.has(id):
		await drag()
		check(not level.state.placed.has(id) and level.state.setting < 0,"installation needs an explicit setting "+id)
		var correct: int = Rules.SETTINGS[id].correct
		await button(level.panel.setting_buttons[1-correct])
		var moving_part: Node3D = level.view.pieces.zrail if id == "leg" else level.view.preview
		var before: Transform3D = moving_part.transform
		await drag()
		check(level.state.last_outcome.code == "alignment" and not level.state.placed.has(id),"wrong setup can be retried "+id)
		await settle(.36)
		check(not moving_part.transform.is_equal_approx(before),"failed fit moves the affected member "+id)
		await button(level.panel.setting_buttons[correct])
		if id == "leg":
			check(moving_part.transform.is_equal_approx(before),"correcting the support restores the spar")
	var count: int = level.state.placed.size()
	await click(point)
	check(level.state.placed.size() == count,"socket tap cannot install "+id)
	if id == "apron":
		await drag(-.4)
		check(is_zero_approx(level.panel.orbit.drag_progress),"reverse drag cannot advance")
		await drag(.35)
		check(level.panel.orbit.drag_progress > .2 and level.state.placed.size() == count,"shallow drag preserves partial insertion")
	await drag(.85,use_touch)
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
	level.completion_changed.connect(func(completed: bool):
		if completed: completion_count += 1)
	level.return_requested.connect(func(): return_count += 1)
	await settle(.7)
	await button(level.panel.inspect_button)
	check(level.state.placed.is_empty(),"starts with no player-installed pieces")
	check(is_equal_approx(G.BEARING_RADIUS-G.SHAFT_RADIUS,.03),"radial bearing clearance .03")
	var dependency := Rules.evaluate("leg","leg","zong_corner",[],1)
	check(dependency.code == "dependency","corner leg cannot precede horizontal rails")
	var bad_socket := Rules.evaluate("zrail","leg","zong_corner",[],1)
	check(bad_socket.code == "wrong_socket","different socket rejected")
	await drag()
	check(level.state.placed.is_empty() and level.state.last_outcome.is_empty(),"unselected reference cannot be installed")
	await button(level.panel.candidate_buttons["l_through"])
	await drag()
	check(level.state.last_outcome.code == "wrong_joint" and level.state.placed.is_empty(),"wrong type rejected without installation")
	await button(level.panel.overview_button)
	await button(level.panel.restart_button)
	await button(level.panel.inspect_button)
	await install("apron")
	await click(level.view.socket_screen_position("apron"))
	check(level.state.placed.size() == 1,"duplicate click never installs twice")
	await button(level.panel.next_button)
	await button(level.panel.closeup_button)
	await snapshot("clamp-top-real-bottom-sockets")
	await button(level.panel.closeup_button)
	await install("top",true)
	await button(level.panel.next_button)
	await button(level.panel.candidate_buttons["round_axle"])
	await button(level.panel.setting_buttons[1])
	await drag()
	await settle(.36)
	check(absf(level.view.preview.rotation.z) > .05 and not level.state.placed.has("mast"),"loose mast visibly tilts and can be corrected")
	await button(level.panel.overview_button)
	await button(level.panel.undo_button)
	check(level.state.selected == "top" and level.state.placed == ["apron"],"undo removes cap and preserves crossbar")
	await button(level.panel.inspect_button)
	await install("top")
	await button(level.panel.next_button)
	await install("mast",true)
	await button(level.panel.next_button)
	check(level.state.stage_idx == 1,"next workbench is the spar")
	await install("zrail")
	await button(level.panel.next_button)
	await install("leg",true)
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
	await button(level.panel.overview_button)
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
	check(not level.state.completed and completion_count == 0,"both steering tests unlock the harbor trial")
	await button(level.panel.launch_button)
	check(level.busy and not level.state.completed and is_instance_valid(level.view.launch_scene),"whole ship launches before completion")
	level.panel.launch_requested.emit()
	check(level.view.launch_scene.ship.has_node("SailsAndPennants") and level.view.launch_scene.ship.has_node("HullDeckAndRigging"),"launch includes completed hull and sails")
	await settle(3.3)
	check(level.state.completed and completion_count == 1,"only the finished harbor trial grants completion")
	var result_preview: JointPreview=level.panel.success_panel.preview
	check(is_instance_valid(result_preview) and is_instance_valid(result_preview.viewport),"result lazily creates its model viewport")
	level.panel.success_panel.hide()
	await process_frame
	check(not is_instance_valid(result_preview) and level.panel.success_panel.preview==null,"closing result releases its model viewport")
	await snapshot("rudder-right-30")
	await button(level.panel.center_button)
	check(completion_count == 1,"repeat steering does not emit completion twice")
	await button(level.panel.undo_button)
	check(not is_instance_valid(level.view.launch_scene),"undo releases harbor scene")
	check(not level.state.completed and not level.state.placed.has("blade"),"undo completion requires blade reassembly")
	await button(level.panel.return_button)
	check(return_count == 1,"directory return emits public signal")
	var report := {"passed":passed,"failed":failures.size(),"failures":failures,"input":"Viewport mouse and touchscreen","bearing_radial_clearance":.03,"steering_range_degrees":[-30,30]}
	var file := FileAccess.open("res://tests/level03_input_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("LEVEL03_REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
