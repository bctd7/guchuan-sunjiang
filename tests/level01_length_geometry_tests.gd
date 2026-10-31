extends SceneTree
const Length = preload("res://levels/level01/length_geometry.gd")
const Geometry = preload("res://levels/level01/ship_geometry.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func triangles(node: Node3D, parent_pose := Transform3D.IDENTITY, visible_only := false) -> PackedVector3Array:
	var result := PackedVector3Array()
	if visible_only and not node.visible: return result
	var pose: Transform3D = parent_pose*node.transform
	if node is MeshInstance3D:
		for v in node.mesh.get_faces(): result.append(pose*v)
	for child in node.get_children():
		if child is Node3D: result.append_array(triangles(child,pose,visible_only))
	return result

func hits(faces: PackedVector3Array, start: Vector3, finish: Vector3, ignore_endpoints := false) -> int:
	var count := 0
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,faces[i],faces[i+1],faces[i+2])
		if hit == null: continue
		if ignore_endpoints and ((hit as Vector3).distance_to(start)<.0001 or (hit as Vector3).distance_to(finish)<.0001): continue
		count += 1
	return count

func snapshot(node: Node) -> Array:
	var result: Array = []
	if node is Node3D: result.append([node.transform,node.visible])
	if node is MeshInstance3D:
		var mat := node.material_override as StandardMaterial3D
		result.append([node.mesh.get_faces(),mat.albedo_color if mat else Color.WHITE,mat.roughness if mat else 0.0])
	for child in node.get_children(): result.append(snapshot(child))
	return result

