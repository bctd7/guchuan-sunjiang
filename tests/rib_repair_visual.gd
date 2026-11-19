extends "res://tests/candidate_revision_visual.gd"
const OUT="res://tests/evidence/rib-repair/"
var motion_samples: Dictionary={}
var recording: Array[Dictionary]=[]
var record_autos:=true
var sample_number:=0

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path:=OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual GPU image "+label)
	images.append(path)

func capture_closeup(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=OUT+label+"-closeup.png"
	check(level.inspector.viewport.get_texture().get_image().save_png(path)==OK,"raw local GPU pixels "+label)
	images.append(path)

func sample_auto() -> void:
	var live_ids: Array[String]=[]
	for id in level.view.animations:
		if level.state.placed.has(id) and bool(level.state.placed[id].get("automatic",false)):
			live_ids.append(id)
			if not motion_samples.has(id): motion_samples[id]=[]
			var part: Node3D=level.view.pieces[id]
			motion_samples[id].append({"position":[part.position.x,part.position.y,part.position.z],"visible":part.is_visible_in_tree(),"at_ms":Time.get_ticks_msec()})
	if live_ids.is_empty(): return
	await RenderingServer.frame_post_draw
	var pixels:=surface.get_texture().get_image()
	pixels.resize(864,540,Image.INTERPOLATE_LANCZOS)
	var path:=OUT+"recording/frame-%04d.png"%sample_number
	check(pixels.save_png(path)==OK,"actual automatic frame")
	recording.append({"file":path,"at_ms":Time.get_ticks_msec(),"moving":live_ids})
	sample_number+=1
	if motion_samples[live_ids[0]].size()==5: await capture("auto-mid-"+live_ids[0])

func wait_motion() -> void:
	var started:=Time.get_ticks_msec()
	while level.busy and Time.get_ticks_msec()-started<23000:
		if record_autos: await sample_auto()
		await settle(.10)
	check(not level.busy and level.view.animations.is_empty(),"all actual automatic motions finish")

func wood_points(node: Node,overlay: Control,result: Array[Vector2]) -> void:
	if node is MeshInstance3D and node.mesh and node.is_visible_in_tree():
		var faces: PackedVector3Array=node.mesh.get_faces()
		for i in range(0,faces.size(),6):
			var world_point: Vector3=node.to_global((faces[i]+faces[i+1]+faces[i+2])/3.0)
			var local: Vector2=overlay.camera.unproject_position(world_point)*overlay.size/Vector2(overlay.camera.get_viewport().size)
			if Rect2(Vector2.ZERO,overlay.size).grow(-6).has_point(local):result.append(local)
	for child in node.get_children():wood_points(child,overlay,result)

func far_body_point() -> Vector2:
	var overlay=level.inspector.orbit
	var points: Array[Vector2]=[]
	wood_points(level.inspector.animated_piece,overlay,points)
	points.sort_custom(func(a: Vector2,b: Vector2):return a.distance_to(overlay.drag_start_screen())>b.distance_to(overlay.drag_start_screen()))
	for point in points:
		if overlay._hit_part(point):return point
	return overlay.drag_start_screen()

func drag_body(touch: bool,label: String) -> void:
	var overlay=level.inspector.orbit
	var start_local:=far_body_point()
	check(start_local.distance_to(overlay.drag_start_screen())>86,"whole visible timber can be grabbed far from tenon "+label)
	var start: Vector2=overlay.global_position+start_local
	var delta: Vector2=overlay.target_screen()-overlay.drag_start_screen()
	var before: Transform3D=level.inspector.camera.transform
	await pointer(start,true,touch)
	check(overlay._gesture==overlay.Gesture.PART and overlay.assembly_dragging,"press locks wood gesture "+label)
	var last:=start
	for i in range(1,13):
		var point:=start+delta*i/12.0
		if touch:
			var event:=InputEventScreenDrag.new()
			event.position=point
			event.relative=point-last
			event.index=0
			surface.push_input(event,true)
		else:
			var event:=InputEventMouseMotion.new()
			event.position=point
			event.global_position=point
			event.relative=point-last
			event.button_mask=MOUSE_BUTTON_MASK_LEFT
			surface.push_input(event,true)
		last=point
		await process_frame
		check(level.inspector.camera.transform.is_equal_approx(before),"wood gesture never rotates camera")
		if i==6:await capture(label+"-held-wood")
	await pointer(start+delta,false,touch)
	await settle(.1)

func open_choice(id: String,length: String="correct") -> void:
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons[level.Rules.expected_joint(id)])
	await button(level.inspector.length_buttons[length])
	await settle(.5)

func install_body(id: String,length: String="correct",touch:=false) -> void:
	await open_choice(id,length)
	await drag_body(touch,id)
	check(level.state.placed.has(id) and level.busy,"actual dragged body installs "+id)
	if not level.busy:return
	await settle(2.3)
	await button(level.inspector.close_button)
	await wait_motion()
	await settle(.5)

func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"actual no-focus GPU")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"recording"))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.3)
	await button(campaign.chapter_buttons[1])
	level=campaign.current_chapter
	await button(level.learning.start_button)
	# Read-only renderer fixture: both mirrors and all three rib stations.
	for id in ["rib_l1","rib_r1","rib_l2","rib_r2","rib_l3","rib_r3"]:
		level.inspector.show_connection(id,"correct",false,"blind_tenon")
		await settle(.15)
		await capture_closeup(id+"-default")
		var overlay=level.inspector.orbit
		var blank: Vector2=overlay.global_position+Vector2(50,40)
		await stroke(blank,blank+Vector2(85,40))
		await settle(.4)
		await capture_closeup(id+"-rotated")
		await button(level.inspector.close_button)
	# Real GUI workflow: grab the curved rib or long beam body, not just tip.
	for id in level.Rules.REPRESENTATIVE_IDS:
		await install_body(id,"correct",id=="bow")
	for id in level.Rules.AUTO_GROUPS.rib_l1+level.Rules.AUTO_GROUPS.bow+level.Rules.AUTO_GROUPS.beam1:
		check(motion_samples.has(id) and motion_samples[id].size()>=5,"each automatic piece has multiple real recorded poses "+id)
		if not motion_samples.has(id):continue
		var samples: Array=motion_samples[id]
		var first: Array=samples[0].position
		var changed:=false
		for entry in samples:
			check(entry.visible,"automatic mesh visible during recording "+id)
			if entry.position!=first:changed=true
		check(changed,"automatic piece genuinely moves on camera "+id)
	await button(level.panel.check_button)
	check(level.state.completed,"full body-drag assembly completes")
	level.panel.success_panel.hide()
	await capture("completed-section")
	record_autos=false
	await button(level.panel.restart_button)
	for id in level.Rules.REPRESENTATIVE_IDS:await install_body(id,"short" if id=="rib_l1" else "long",false)
	await button(level.panel.check_button)
	check(not level.state.completed,"wrong lengths remain installable and unstable")
	await wait_motion()
	await capture("wrong-length-remains-correctable")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"recording":recording,"motion_samples":motion_samples,"method":"Actual GPU pixels. Mouse/touch sequences through real Viewport GUI, full timber picks. Six rib closeups use read-only inspector fixture. Hidden NO_FOCUS host; no native desktop or physical touchscreen testing."}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RIB_REPAIR_GPU ",passed," passed, ",failures.size()," failed; images=",images.size(),"; recorded frames=",recording.size())
	surface.free()
	quit(0 if failures.is_empty() else 1)
