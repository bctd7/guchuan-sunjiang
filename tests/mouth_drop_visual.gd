extends "res://tests/trial_flow_visual.gd"
const MOUTH_OUT="res://tests/evidence/full-insert/"
var drops: Array[Dictionary]=[]
func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOUTH_OUT))
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=MOUTH_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual mouth-drop pixels "+label)
	images.append(path)
func attempt(kind: String,length: String,label: String,touch:=false) -> void:
	var id: String=level.state.selected
	await choose_trial(kind,length)
	await capture(label+"-before")
	var inspector=level.inspector
	var part: Node3D=inspector.animated_piece
	var tip: MeshInstance3D
	if part.has_meta("candidate_tip_path"):tip=part.get_node(part.get_meta("candidate_tip_path"))
	elif id.begins_with("rib_"):tip=part.find_child("RootTenon",true,false)
	elif id=="bow":tip=part.get_child(0).get_child(0)
	else:tip=part.get_child(0)
	# Independently derive the timber's actual leading face from its AABB.
	# The release destination is the real receiving face, never target_screen,
	# drag_start_screen, _seated_pose, trial_pose or the controller's socket API.
	var outward:=Vector3.LEFT if id=="rib_l1" else (Vector3.FORWARD if id=="bow" else Vector3.RIGHT)
	var front:=Vector3.ZERO
	var minimum:=INF
	var count:=0
	for index in 8:
		var corner: Vector3=tip.to_global(tip.mesh.get_aabb().get_endpoint(index))
		var distance: float=corner.dot(outward)
		if distance<minimum-.0001:minimum=distance;front=corner;count=1
		elif absf(distance-minimum)<.0001:front+=corner;count+=1
	front/=count
	var mouth:=Vector3(-.55,.38,-2.7) if id=="rib_l1" else (Vector3(0,.46,-4.45) if id=="bow" else Vector3(2.97,2.34,-2.7))
	var viewport_size:=Vector2(inspector.viewport.size)
	var pixel_scale: Vector2=inspector.orbit.size/viewport_size
	var delta: Vector2=(inspector.camera.unproject_position(mouth)-inspector.camera.unproject_position(front))*pixel_scale
	var local_start: Vector2=far_body_point()
	var start: Vector2=inspector.orbit.global_position+local_start
	var finish: Vector2=start+delta
	var angles: Vector2=inspector.orbit.target_angles
	check(inspector.orbit.get_global_rect().has_point(finish),"physical mouth release lies inside visible stage "+label)
	await stroke(start,finish,touch)
	check(inspector.orbit.target_angles==angles,"holding visible stock never rotates camera "+label)
	check(level.state.placed.has(id),"release at actual mouth accepts "+label)
	drops.append({"trial":label,"mouse_start":str(start),"mouse_release":str(finish),"actual_front":str(front),"actual_mouth":str(mouth),"accepted":level.state.placed.has(id),"touch_dispatch":touch})
	if not level.state.placed.has(id):
		await capture(label+"-REJECTED")
		return
	check(level.state.placed[id].joint==kind and level.state.placed[id].length==length,"actual selected material retained "+label)
	await wait_review(not level.Rules.connection_correct(id,level.state.placed),label)
	check(inspector.animated_piece.transform.is_equal_approx(level.Lengths.seated_pose(id,length)),"full visual insertion reaches assembled location "+label)
	await capture(label+"-after")
func run() -> void:
	await super.run()
	# Parent writes its compatibility report before returning; retain the real
	# mouth-drop evidence and independently derived pointer destinations here.
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"drops":drops,"images":images,"method":"Actual GPU frames and Viewport GUI events. Grip actual visible body, independently project physical tip face onto real receiving mouth, release there; no internal drag target used. Not native mouse/physical touchscreen."}
	FileAccess.open(MOUTH_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOUTH_DROP_GPU ",passed," passed, ",failures.size()," failed")
