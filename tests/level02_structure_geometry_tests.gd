extends SceneTree
## Actual surface contacts and the full unchanged teaching assembly, without GUI claims.
const Probe=preload("res://tests/stock_clearance.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func footprints(node: Node3D,height: float) -> Array:
	var result: Array=[]
	for part in Probe.mesh_shapes(node):
		var faces: PackedVector3Array=part.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3=part.pose*faces[i];var b: Vector3=part.pose*faces[i+1];var c: Vector3=part.pose*faces[i+2]
			if absf(a.y-height)<.0001 and absf(b.y-height)<.0001 and absf(c.y-height)<.0001:result.append(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]))
	return result
func supported(stock: Node3D,frame: Node3D,height: float) -> bool:
	for a in footprints(stock,height):
		for b in footprints(frame,height):
			if not Geometry2D.intersect_polygons(a,b).is_empty():return true
	return false
func hull_hit(point: Vector3,parts: Array) -> bool:
	var normal:=Vector3(0,sin(.95),-signf(point.z)*cos(.95))
	for part in parts:
		var faces: PackedVector3Array=part.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit=Geometry3D.segment_intersects_triangle(point-normal*.006,point+normal*.006,part.pose*faces[i],part.pose*faces[i+1],part.pose*faces[i+2])
			if hit!=null:return true
	return false
func rib_surface(frame: Node3D,station: float,height: float,side: int) -> Vector3:
	var outer: float=-INF
	for part in Probe.mesh_shapes(frame):
		var faces: PackedVector3Array=part.mesh.get_faces()
		for i in range(0,faces.size(),3):
			for edge in 3:
				var a: Vector3=part.pose*faces[i+edge];var b: Vector3=part.pose*faces[i+(edge+1)%3]
				if absf(a.x-station)>.071 or absf(b.x-station)>.071 or (a.y-height)*(b.y-height)>0 or absf(a.y-b.y)<.00001:continue
				var point:=a.lerp(b,(height-a.y)/(b.y-a.y));outer=maxf(outer,point.z*side)
	return Vector3(station,height,outer*side)
func run() -> void:
	var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
	for id in level.Rules.IDS:
		level.state.select(id);level.state.observe();level.state.choose_joint(level.Rules.expected(id));level.state.choose_opening(level.state.Openings.target(id))
		if level.Rules.row_for(id)>0:level.state.choose_layout("B" if level.Rules.row_for(id)==1 else "A")
		level.state.attempt(id)
	check(not level.view.fixed.has("support_legs"),"independent stool legs removed")
	for group in [["cross_lower","cross_upper","cross_frame",1.13],["three_lower","three_middle","three_frame",1.33],["three_lower","three_upper","three_frame",1.33]]:
		check(supported(level.view.fixed[group[0]],level.view.fixed[group[2]],group[3]),"fixed receiver actually rests on shell-connected transverse beams "+group[0])
		check(supported(level.view.pieces[group[1]],level.view.fixed[group[2]],group[3]),"installed member actually rests on longitudinal carlings "+group[1])
	var shell: Array=Probe.mesh_shapes(level.view.fixed.far_shell)
	for id in level.Rules.IDS:
		if level.Rules.row_for(id)>=0:shell.append_array(Probe.mesh_shapes(level.view.pieces[id]))
	var touches:=0
	for station in [-3.8,-1.8,1.5,3.5]:
		for y in [.6,1.0,1.6,2.0]:
			for side in [-1,1]:
				var frame: Node3D=level.view.fixed.cross_frame if station<0 else level.view.fixed.three_frame
				var point: Vector3=rib_surface(frame,station,y,side)
				check(is_finite(point.z) and hull_hit(point,shell),"actual rib edge meets planking within small assembly clearance "+str(Vector3(station,y,side)))
				touches+=1
	var probe=Probe.new();var clashes: Array=[]
	for id in ["cross_upper","three_middle","three_upper"]:
		for fixture in ["cross_frame","three_frame","ribs","far_shell","starter"]:
			for a in Probe.mesh_shapes(level.view.pieces[id]):
				for b in Probe.mesh_shapes(level.view.fixed[fixture]):
					if Probe.intersects(a.shape,b.shape) and probe.triangles_intersect(a,b):clashes.append(id+"/"+fixture)
	check(clashes.is_empty(),"correct actual members do not penetrate new frame or shell: "+str(clashes))
	check(level.state.placed.values().map(func(value):return value.joint).has("tongue_groove") and level.state.placed.values().map(func(value):return value.joint).has("cross_lap") and level.state.placed.values().map(func(value):return value.joint).has("three_way_lap"),"all three required types participate in real placed state")
	check(level.state.validate().ok,"unchanged staggered full-hull verdict passes")
	# Check transitional default previews too: a later pending correct board may
	# otherwise intersect earlier loose stock before the player chooses its type.
	for variant in 2:
		level.state.reset();level.view.inspect_selected();probe.violations.clear()
		for id in level.Rules.IDS:
			level.state.select(id);probe.sample(level);level.state.observe()
			var kinds: Array=level.Rules.JOINT_NAMES.keys();var expected: String=level.Rules.expected(id)
			level.state.choose_joint(str(kinds[(kinds.find(expected)+1+variant)%kinds.size()]));probe.sample(level)
			level.state.choose_opening(level.state.Openings.target(id))
			if level.Rules.row_for(id)>0:level.state.choose_layout("B" if level.Rules.row_for(id)==1 else "A")
			var decision: Dictionary=level._physical_decision(id,level.state.installation_result(id))
			if decision.mode==level.state.Assembly.BLOCKED:
				level.state.fail_installation(id,decision.message);break
			var installed: Dictionary=level.state.attempt(id)
			if installed.code=="middle_seated":
				level.state.begin_starter_top(id);level.state.attempt(id)
			level.state.finish_installation(id);probe.sample(level)
			if level.state.failed:break
		check(probe.violations.is_empty(),"both all-wrong sequences and pending choice transitions stay clear: "+str(variant)+" "+str(probe.violations.keys()))
		check(level.state.failed and level.state.placed.size()<=1 and not level.state.checked,"first wrong family stops after its local joint without fabricating a full hull")
	var source:=MeshInstance3D.new();source.mesh=BoxMesh.new()
	var section:=Node3D.new();root.add_child(section)
	load("res://levels/level02/inspection_context.gd").append(section,source,Transform3D(Basis.from_scale(Vector3(1,1,-1)),Vector3.ZERO),-.3,.3,.25)
	var outward:=true
	for mesh in section.get_children():
		var arrays: Array=mesh.mesh.surface_get_arrays(0);var center: Vector3=mesh.get_aabb().get_center()
		for index in arrays[Mesh.ARRAY_VERTEX].size():
			if arrays[Mesh.ARRAY_NORMAL][index].dot(arrays[Mesh.ARRAY_VERTEX][index]-center)<-.0001:outward=false
	check(outward,"mirrored actual shell section and fresh cut faces keep outward normals")
	source.free();section.free();probe.free();level.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"hull_surface_contacts":touches,"method":"actual mesh triangle contact patches and shell surface rays, independent narrow-phase guard; pure State setup, not GUI or engineering simulation"}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/hull-structure")
	FileAccess.open("res://tests/evidence/hull-structure/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("HULL_STRUCTURE_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
