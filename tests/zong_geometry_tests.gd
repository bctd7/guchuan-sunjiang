extends SceneTree
const Guard = preload("res://core/mesh_collision_guard.gd")
var passed := 0
var failed := 0
var meshes: Dictionary = {}
var intersections: Array = []

func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)

func _initialize() -> void:
	call_deferred("run")

func contains_point(id: String,point: Vector3) -> bool:
	var direction := Vector3(.819231,.371391,.436217).normalized()
	var distances: Array[float] = []
	var faces: PackedVector3Array = meshes[id].get_faces()
	for i in range(0,faces.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(point,direction,faces[i],faces[i+1],faces[i+2])
		if hit != null and point.distance_to(hit) > .000001: distances.append(point.distance_to(hit))
	distances.sort()
	var unique := 0
	var previous := -1.0
	for value in distances:
		if value - previous > .000001:
			unique += 1
			previous = value
	return unique % 2 == 1

func check_topology(id: String) -> void:
	var faces: PackedVector3Array = meshes[id].get_faces()
	var edges := {}
	var volume := 0.0
	var finite := true
	for i in range(0,faces.size(),3):
		var keys: Array[String] = []
		for j in range(3):
			var v := faces[i+j]
			finite = finite and v.is_finite()
			keys.append("%.6f,%.6f,%.6f" % [v.x,v.y,v.z])
		volume += faces[i].dot(faces[i+1].cross(faces[i+2])) / 6.0
		for j in range(3):
			var a := keys[j]
			var b := keys[(j+1)%3]
			var edge := a + ":" + b if a < b else b + ":" + a
			edges[edge] = int(edges.get(edge,0)) + 1
	var closed := not edges.is_empty()
	for count in edges.values(): closed = closed and count == 2
	check(finite,"finite imported coordinates " + id)
	check(closed,"welded edges have exactly two incident faces " + id)
	check(absf(volume) > .1,"nonzero solid volume with Godot clockwise winding " + id)

func intersection_volume(a: String, ap: Transform3D, b: String, bp: Transform3D) -> float:
	var operation := CSGCombiner3D.new()
	root.add_child(operation)
	for entry in [[a,ap],[b,bp]]:
		var piece := CSGMesh3D.new()
		piece.mesh = meshes[entry[0]]
		piece.transform = entry[1]
		piece.operation = CSGShape3D.OPERATION_UNION if operation.get_child_count() == 0 else CSGShape3D.OPERATION_INTERSECTION
		operation.add_child(piece)
	await process_frame
	await process_frame
	var mesh := operation.bake_static_mesh()
	var volume := 0.0
	if mesh != null:
		var faces := mesh.get_faces()
		for i in range(0,faces.size(),3): volume += faces[i].dot(faces[i+1].cross(faces[i+2])) / 6.0
	operation.free()
	return absf(volume)

func run() -> void:
	var guard = Guard.new()
	for id in ["xrail","zrail","leg"]:
		meshes[id] = load("res://models/assets/zong_corner_" + id + ".obj")
		guard.register_mesh(id,meshes[id])
		check_topology(id)
	check(contains_point("leg",Vector3(.6,.8,.2)),"long tenon reaches upper deep socket")
	check(not contains_point("leg",Vector3(.2,.88,.6)),"short vertical tenon remains below long tenon")
	check(contains_point("leg",Vector3(.2,.5,.6)),"short tenon has real solid material")
	check(not contains_point("xrail",Vector3(.2,.88,.6)),"auxiliary horizontal tongue absent")
	check(contains_point("zrail",Vector3(.2,.88,.6)),"former auxiliary slot restored to stock")
	check(not contains_point("xrail",Vector3(.6,.8,.2)),"deep leg-tenon mortise is open")
	check(not contains_point("zrail",Vector3(.2,.5,.6)),"shallow leg-tenon mortise is open")
	var assembled := {"xrail":Transform3D.IDENTITY,"zrail":Transform3D.IDENTITY,"leg":Transform3D.IDENTITY}
	var positive_control := await intersection_volume("xrail",Transform3D.IDENTITY,"xrail",Transform3D.IDENTITY)
	check(positive_control > 2.0,"boolean positive control must detect solid overlap")
	intersections.append({"positive_control_volume":positive_control})
	for id in assembled:
		check(guard.motion_is_safe(id,assembled[id],assembled[id],assembled), "assembled pose clear: " + id + " " + guard.last_reason)
	for pair in [["xrail","zrail"],["xrail","leg"],["zrail","leg"]]:
		var volume := await intersection_volume(pair[0],Transform3D.IDENTITY,pair[1],Transform3D.IDENTITY)
		intersections.append({"pair":pair,"assembled_volume":volume})
		check(volume < .000001,"assembled boolean intersection: " + str(pair))
	var parked := Transform3D(Basis.IDENTITY,Vector3(0,-1.8,0))
	check(guard.motion_is_safe("zrail",Transform3D(Basis.IDENTITY,Vector3(0,0,2.2)),Transform3D.IDENTITY,{"xrail":Transform3D.IDENTITY,"leg":parked}), "continuous rail insertion " + guard.last_reason)
	check(guard.motion_is_safe("leg",parked,Transform3D.IDENTITY,{"xrail":Transform3D.IDENTITY,"zrail":Transform3D.IDENTITY}), "continuous leg insertion " + guard.last_reason)
	for id in ["zrail","leg"]:
		var start := Vector3(0,0,2.2) if id == "zrail" else Vector3(0,-1.8,0)
		var worst := 0.0
		for step in range(41):
			var pose := Transform3D(Basis.IDENTITY,start.lerp(Vector3.ZERO,step/40.0))
			for other in ["xrail","leg"] if id == "zrail" else ["xrail","zrail"]:
				var other_pose := parked if id == "zrail" and other == "leg" else Transform3D.IDENTITY
				worst = maxf(worst,await intersection_volume(id,pose,other,other_pose))
		intersections.append({"moving":id,"samples":41,"maximum_boolean_intersection_volume":worst})
		check(worst < .000001,"sampled boolean path: " + id)
	check(not guard.motion_is_safe("leg",Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(.2,0,0)),assembled),"tenons prevent sideways extraction")
	check(not guard.motion_is_safe("zrail",Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(.18,0,0)),assembled),"vertical mortise walls prevent cross-axis motion")
	var report := {"passed":passed,"failed":failed,"intersections":intersections}
	FileAccess.open("res://tests/zong_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CANDIDATE GEOMETRY: ",passed," passed, ",failed," failed ",intersections)
	quit(0 if failed == 0 else 1)
