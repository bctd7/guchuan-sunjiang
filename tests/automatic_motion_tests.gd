extends SceneTree
## Coordinator acceptance: sample the real rendered nodes as Tweens advance.
## Screen bounds come from transformed mesh corners, never animation bookkeeping.
var level: Node3D
var passed := 0
var failures: Array[String] = []
var records: Dictionary = {}
var observed: Array[String] = []
var synchronous_reveals: Array[String] = []
var seen_state: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failures.append(label)
		push_error("FAIL "+label)

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func mesh_corners(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree():
		var box: AABB=node.mesh.get_aabb()
		for i in 8: points.append(node.global_transform*box.get_endpoint(i))
	for child in node.get_children(): mesh_corners(child,points)

func projected_bounds(id: String) -> Rect2:
	var points: Array[Vector3]=[]
	mesh_corners(level.view.pieces[id],points)
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for point in points:
		var screen: Vector2=level.view.camera.unproject_position(point)
		low=low.min(screen)
		high=high.max(screen)
	return Rect2(low,high-low)

func vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func sample(id: String) -> void:
	var part: Node3D=level.view.pieces[id]
	var bounds:=projected_bounds(id)
	var record: Dictionary=records[id]
	record.samples.append({"time_ms":Time.get_ticks_msec(),"pose":vec(part.position),"bounds":rect(bounds),"visible":part.is_visible_in_tree()})
	record.path_bounds=record.path_bounds.merge(bounds)
	record.visible=record.visible and part.is_visible_in_tree()
	record.contained=record.contained and level.view.workshop_clear_rect().grow(1).encloses(bounds)
	record.screen_positions.append(bounds.get_center())

func state_changed() -> void:
	for id in seen_state.keys():
		if not level.state.placed.has(id): seen_state.erase(id)
	for id in level.state.placed:
		if seen_state.has(id): continue
		seen_state[id]=true
		if not bool(level.state.placed[id].get("automatic",false)): continue
		# This signal runs inside place_automatic(), before animate_place().
		if level.view.pieces[id].visible or not level.view.planned_insertions.has(id): synchronous_reveals.append(id)

func start_group(id: String, length: String = "correct") -> void:
	level.joint_type=level.Rules.expected_joint(id)
	level.tenon_length=length
	var outcome: Dictionary=level._try_socket(id)
	check(outcome.ok,"representative accepted: "+id)
	# Wait for the manual part's actual final pose before returning to workshop.
	while level.view.animations.has(id): await process_frame
	level.inspector.close()
	check(level.busy and level.state.pending_group==id,"review close begins pending group: "+id)

func observe_group(representative: String, length: String = "correct") -> void:
	var camera_pose: Transform3D=level.view.camera.transform
	var camera_size: float=level.view.camera.size
	var expected: Array=level.Rules.AUTO_GROUPS[representative]
	var previous: String=""
	var all_gated:=true
	var sequential:=true
	var fixed_camera:=true
	var started:=Time.get_ticks_msec()
	while level.busy and Time.get_ticks_msec()-started<15000:
		all_gated=all_gated and level.panel.check_button.disabled and not level.state.pending_group.is_empty()
		level._check()
		all_gated=all_gated and not level.state.completed
		sequential=sequential and level.view.animations.size()==1
		fixed_camera=fixed_camera and level.view.camera.transform.is_equal_approx(camera_pose) and is_equal_approx(level.view.camera.size,camera_size)
		for id in level.view.animations:
			if not id in expected: continue
			if not records.has(id):
				if not previous.is_empty():
					check(level.view.pieces[previous].transform.is_equal_approx(level.view.final_pose(previous,length)),"previous is fully seated before next: "+id)
				observed.append(id)
				records[id]={"samples":[],"path_bounds":projected_bounds(id),"visible":true,"contained":true,"screen_positions":[]}
				previous=id
			sample(id)
		await process_frame
	for id in expected:
		if not records.has(id):
			check(false,"observed real motion: "+id)
			continue
		sample(id)
		var record: Dictionary=records[id]
		var samples: Array=record.samples
		var first:=Vector3(samples[0].pose[0],samples[0].pose[1],samples[0].pose[2])
		var final: Transform3D=level.view.final_pose(id,length)
		check(first.is_equal_approx(final.origin+level.view.insertion_offset(id)),"first visible pose is complete entry offset: "+id)
		var distinct: Array[Vector3]=[]
		var monotonic:=true
		var remaining:=INF
		var first_move_ms: int=-1
		var seated_ms: int=-1
		var active_end_ms: int=int(samples[samples.size()-2].time_ms)
		for item in samples:
			var pose:=Vector3(item.pose[0],item.pose[1],item.pose[2])
			var distance:=pose.distance_to(final.origin)
			monotonic=monotonic and distance<=remaining+.0001
			remaining=distance
			if first_move_ms<0 and pose.distance_to(first)>.001: first_move_ms=int(item.time_ms)
			if seated_ms<0 and distance<.001: seated_ms=int(item.time_ms)
			if distinct.is_empty() or distinct.back().distance_to(pose)>.05: distinct.append(pose)
		check(distinct.size()>=10 and monotonic,"multiple real intermediate poses approach socket monotonically: "+id)
		check(level.view.pieces[id].transform.is_equal_approx(final),"last pose equals seated transform: "+id)
		check(first_move_ms-int(samples[0].time_ms)>=100 and active_end_ms-seated_ms>=90,"entry and seated holds remain visible in animation: "+id)
		check(record.visible and record.contained,"whole actual mesh remains visible inside clear workshop region: "+id)
		var screen_motion: float=record.screen_positions[0].distance_to(record.screen_positions.back())
		check(screen_motion>=35,"projected movement is readable (>=35px): "+id)
		check(record.path_bounds.size.length()>90,"projected member has readable screen extent: "+id)
		record["screen_motion_px"]=screen_motion
		record["path_bounds"]=rect(record.path_bounds)
		record["sample_count"]=samples.size()
		# Keep five representative real-time samples in the portable report.
		var compact: Array=[]
		for fraction in [0.0,.25,.5,.75,1.0]: compact.append(samples[mini(roundi((samples.size()-1)*fraction),samples.size()-1)])
		record["samples"]=compact
		record.erase("screen_positions")
	check(all_gated,"check remains disabled and cannot bypass pending motion: "+representative)
	check(sequential,"one actual member moves at a time: "+representative)
	check(fixed_camera,"camera remains fixed for whole automatic group: "+representative)
	check(not level.busy and level.state.pending_group.is_empty() and level.view.animations.is_empty(),"group completes only after last member seats: "+representative)

func clean_after_cancel(label: String) -> void:
	var clear: bool=level.view.animations.is_empty() and level.view.planned_insertions.is_empty() and level._auto_queue.is_empty()
	for id in level.Rules.BUILD_IDS:
		clear=clear and level.view.pieces[id].visible==level.state.placed.has(id)
		if not level.state.placed.has(id): clear=clear and level.view.pieces[id].position.is_zero_approx()
	check(clear and not level.busy and level.state.pending_group.is_empty(),label)

func run() -> void:
	root.size=Vector2i(1440,900)
	level=load("res://levels/level01/level01.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await settle(.1)
	seen_state=level.state.placed.duplicate()
	level.state.changed.connect(state_changed)
	for id in level.Rules.REPRESENTATIVE_IDS:
		await start_group(id)
		await observe_group(id)
	check(observed==["rib_r1","rib_l2","rib_r2","rib_l3","rib_r3","stern","beam3"],"all seven automatic members have actual sampled motion in order")
	check(synchronous_reveals.is_empty(),"state.changed never reveals an automatic member seated before its animation")
	check(level.state.progress_count()==3 and level.state.automatic_count()==7 and level.state.installed_count()==10,"three player demonstrations and seven automatic members preserved")
	level._check()
	check(level.state.completed,"stability check becomes available after every real insertion finishes")
	var correct_records: Dictionary=records
	var length_variants: Dictionary={}
	for length in ["long","short"]:
		level._restart()
		records={}
		for id in level.Rules.REPRESENTATIVE_IDS:
			await start_group(id,length)
			await observe_group(id,length)
		for id in level.Rules.BUILD_IDS:
			check(level.state.placed[id].length==length,"chosen length preserved through automatic repetition: "+id+" "+length)
		check(level.state.progress_count()==3 and level.state.automatic_count()==7,"counts unchanged for "+length)
		check(level.state.validate_structure().code=="unstable_length","incompatible length still fails stability after actual motion: "+length)
		length_variants[length]=records
	level._restart()
	await start_group("rib_l1","long")
	await settle(.6)
	level._undo()
	await settle(.3)
	clean_after_cancel("undo mid-motion cancels planned and visible animation without remnants")
	check(level.state.placed.size()==1,"undo removes the whole demonstrated group")
	await start_group("rib_l1","short")
	await settle(.6)
	level._restart()
	await settle(2)
	clean_after_cancel("reset mid-motion prevents killed callbacks from starting later members")
	check(level.state.placed.size()==1 and not level.panel.success_panel.visible,"reset retains only fixed keel and clears success")
	level.joint_type="blind_tenon"
	level.tenon_length="correct"
	level._try_socket("rib_l1")
	level.inspector.close()
	check(level.view.animations.has("rib_l1") and level.state.automatic_count()==0,"closing review early waits for actual representative motion")
	await settle(.3)
	check(level.state.automatic_count()==0 and level.state.pending_group=="rib_l1","pending representative cannot trigger premature automatic insertion")
	level._undo()
	await settle(1.9)
	clean_after_cancel("undo while waiting for manual motion also cancels deferred automatic chain")
	check(synchronous_reveals.is_empty(),"all length variants preserve hidden preparation during state.changed")
	var report:={"passed":passed,"failed":failures.size(),"failures":failures,"renderer":DisplayServer.get_name(),"method":"real SceneTree Tween frames; transformed visible mesh corners projected through Camera3D; coordinator state.changed observed synchronously","clear_rect":rect(level.view.workshop_clear_rect()),"members":correct_records,"length_variants":length_variants}
	var target: String=OS.get_environment("AUTOMATIC_MOTION_REPORT")
	if target.is_empty(): target="res://tests/evidence/rib-repair/automatic-motion-report.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var file:=FileAccess.open(target,FileAccess.WRITE)
	if file==null:
		push_error("Motion assertions complete but report cannot be saved: "+target)
		level.free()
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  "))
	print("AUTOMATIC MOTION: %d passed, %d failed; report=%s"%[passed,failures.size(),target])
	level.free()
	quit(0 if failures.is_empty() else 1)
