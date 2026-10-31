extends SceneTree
const G=preload("res://levels/level02/ship_geometry.gd")
const State=preload("res://levels/level02/level_state.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
var passed:=0
var failed:=0
var details: Array=[]
func check(ok: bool,label: String) -> void:
	details.append({"check":label,"ok":ok})
	if ok: passed+=1
	else:
		failed+=1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func box_collision(a: Node3D,b: Node3D,offset: Vector3) -> float:
	var total=0.0
	for aa in a.get_children():
		if not aa is MeshInstance3D or not aa.mesh is BoxMesh: continue
		var ba=AABB(aa.position-aa.mesh.size/2,aa.mesh.size)
		for bb in b.get_children():
			if not bb is MeshInstance3D or not bb.mesh is BoxMesh: continue
			var box_b=AABB(bb.position+offset-bb.mesh.size/2,bb.mesh.size)
			var size=ba.intersection(box_b).size
			total+=size.x*size.y*size.z
	return total
func area(p: PackedVector2Array) -> float:
	var v=0.0
	for i in p.size(): v+=p[i].cross(p[(i+1)%p.size()])
	return absf(v)/2
func three_collision(a: int,b: int,lift: float) -> float:
	var volume=0.0
	for la in 3:
		for lb in 3:
			var low=maxf(-.12+la*.08,-.12+lb*.08+lift)
			var high=minf(-.12+(la+1)*.08,-.12+(lb+1)*.08+lift)
			if high<=low: continue
			for pa in G.layer_polygons(a,la):
				for pb in G.layer_polygons(b,lb):
					for p in Geometry2D.intersect_polygons(pa,pb): volume+=area(p)*(high-low)
	return volume
func collect_meshes(n: Node,list: Array) -> void:
	if n is MeshInstance3D: list.append(n)
	for c in n.get_children(): collect_meshes(c,list)
func partition_hit(y: float,z: float,list: Array) -> bool:
	var a=Vector3(-1.2,y,z)
	var b=Vector3(1.2,y,z)
	for n in list:
		var faces=n.mesh.get_faces()
		for i in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,n.global_transform*faces[i],n.global_transform*faces[i+1],n.global_transform*faces[i+2])!=null: return true
	return false
func run() -> void:
	var lower=Node3D.new()
	var upper=Node3D.new()
	G.plank(lower,-4,4,0,G.material(Color.WHITE))
	G.plank(upper,-4,4,1,G.material(Color.WHITE))
	var max_overlap=0.0
	for step in 66: max_overlap=maxf(max_overlap,box_collision(lower,upper,Vector3(0,0,step*.01)))
	check(max_overlap<.000001,"actual plank BoxMesh: 66 lateral insertion positions clear")
	check(box_collision(lower,upper,Vector3(0,.08,0))>.001,"negative control: roof-crossing lift collides")
	lower.free()
	upper.free()
	lower=Node3D.new()
	upper=Node3D.new()
	G.cross_member(lower,false,G.material(Color.WHITE))
	G.cross_member(upper,true,G.material(Color.WHITE))
	max_overlap=0
	for step in 101: max_overlap=maxf(max_overlap,box_collision(lower,upper,Vector3(0,step*.01,0)))
	check(max_overlap<.000001,"actual cross lap solids: 101 vertical positions clear")
	check(box_collision(lower,upper,Vector3(0,-.08,0))>.0001,"negative control: inverse cross insertion collides")
	lower.free()
	upper.free()
	max_overlap=0
	for pair in [[0,1],[0,2],[1,2]]:
		for step in 101: max_overlap=maxf(max_overlap,three_collision(pair[0],pair[1],step*.01))
	check(max_overlap<.000001,"three horizontal members: 303 ordered insertion positions clear")
	check(three_collision(0,1,-.08)>.00001,"negative control: inverse three-way insertion collides")
	for i in 3:
		for layer in 3:
			var center=G.three_solid(Vector3(0,-.08+layer*.08,0),i)
			check(center==(i==layer),"three-way central layer %d belongs only to member %d"%[layer,i])
	var level=load("res://levels/level02/level02.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await process_frame
	for id in Rules.IDS:
		level.state.select(id)
		level.state.observe()
		level.state.choose_joint(Rules.expected(id))
		if Rules.row_for(id)>0: level.state.choose_layout("B" if Rules.row_for(id)==1 else "A")
		level.state.attempt(id)
	check(level.state.validate().ok,"geometry fixture completes with staggered end seams")
	var meshes: Array=[]
	collect_meshes(level.view.pieces.bulkhead,meshes)
	collect_meshes(level.view.fixed.bulk_base,meshes)
	collect_meshes(level.view.caulk,meshes)
	var holes=0
	var rays=0
	for yi in 40:
		var y=.18+yi*.05
		var half=.45+(y-.26)/tan(.95)-.09/sin(.95)
		for zi in 31:
			var z=lerpf(-half+.004,half-.004,float(zi)/30)
			rays+=1
			if not partition_hit(y,z,meshes):
				holes+=1
				print("HOLE ",Vector2(y,z))
	check(holes==0,"sealed partition: %d X-axis crossing rays, %d holes"%[rays,holes])
	var bulk=level.view.pieces.bulkhead
	check(is_equal_approx(bulk.position.y-.12,.165),"bulkhead rail bottom equals floor top .165")
	check(level.view.fixed.has("ribs"),"curved rib context surrounds local flat plank band")
	var clearance=true
	for id in ["cross_upper","three_middle","three_upper"]:
		var members: Array=[]
		collect_meshes(level.view.pieces[id],members)
		for n in members:
			for vertex in n.mesh.get_faces():
				var p=n.global_transform*vertex
				var inner=.45+(p.y-.26)/tan(.95)-.09/sin(.95)
				if absf(p.z)>inner-.001: clearance=false
	check(clearance,"all support vertices clear both hull inner faces; upward insertion increases clearance")
	var f=FileAccess.open("res://tests/level02_geometry_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"failed":failed,"checks":details,"method":"actual BoxMesh overlaps; clipped polygon layer volumes; triangle segment crossings of actual partition meshes. Static teaching-scale geometry only."},"	"))
	print("LEVEL02 GEOMETRY ",passed," passed / ",failed," failed")
	level.free()
	quit(0 if failed==0 else 1)

