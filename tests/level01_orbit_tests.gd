extends SceneTree
## Acceptance uses root Viewport GUI dispatch, not direct helper input callbacks.
var level: Node3D
var passed := 0
var failures: Array[String] = []
var requests := 0
const EVIDENCE := "res://tests/evidence/level01-orbit/"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failures.append(label)
		push_error("FAIL "+label)

func settle(seconds := 0.6) -> void:
	await create_timer(seconds).timeout
	await process_frame

func mouse_at(position: Vector2, pressed: bool, device := 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position=position
	motion.global_position=position
	motion.device=device
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position=position
	event.global_position=position
	event.pressed=pressed
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.device=device
	root.push_input(event,true)
	await process_frame

func move_mouse(position: Vector2, relative: Vector2, device := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position=position
	event.global_position=position
	event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.device=device
	root.push_input(event,true)
	await process_frame

func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	await mouse_at(position,true)
	await mouse_at(position,false)
	await process_frame

func drag_mouse(start: Vector2, delta: Vector2) -> void:
	await mouse_at(start,true)
	await move_mouse(start+delta,delta)
	await mouse_at(start+delta,false)

func touch_at(position: Vector2, pressed: bool, index := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position=position
	event.pressed=pressed
	event.index=index
	event.canceled=canceled
	root.push_input(event,true)
	await process_frame

func drag_touch(position: Vector2, delta: Vector2, index := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position=position
	event.relative=delta
	event.index=index
	root.push_input(event,true)
	await process_frame

func signature(node: Node) -> String:
	var result := ""
	if node is Node3D: result += str(node.transform)+str(node.visible)
	if node is MeshInstance3D: result += str(node.mesh.get_faces())
	for child in node.get_children(): result += signature(child)
	return result

func snapshot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EVIDENCE+label+".png")

func run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	level=load("res://levels/level01/level01.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await settle(0.15)
	level.interaction.socket_requested.connect(func(_id: String): requests += 1)
	check(level.state.placed.has("keel") and level.state.progress_count() == 0,"fixed foundation precedes observation without player action")
	await click(level.panel.inspect_button)
	var inspector=level.inspector
	var orbit=inspector.orbit
	await click(inspector.joint_buttons["blind_tenon"])
	await click(inspector.length_buttons["correct"])
	await settle(0.1)
	var center: Vector2=orbit.get_global_rect().get_center()
	var default_pose: Transform3D=inspector.camera.transform
	var world_pose: Transform3D=level.view.camera.transform
	var source_before := signature(level.view)
	var clone_before := signature(inspector.animated_piece)
	var state_before: Dictionary=level.state.placed.duplicate(true)
	var request_before := requests
	check(orbit.size.x>200 and orbit.size.y>200,"orbit surface occupies central close-up")
	check(inspector.length_buttons.size()==3 and inspector.candidate_panel.visible,"length measurement remains available beside orbit region")
	check(not orbit.get_global_rect().intersects(inspector.candidate_panel.get_global_rect()),"length comparison stays outside draggable orbit region")
	await snapshot("01-default")
	await drag_mouse(center,Vector2(2,1))
	await settle(0.1)
	check(orbit.target_angles==Vector2.ZERO and inspector.camera.transform.is_equal_approx(default_pose),"light click has no camera jump")
	await mouse_at(center,true)
	orbit.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await move_mouse(center+Vector2(50,30),Vector2(50,30))
	await mouse_at(center+Vector2(50,30),false)
	check(not orbit._mouse_down and orbit.target_angles==Vector2.ZERO,"focus loss cancels mouse before next motion")
	await drag_mouse(center,Vector2(60,32))
	check(orbit.target_angles.x<0 and orbit.target_angles.y<0,"real GUI mouse drag rotates yaw and pitch")
	check(orbit.angles.distance_to(orbit.target_angles)>0.001,"camera damping interpolates instead of jumping")
	await settle()
	check(not inspector.camera.transform.is_equal_approx(default_pose),"mouse orbit changes local camera")
	check(inspector.camera.position.distance_to(default_pose.origin)<5.0,"limited orbit stays close to original viewpoint")
	await snapshot("02-rotated")
	var retained: Vector2=orbit.target_angles
	for kind in ["dovetail","through_tenon","blind_tenon"]:
		await click(inspector.joint_buttons[kind])
		check(inspector.selected_joint==kind,"type card still clickable: "+kind)
		check(orbit.target_angles.is_equal_approx(retained),"same piece preserves angle on type change: "+kind)
		check(inspector.selected_length=="correct" and level.tenon_length=="correct","type change preserves explicit length: "+kind)
	for length in ["short","long","correct"]:
		await click(inspector.length_buttons[length])
		check(inspector.selected_length==length and level.tenon_length==length,"length control remains clickable: "+length)
		check(orbit.target_angles.is_equal_approx(retained),"same piece preserves orbit angle on length change: "+length)
		check(inspector.selected_joint=="blind_tenon","length change preserves selected type: "+length)
	await drag_mouse(inspector.explanation.get_global_rect().get_center(),Vector2(30,5))
	check(orbit.target_angles.is_equal_approx(retained),"dragging explanation cannot rotate camera")
	await drag_mouse(inspector.joint_buttons["dovetail"].get_global_rect().get_center(),Vector2(35,0))
	check(orbit.target_angles.is_equal_approx(retained),"dragging candidate card cannot rotate camera")
	# Restore expected candidate via actual GUI, then test extreme motion capture.
	await click(inspector.joint_buttons["blind_tenon"])
	await drag_mouse(center,Vector2(6000,6000))
	await settle()
	check(is_equal_approx(orbit.target_angles.x,-orbit.YAW_LIMIT) and is_equal_approx(orbit.target_angles.y,-orbit.PITCH_LIMIT),"mouse yaw/pitch clamp at -30/-18 degrees")
	await drag_mouse(center,Vector2(-6000,-6000))
	await settle()
	check(is_equal_approx(orbit.target_angles.x,orbit.YAW_LIMIT) and is_equal_approx(orbit.target_angles.y,orbit.PITCH_LIMIT),"mouse yaw/pitch clamp at +30/+18 degrees")
	check(not orbit._mouse_down,"mouse release outside viewport clears capture")
	inspector.close()
	inspector.show_connection("rib_l1","correct",false,"blind_tenon")
	await settle(0.1)
	check(orbit.angles==Vector2.ZERO and orbit.target_angles==Vector2.ZERO,"close/reopen restores default angles")
	check(inspector.camera.transform.is_equal_approx(default_pose),"reopen restores exact default camera")
	await touch_at(center,true)
	await drag_touch(center+Vector2(55,-24),Vector2(55,-24))
	await touch_at(center+Vector2(55,-24),false)
	check(orbit.target_angles.x<0 and orbit.target_angles.y>0,"real GUI single touch rotates yaw and pitch")
	check(orbit._touch_index==-1,"touch release clears capture")
	retained=orbit.target_angles
	await mouse_at(center,true,InputEvent.DEVICE_ID_EMULATION)
	await move_mouse(center+Vector2(100,100),Vector2(100,100),InputEvent.DEVICE_ID_EMULATION)
	await mouse_at(center+Vector2(100,100),false,InputEvent.DEVICE_ID_EMULATION)
	check(orbit.target_angles.is_equal_approx(retained),"emulated mouse does not double touch orbit")
	await touch_at(center,true,1)
	await touch_at(center,true,2)
	await drag_touch(center+Vector2(90,90),Vector2(90,90),2)
	check(orbit.target_angles.is_equal_approx(retained),"second finger cannot hijack orbit")
	await touch_at(center,false,2)
	await touch_at(center,false,1,true)
	check(orbit._touch_index==-1,"canceled touch clears capture")
	await touch_at(center,true,3)
	orbit.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await drag_touch(center+Vector2(60,60),Vector2(60,60),3)
	check(orbit._touch_index==-1 and orbit.target_angles.is_equal_approx(retained),"focus loss cancels touch without later drift")
	await touch_at(center,false,3)
	await touch_at(center,true,4)
	await drag_touch(center+Vector2(6000,6000),Vector2(6000,6000),4)
	await touch_at(center+Vector2(6000,6000),false,4)
	check(is_equal_approx(orbit.target_angles.x,-orbit.YAW_LIMIT) and is_equal_approx(orbit.target_angles.y,-orbit.PITCH_LIMIT),"touch yaw/pitch clamp at -30/-18 degrees")
	check(orbit._touch_index==-1,"touch release outside viewport clears capture")
	await touch_at(center,true,5)
	await drag_touch(center-Vector2(6000,6000),-Vector2(6000,6000),5)
	await touch_at(center-Vector2(6000,6000),false,5)
	check(is_equal_approx(orbit.target_angles.x,orbit.YAW_LIMIT) and is_equal_approx(orbit.target_angles.y,orbit.PITCH_LIMIT),"touch yaw/pitch clamp at +30/+18 degrees")
	inspector.close()
	inspector.show_connection("rib_l1","correct",false,"blind_tenon")
	await touch_at(center,true,6)
	await drag_touch(center+Vector2(55,-24),Vector2(55,-24),6)
	await touch_at(center+Vector2(55,-24),false,6)
	await settle()
	check(signature(level.view)==source_before,"orbit leaves all source geometry and world camera unchanged")
	check(level.view.camera.transform.is_equal_approx(world_pose),"whole scene camera stays fixed")
	check(signature(inspector.animated_piece)==clone_before,"orbit leaves displayed wood transform and mesh unchanged")
	check(level.state.placed==state_before and requests==request_before,"GUI orbit never requests assembly or changes placed state")
	await settle(0.5)
	await click(inspector.xray_button)
	check(inspector.xray_button.button_pressed,"cutaway button remains clickable")
	await snapshot("03-hole-interior")
	# Installation tween continues independently while its camera orbits.
	inspector.show_connection("rib_l1","correct",true,"blind_tenon")
	await settle(0.35)
	var animation_pose: Transform3D=inspector.animated_piece.transform
	await drag_mouse(center,Vector2(40,20))
	await settle(0.4)
	check(inspector.is_animating and not inspector.animated_piece.transform.is_equal_approx(animation_pose),"insertion animation advances during orbit")
	await settle(1.7)
	check(inspector.animation_finished and inspector.animated_piece.transform.is_equal_approx(level.view.final_pose("rib_l1","correct")),"orbit does not alter insertion final trajectory")
	await mouse_at(center,true)
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	root.push_input(escape,true)
	await process_frame
	check(not inspector.opened and not orbit.active and not orbit._mouse_down,"Escape closes and cancels active mouse gesture")
	inspector.show_connection("rib_l1","correct",false,"blind_tenon")
	check(orbit.target_angles==Vector2.ZERO,"Escape reopen starts at default")
	await drag_mouse(center,Vector2(40,20))
	inspector.show_connection("beam1","correct",false,"through_tenon")
	check(orbit.target_angles==Vector2.ZERO and orbit.angles==Vector2.ZERO,"different piece opens at its own default view")
	await click(inspector.close_button)
	check(not inspector.opened and not orbit.active,"close button remains clickable and deactivates orbit")
	var report := {"passed":passed,"failed":failures.size(),"failures":failures,"method":"root.push_input real Viewport GUI mouse/touch dispatch; only focus-loss notification injected","renderer":DisplayServer.get_name(),"screenshots":["01-default.png","02-rotated.png","03-hole-interior.png"]}
	var file := FileAccess.open(EVIDENCE+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("LEVEL01 ORBIT: %d passed, %d failed" % [passed,failures.size()])
	level.free()
	quit(0 if failures.is_empty() else 1)
