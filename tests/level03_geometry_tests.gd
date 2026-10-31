extends SceneTree
const G = preload("res://models/ship/rigging/ship_geometry.gd")
var level: Node3D
var passed := 0
var failures: Array[String] = []
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks.append({"check":text,"ok":ok})
	if ok:
		passed += 1
		print("PASS ",text)
	else:
		failures.append(text)
		push_error(text)
func inside(node: Node, world_point: Vector3) -> bool:
	if node is MeshInstance3D:
		var point: Vector3 = node.global_transform.affine_inverse()*world_point
		if node.get_aabb().grow(.0001).has_point(point):
			var ray_end := point+Vector3(31.731,19.337,23.733)
			var hits: Array[float] = []
			var faces: PackedVector3Array = node.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var hit = Geometry3D.segment_intersects_triangle(point,ray_end,faces[i],faces[i+1],faces[i+2])
				if hit == null: continue
				var distance: float = point.distance_to(hit)
				var duplicate := false
				for old in hits:
					if absf(old-distance) < .00001: duplicate = true
				if not duplicate: hits.append(distance)
			if hits.size()%2 == 1: return true
	for child in node.get_children():
		if inside(child,world_point): return true
	return false
func points_for(node: Node, output: Array) -> void:
	if node is MeshInstance3D:
		var faces: PackedVector3Array = node.mesh.get_faces()
		var stride := maxi(3,int(ceil(float(faces.size())/180.0/3.0))*3)
		for i in range(0,faces.size(),stride):
			var a: Vector3 = node.global_transform*faces[i]
			var b: Vector3 = node.global_transform*faces[i+1]
			var c: Vector3 = node.global_transform*faces[i+2]
			var middle := (a+b+c)/3.0
			var n := (b-a).cross(c-a).normalized()*.004
			for point in [middle+n,middle-n]:
				if inside(node,point): output.append(point)
	for child in node.get_children(): points_for(child,output)
func sweep(source: Node3D, targets: Array, start: Vector3, label: String) -> void:
	var points: Array = []
	points_for(source,points)
	var collision := false
	var contact: Vector3
	for step in 17:
		var offset := start*(1.0-float(step)/16.0)
		for point in points:
			for target in targets:
				if inside(target,point+offset):
					collision = true
					contact = point+offset
		if collision: break
	check(not collision,label+" (17 poses / "+str(points.size())+" interior surface samples)")
	if collision: print("COLLISION ",label," at ",contact)
func run() -> void:
	level = load("res://levels/level03/level03.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await process_frame
	var view = level.view
	var frame = view.stages[0]
	var fork = view.stages[1].get_node("MastTopForkAndTwinTenons")
	var post = view.stages[2].get_node("SternPostSteppedSocket")
	check(not inside(frame.get_node("MastBedSquareSocket"),Vector3(2.7,.7,2.5)),"mast bed has actual open square cavity")
	check(inside(frame.get_node("MastBedSquareSocket"),Vector3(2.7,.2,2.5)),"mast socket retains solid bottom")
	check(not inside(fork,Vector3(0,.1,0)),"mast-top fork gap really open")
	check(inside(fork,Vector3(0,-.3,0)),"fork gap has supporting lower shoulder")
	check(inside(fork,Vector3(0,.45,.3)) and inside(fork,Vector3(0,.45,-.3)),"two distinct top tenons")
	check(not inside(view.pieces.top,Vector3(0,.5,.3)) and not inside(view.pieces.top,Vector3(0,.5,-.3)),"top board has two actual underside sockets")
	check(inside(view.pieces.top,Vector3(0,.65,.3)),"top sockets retain sealed upper wall")
	check(not inside(post,Vector3(.3,.15,0)),"L socket larger rear portion open")
	check(not inside(post,Vector3(-.5,-.18,0)),"L socket small front outlet open")
	check(inside(post,Vector3(-.5,.15,0)),"L socket upper front remains solid, unlike ordinary through hole")
	check(inside(view.pieces.lbrace,Vector3(-.5,-.18,0)) and not inside(view.pieces.lbrace,Vector3(-.5,.15,0)),"L tenon has actual small leading step")
	var bearing = view.pieces.lbrace.get_node("IndependentRoundBearing")
	check(not inside(bearing,Vector3(2.3,.66,0)),"round bearing axial center is clear")
	check(not inside(bearing,Vector3(2.499,.66,0)) and inside(bearing,Vector3(2.501,.66,0)),"actual bearing mesh inner radius is 0.20")
	check(inside(view.pieces.rudder,Vector3(2.469,.4,0)) and not inside(view.pieces.rudder,Vector3(2.471,.4,0)),"actual round shaft mesh radius is 0.17")
	check(not inside(view.pieces.lbrace,Vector3(2.3,0,0)),"round opening continues through timber below bearing")
	sweep(view.pieces.zrail,[frame.get_node("ShipZong_xrail")],Vector3(0,0,1.65),"horizontal miter rail path stays clear")
	sweep(view.pieces.leg,[frame.get_node("ShipZong_xrail"),view.pieces.zrail],Vector3(0,-1.65,0),"long/short corner tenons enter from below without collision")
	sweep(view.pieces.mast,[frame.get_node("MastBedSquareSocket")],Vector3(0,1.6,0),"square mast foot enters actual bed")
	sweep(view.pieces.apron,[fork],Vector3(0,1.1,0),"apron drops between fork cheeks")
	sweep(view.pieces.top,[fork,view.pieces.apron],Vector3(0,1.4,0),"support board receives fork twin tenons")
	sweep(view.pieces.lbrace,[post],Vector3(1.65,0,0),"stepped L beam enters matching stepped slot")
	sweep(view.pieces.rudder,[view.pieces.lbrace],Vector3(0,2.6,0),"bare round axle and upper shoulder never pass through bearing walls")
	# Back half + blade enter from -Z; opposite cap remains parked at +Z.
	var blade = view.pieces.blade
	var cap = blade.get_node("SideCap")
	blade.remove_child(cap)
	sweep(blade,[view.pieces.rudder,view.pieces.lbrace],Vector3(0,0,-1.5),"open back collar and blade slide onto shaft from side")
	blade.add_child(cap)
	sweep(cap,[view.pieces.rudder],Vector3(0,0,1.3),"opposite semicollar closes from the other side")
	var report := {"passed":passed,"failed":failures.size(),"failures":failures,"checks":checks,"method":"actual triangle mesh ray parity, interior surface samples and 17-pose insertion sweeps; teaching-scale test"}
	var file := FileAccess.open("res://tests/level03_geometry_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("LEVEL03_GEOMETRY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
