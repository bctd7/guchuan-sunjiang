extends SceneTree
## Verify actual solids, not only a lookup table: openings move while stock sizes stay fixed.
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Boat=preload("res://models/ship/hull/boat_joints.gd")
const Openings=preload("res://levels/level02/opening_rules.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if ok:passed+=1
	else:failures.append(message);push_error(message)
func boxes(a: Node3D,b: Node3D,offset:=Vector3.ZERO) -> float:
	var total:=0.0
	for aa in a.get_children():
		if not aa is MeshInstance3D or not aa.mesh is BoxMesh:continue
		var x:=AABB(aa.position-aa.mesh.size/2.0,aa.mesh.size)
		for bb in b.get_children():
			if not bb is MeshInstance3D or not bb.mesh is BoxMesh:continue
			var y:=AABB(bb.position+offset-bb.mesh.size/2.0,bb.mesh.size)
			var size:=x.intersection(y).size;total+=size.x*size.y*size.z
	return total
func polygon_area(poly: PackedVector2Array) -> float:
	var area:=0.0
	for i in poly.size():area+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(area)*.5
func three_overlap(first: int,first_opening: String,second: int,second_opening: String) -> float:
	var total:=0.0
	for layer in 3:
		for a in Boat.three_polygons(first,layer,first_opening):
			for b in Boat.three_polygons(second,layer,second_opening):
				for intersection in Geometry2D.intersect_polygons(a,b):total+=polygon_area(intersection)*.08
	return total
func signature(node: Node) -> String:
	var result:=str(node.transform) if node is Node3D else ""
	if node is MeshInstance3D:result+=str(node.mesh.get_faces())
	for child in node.get_children():result+=signature(child)
	return result
func bounds(node: Node,pose:=Transform3D.IDENTITY) -> AABB:
	var transform: Transform3D=pose*node.transform if node is Node3D else pose
	var result:=AABB();var initialized:=false
	if node is MeshInstance3D:result=transform*node.get_aabb();initialized=true
	for child in node.get_children():
		var box:=bounds(child,transform)
		if box.size.length_squared()>0:result=result.merge(box) if initialized else box;initialized=true
	return result
func run() -> void:
	var material:=G.material(Color.WHITE)
	for row in [1,2]:
		var lower:=Node3D.new();G.plank(lower,-4,4,row-1,material,0,Openings.next_groove(row-1),true)
		for option in Openings.OPTIONS:
			var upper:=Node3D.new();var id:="plank_%da"%row;G.plank(upper,-4,4,row,material,Openings.offset(id,option),Openings.next_groove(row),true)
			var overlap:=boxes(lower,upper)
			check(overlap<.000001 if option==Openings.target(id) else overlap>.0001,"actual shifted plank opening matches receiver only for its physical position row "+str(row)+"/"+option)
			upper.free()
		lower.free()
	for id in ["cross_upper","bulkhead"]:
		var lower:=Node3D.new();Boat.cross_member(lower,false,material,"C",1.86 if id=="cross_upper" else 1.4)
		for option in Openings.OPTIONS:
			var upper:=Node3D.new()
			if id=="cross_upper":Boat.cross_member(upper,true,material,option)
			else:Boat.bulkhead_foot(upper,material,option)
			var overlap:=boxes(upper,lower)
			var seated: bool=option==Openings.target(id) or option=="B"
			check(overlap<.000001 if seated else overlap>.00001,"actual boat mouth has full seating or an obstructing shoulder "+id+"/"+option)
			upper.free()
		lower.free()
	for pair in [[0,"C",1,"C"],[0,"C",2,"A"],[1,"C",2,"A"]]:check(three_overlap(pair[0],pair[1],pair[2],pair[3])<.000001,"correct three-way layers have no overlapping solid "+str(pair))
	for option in ["A","B"]:
		check(three_overlap(0,"C",1,option)<.000001,"wrong middle lower mouth still fits lower member "+option)
		check(three_overlap(1,option,2,"A")>.00001,"wrong middle upper channel physically blocks the final member "+option)
	for option in ["B","C"]:check(three_overlap(0,"C",2,option)>.00001,"wrong final mouth physically interferes with lower member "+option)
	var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
	for id in level.Rules.IDS:
		var models: Array=[]
		for option in Openings.OPTIONS:models.append(level.view.candidate_opening(id,option))
		check(signature(models[0])!=signature(models[1]) and signature(models[1])!=signature(models[2]),"opening geometry really differs "+id)
		check(bounds(models[0]).is_equal_approx(bounds(models[1])) and bounds(models[1]).is_equal_approx(bounds(models[2])),"all opening candidates retain identical stock dimensions "+id)
		for model in models:model.free()
	level.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"method":"Actual BoxMesh intersections, clipped layer polygon intersections, and all ten preview stock bounds/mesh signatures; no physics simulation claim"}
	FileAccess.open("res://tests/opening_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPENING_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