func run() -> void:
	var mat := Geometry.material(Color("b89569"))
	var builder = Geometry.new(mat,mat,mat)
	var keel := Node3D.new()
	builder.build(keel,"keel")
	var keel_faces := triangles(keel)
	for id in ["rib_l1","rib_r1","rib_l2","rib_r3","bow","stern","beam1","beam3"]:
		var original := Node3D.new()
		builder.build(original,id)
		var unchanged := snapshot(original)
		for length in ["short","correct","long"]:
			var clone := original.duplicate() as Node3D
			var root_pose := clone.transform
			Length.apply(clone,id,length)
			check(clone.transform == root_pose,"apply retains caller root pose: "+id+length)
			check(snapshot(original) == unchanged,"Shared original untouched: "+id+length)
			var clone_mesh: MeshInstance3D = clone.find_child("RootTenon",true,false) if id.begins_with("rib_") else (clone.get_child(0).get_child(0) if id in ["bow","stern"] else clone.get_child(0))
			var original_mesh: MeshInstance3D = original.find_child("RootTenon",true,false) if id.begins_with("rib_") else (original.get_child(0).get_child(0) if id in ["bow","stern"] else original.get_child(0))
			check(clone_mesh.mesh != original_mesh.mesh,"Length mesh belongs to clone: "+id+length)
			var once := snapshot(clone)
			Length.apply(clone,id,length)
			check(snapshot(clone) == once,"Idempotent geometry: "+id+length)
			var size: float = Length.span(id,length)
			clone.transform = Length.seated_pose(id,length)
			check(clone.basis.is_equal_approx(Basis.IDENTITY),"Seating has no collision-inducing tilt: "+id+length)
			if id.begins_with("rib_"):
				var tip := clone.find_child("RootTenon",true,false) as MeshInstance3D
				check(is_equal_approx(tip.mesh.get_aabb().size.x,size),"Real root tenon span: "+id+length)
				var side := -1.0 if id.begins_with("rib_l") else 1.0
				var tip_x := absf(tip.position.x+clone.position.x)-size*.5
				check(tip_x >= .10,"Root tenon never crosses central web: "+id+length)
				check(is_equal_approx(tip_x,.11 if length == "long" else .55-size),"Root insertion depth: "+id+length)
				check(is_equal_approx(absf(tip.position.x)+size*.5,.55),"Shoulder local anchor: "+id+length)
			elif id in ["bow","stern"]:
				var tip := clone.get_child(0).get_child(0) as MeshInstance3D
				var bounds := tip.mesh.get_aabb()
				check(is_equal_approx(bounds.size.z,size),"Real dovetail span: "+id+length)
				check(is_equal_approx(bounds.end.z,4.45),"Dovetail local shoulder anchor: "+id+length)
				var direction := -1.0 if id == "bow" else 1.0
				var world_min := (bounds.position.z+absf(clone.position.z))
				check(world_min >= 3.50,"Dovetail does not enter closed keel: "+id+length)
				for vertex in triangles(clone):
					check(hits(keel_faces,vertex+Vector3(0,0,direction*1.8),vertex,true)==0,"Open-end insertion clears real stock: "+id+length)
			else:
				var body := clone.get_child(0) as MeshInstance3D
				check(is_equal_approx(body.mesh.get_aabb().size.x,size),"Real beam span: "+id+length)
				check(body.mesh.get_aabb().size.is_equal_approx(Vector3(size,.26,.30)),"Uniform beam section: "+id+length)
				var faces := triangles(body)
				var hole_x := size*.5-Length.PIN_END_DISTANCE
				var station: float = body.position.z
				for side in [-1.0,1.0]:
					check(hits(faces,Vector3(side*hole_x,2.0,station),Vector3(side*hole_x,2.7,station))==0,"True open vertical bore: "+id+length)
					check(hits(faces,Vector3(side*hole_x+.055,2.0,station),Vector3(side*hole_x+.055,2.7,station))>=2,"Wood remains around bore: "+id+length)
					check(hits(faces,Vector3(side*hole_x,2.34,station),Vector3(side*hole_x+.055,2.34,station))>0,"Bore has real interior wall: "+id+length)
				var pins := clone.get_node("LengthFasteners") as Node3D
				check(not pins.visible,"Pins hidden until insertion finishes: "+id+length)
				Length.set_fasteners_visible(clone,true)
				check(pins.visible == (length != "short"),"Only accessible pins can be fitted: "+id+length)
				for pin in pins.get_children():
					check(is_equal_approx(pin.mesh.top_radius,Length.PIN_RADIUS),"Pin and bore radius agree: "+id+length)
					check(is_equal_approx(absf(pin.position.x),hole_x),"Pin centered in bore: "+id+length)
					# Test the real CylinderMesh silhouette against the actual bore,
					# just inside its boundary to exclude coincident contact surfaces.
					for vertex in pin.mesh.get_faces():
						var p: Vector3 = pin.position+Vector3(vertex.x*.999,0,vertex.z*.999)
						check(hits(faces,Vector3(p.x,2.0,p.z),Vector3(p.x,2.7,p.z))==0,"Pin fits actual round bore without crossing wood: "+id+length)
					if length != "short": check(absf(pin.position.x)-Length.PIN_RADIUS>=2.97-.0001,"Pin outside receiving rib solid: "+id+length)
				var data: Dictionary = Length.measurement(id,length)
				check(is_equal_approx(data.axial_play,.35 if length == "long" else 0.0),"Real clearance explains beam play: "+id+length)
				# Both mortises remain clear during the full axial insertion path.
				var receivers := PackedVector3Array()
				for side in ["l","r"]:
					var rib := Node3D.new()
					builder.build(rib,"rib_"+side+("1" if id == "beam1" else "3"))
					receivers.append_array(triangles(rib))
					rib.free()
				for vertex in faces:
					check(hits(receivers,vertex+Vector3(7.2,0,0),vertex,true)==0,"Beam fits uniform through path: "+id+length)
				Length.set_fasteners_visible(clone,false)
				check(not pins.visible,"Pins hide for inspection or removal: "+id+length)
			# Switching length reuses neither the original nor the previous mesh.
			Length.apply(clone,id,"correct")
			check(snapshot(original) == unchanged,"Switch length preserves source: "+id+length)
			clone.free()
		original.free()
	keel.free()
	check(is_equal_approx(Length.reference_span("bow"),.95),"Reference dovetail groove span")
	check(is_equal_approx(Length.reference_span("beam1"),6.32),"Reference beam span")
	check(is_equal_approx(Length.reference_span("rib_r1"),.45),"Reference blind slot span")
	print("LEVEL01_LENGTH_GEOMETRY: ",passed," passed; ",failed," failed")
	quit(1 if failed else 0)
