extends "res://tests/trial_flow_visual.gd"
const MATRIX_OUT="res://tests/evidence/dropzone-r3/"
var rows: Array[Dictionary]=[]
func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATRIX_OUT))
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=MATRIX_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"matrix GPU frame "+label)
	images.append(path)
func entry(id: String) -> Vector3:
	return Vector3(-.55,.38,-2.7) if id=="rib_l1" else (Vector3(0,.46,-4.45) if id=="bow" else Vector3(2.97,2.34,-2.7))
func front(id: String) -> Vector3:
	var part: Node3D=level.inspector.animated_piece
	var tip: MeshInstance3D
	if part.has_meta("candidate_tip_path"):tip=part.get_node(part.get_meta("candidate_tip_path"))
	elif id.begins_with("rib_"):tip=part.find_child("RootTenon",true,false)
	elif id=="bow":tip=part.get_child(0).get_child(0)
	else:tip=part.get_child(0)
	var outward:=Vector3.LEFT if id=="rib_l1" else (Vector3.FORWARD if id=="bow" else Vector3.RIGHT)
	var nearest:=INF
	var sum:=Vector3.ZERO
	var count:=0
	for index in 8:
		var point: Vector3=tip.to_global(tip.mesh.get_aabb().get_endpoint(index))
		var distance: float=point.dot(outward)
		if distance<nearest-.0001:nearest=distance;sum=point;count=1
		elif absf(distance-nearest)<.0001:sum+=point;count+=1
	return sum/count
func project(point: Vector3) -> Vector2:
	var inspector=level.inspector
	return inspector.camera.unproject_position(point)*inspector.orbit.size/Vector2(inspector.viewport.size)
func visible_grip() -> Vector2:
	var overlay=level.inspector.orbit
	var points: Array[Vector2]=[]
	wood_points(level.inspector.animated_piece,overlay,points)
	points.sort_custom(func(a: Vector2,b: Vector2):return a.distance_to(overlay.size*.5)<b.distance_to(overlay.size*.5))
	for point in points:
		if Rect2(Vector2.ZERO,overlay.size).grow(-40).has_point(point) and overlay._hit_part(point):return point
	return far_body_point()
func trial(id: String,kind: String,length: String,index: int,record_case: bool=true) -> bool:
	await choose_trial(kind,length)
	var label:=id+"-"+kind+"-"+length
	if index%9==0:await capture(label+"-choices")
	var overlay=level.inspector.orbit
	var grip:=visible_grip()
	var mouth:=project(entry(id))
	var tip:=project(front(id))
	var variant:=index%3
	# Endpoints come from independently projected physical stock and receiver.
	# Exercise off-axis tip drops, direct hand-to-port and opposite-side drops.
	var finish: Vector2=mouth+Vector2(-20,-12) if variant==1 else grip+(mouth-tip)+Vector2(30,18) if variant==0 else grip+(mouth-tip)+Vector2(-32,20)
	var origin: Vector2=overlay.global_position
	var angles: Vector2=overlay.target_angles
	var touch:=index%2==1
	check(overlay.get_global_rect().has_point(origin+finish),"release remains on visible stage "+label)
	await stroke(origin+grip,origin+finish,touch)
	var accepted: bool=level.state.placed.has(id)
	check(accepted,"visible region accepts "+label)
	check(overlay.target_angles==angles,"stock press stays stock gesture "+label)
	var expected_stable: bool=kind==level.Rules.expected_joint(id) and length=="correct"
	var row={"socket":id,"joint":kind,"length":length,"expected_stable":expected_stable,"program_drag_accepted":accepted,"pointer_variant":variant,"event_type":"Viewport touch" if touch else "Viewport mouse","grip":str(grip),"release":str(finish),"native_mouse_tested":false,"physical_touch_tested":false}
	if not accepted:
		rows.append(row)
		await capture(label+"-REJECTED")
		return false
	check(level.state.placed[id].joint==kind and level.state.placed[id].length==length,"actual chosen stock retained "+label)
	row["no_restart_jump"]=level.inspector.animated_piece.has_meta("trial_release_start") and level.inspector.animated_piece.transform.is_equal_approx(level.inspector.animated_piece.get_meta("trial_release_start"))
	check(row.no_restart_jump,"insertion continues from released model pose without returning to start "+label)
	await wait_review(not expected_stable,label)
	row["stability_feedback_matches"]=level.inspector.title.text.contains("接好了") if expected_stable else level.inspector.title.text.contains("松")
	check(row.stability_feedback_matches,"stable or loose feedback matches "+label)
	await capture(label+"-inserted")
	if record_case:
		await take_back(id)
		row["take_back_clears_choices"]=not level.state.placed.has(id) and level.joint_type.is_empty() and level.tenon_length.is_empty() and level.inspector.observation_mode
		check(row.take_back_clears_choices,"take-back returns candidate choices "+label)
		rows.append(row)
	return true
func finish_report() -> void:
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":rows,"case_count":rows.size(),"images":images,"method":"Program verification only: actual GPU pixels and Viewport-dispatched mouse/touch events on physical stock/entry projections, 3 sockets x 3 types x 3 lengths. No internal drag target, placement setter, direct business callback, native Windows mouse or physical touchscreen."}
	FileAccess.open(MATRIX_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DROPZONE_MATRIX_GPU ",passed," passed; ",failures.size()," failed; cases=",rows.size())
	surface.free()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"hidden no-focus GPU")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATRIX_OUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.25)
	await button(campaign.chapter_buttons[1])
	level=campaign.instances[1]
	await button(level.learning.start_button)
	record_autos=false
	var index:=0
	for id in level.Rules.REPRESENTATIVE_IDS:
		await button(level.panel.inspect_button)
		for kind in ["blind_tenon","dovetail","through_tenon"]:
			for length in ["short","correct","long"]:
				if not await trial(id,kind,length,index):finish_report();return
				index+=1
		if not await trial(id,level.Rules.expected_joint(id),"correct",0,false):finish_report();return
		await finish_group(level.Rules.expected_joint(id))
	check(rows.size()==27,"all 27 combinations have their own record")
	await button(level.panel.check_button)
	check(level.state.completed,"correct final rebuild completes after all trials and take-backs")
	await capture("all-27-cases-corrected-complete")
	finish_report()
