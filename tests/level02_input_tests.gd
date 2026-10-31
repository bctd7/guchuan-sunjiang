extends SceneTree
var level
var passed:=0
var failed:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		failures.append(label)
		push_error(label)
func settle(seconds:=.12) -> void:
	await create_timer(seconds).timeout
	await process_frame
func mouse(p: Vector2,pressed: bool) -> void:
	var motion=InputEventMouseMotion.new()
	motion.position=p
	motion.global_position=p
	root.push_input(motion,true)
	var event=InputEventMouseButton.new()
	event.position=p
	event.global_position=p
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
	await process_frame
func click(p: Vector2) -> void:
	await mouse(p,true)
	await mouse(p,false)
	await process_frame
func button(b: Button) -> void:
	check(b.is_visible_in_tree() and not b.disabled,"operable "+b.text)
	await click(b.get_global_rect().get_center())
func touch(p: Vector2) -> void:
	for pressed in [true,false]:
		var e=InputEventScreenTouch.new()
		e.position=p
		e.pressed=pressed
		e.index=0
		root.push_input(e,true)
		await process_frame
func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/level02_evidence"))
	root.get_texture().get_image().save_png("res://tests/level02_evidence/"+name+".png")
func prepare(id: String,layout: String="") -> void:
	await button(level.panel.piece_buttons[id])
	check(level.state.joint.is_empty(),"joint requires a fresh choice "+id)
	await button(level.panel.observe_button)
	check(level.view.inspected and level.state.observed.has(id),"real ship target inspected "+id)
	check(level.panel.gallery.get_child_count()==3,"three actual geometry candidates visible")
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	if not layout.is_empty() and id.ends_with("a"): await button(level.panel.layout_buttons[layout])
	if id in ["cross_upper","three_middle","three_upper"]: await snapshot("candidate-"+id)
	await button(level.panel.overview_button)
func place(id: String,layout: String="",use_touch:=false) -> void:
	await prepare(id,layout)
	var p=level.view.socket_screen_position(id)
	check(level.view.pick_socket(p)==id,"projected socket accessible "+id)
	check(Rect2(340,330,1080,380).has_point(p),"socket fits unobstructed world region "+id)
	if use_touch: await touch(p)
	else: await click(p)
	check(level.state.placed.has(id),"real pointer places "+id)
	check(level.busy and level.view.animations.has(id),"insertion remains busy until the actual .65-second motion finishes: "+id)
	var selected: String=level.state.selected
	var tween: Tween=level.view.animations.get(id)
	var start_pose: Transform3D=level.view.pieces[id].transform
	var next_id: String=level.Rules.IDS[(level.Rules.IDS.find(id)+1)%level.Rules.IDS.size()]
	# Also emit the normal controls' signals: disabled GUI alone must not hide a missing coordinator guard.
	level.panel.piece_buttons[next_id].pressed.emit()
	level.panel.check_button.pressed.emit()
	check(level.state.selected==selected and level.view.animations.get(id)==tween,"rapid selection cannot cancel or replace active insertion: "+id)
	check(not level.state.completed and not level.panel.success_panel.visible,"busy inspection cannot complete the hull: "+id)
	await settle(.20)
	check(level.busy and level.view.animations.get(id)==tween and not level.view.pieces[id].transform.is_equal_approx(start_pose),"same insertion tween continues moving after rapid controls: "+id)
	await settle(.55)
	check(not level.busy and level.view.animations.is_empty(),"busy releases only after insertion animation completes: "+id)
	check(level.view.pieces[id].transform.is_equal_approx(level.view.poses[id]),"piece reaches its true seated pose: "+id)
func run() -> void:
	root.size=Vector2i(1440,900)
	level=load("res://levels/level02/level02.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await settle(.5)
	await snapshot("01-start")
	check(level.state.placed.is_empty(),"fresh state")
	await click(level.view.socket_screen_position("plank_0a"))
	check(level.state.placed.is_empty() and level.panel.feedback_label.text.contains("观察"),"observation required via input")
	await button(level.panel.observe_button)
	await snapshot("02-observe-three-candidates")
	await button(level.panel.joint_buttons.cross_lap)
	await snapshot("03-wrong-candidate-selected")
	await button(level.panel.overview_button)
	await click(level.view.socket_screen_position("plank_0a"))
	check(level.state.placed.is_empty() and level.panel.feedback_label.text.contains("不匹配"),"wrong type cannot install")
	await snapshot("04-wrong-rejected")
	for id in level.Rules.IDS: await place(id,"A" if level.Rules.row_for(id)>0 else "",id=="plank_0b")
	await button(level.panel.check_button)
	check(not level.state.completed and level.state.bad_row()==1,"aligned end seams leak and fail")
	check(level.view.water.get_child_count()>0,"visible leakage risk drops")
	await snapshot("05-aligned-leak")
	await button(level.panel.repair_button)
	check(level.state.placed.size()==2 and level.state.selected=="plank_1a","repair removes bad row and downstream")
	for id in level.Rules.IDS.slice(2): await place(id,"B" if level.Rules.row_for(id)==1 else "A" if level.Rules.row_for(id)==2 else "")
	await button(level.panel.plan_button)
	await snapshot("06-end-seams-plan")
	await button(level.panel.overview_button)
	await button(level.panel.check_button)
	check(level.state.completed and level.panel.success_panel.visible,"corrected hull passes through UI")
	await snapshot("07-complete")
	# Dismiss success through its actual button and inspect completed physical hull.
	var close=level.panel.success_panel.get_child(0).get_child(3)
	await button(close)
	await button(level.panel.transparent_button)
	await snapshot("08-complete-transparent")
	await button(level.panel.transparent_button)
	await snapshot("09-complete-hull")
	await button(level.panel.restart_button)
	check(level.state.placed.is_empty() and not level.state.completed,"restart resets completed hull")
	await prepare("plank_0a")
	var p=level.view.socket_screen_position("plank_0a")
	await mouse(p+Vector2(70,0),true)
	await mouse(p,false)
	check(level.state.placed.is_empty(),"drag is not a placement tap")
	await click(p)
	await button(level.panel.undo_button)
	await settle(.75)
	check(level.state.placed.is_empty() and not level.view.pieces.plank_0a.visible,"undo during alignment cancels late piece")
	await place("plank_0a")
	check(level.state.placed.size()==1,"retry remains playable")
	var f=FileAccess.open("res://tests/level02_input_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"failed":failed,"failures":failures,"method":"Godot Viewport real mouse/touch events; no state mutation","renderer":DisplayServer.get_name()},"\t"))
	print("LEVEL02 INPUT ",passed," passed / ",failed," failed")
	level.free()
	quit(0 if failed==0 else 1)
