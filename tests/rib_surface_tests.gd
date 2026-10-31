extends SceneTree
## Geometric visibility tests run without a renderer. Each ray compares the
## physical first surface with the first clockwise face a back-culling camera sees.
const Geometry = preload("res://models/ship/keel/ship_geometry.gd")
const Preview = preload("res://levels/level01/candidate_preview.gd")
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
const Lengths = preload("res://models/ship/keel/length_geometry.gd")
var passed := 0
var failed := 0
const OUTLINE = [Vector2(.55,.56),Vector2(1.22,.62),Vector2(1.92,.98),Vector2(2.43,1.50),Vector2(2.73,1.86),Vector2(2.96,1.86),Vector2(2.69,1.30),Vector2(2.12,.64),Vector2(1.34,.25),Vector2(.55,.10)]

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func edge_key(a: Vector3, b: Vector3) -> Array:
	var first := str(a.snapped(Vector3.ONE*.00001))
	var second := str(b.snapped(Vector3.ONE*.00001))
	return [first+"/"+second,1] if first < second else [second+"/"+first,-1]

func faces_of(mesh: Mesh) -> PackedVector3Array:
	# get_faces() uses Godot's snapped collision triangle cache. Inspect the
	# renderer's actual vertex/index arrays, including narrow bore-wall facets.
	if not mesh is ArrayMesh: return mesh.get_faces()
	var result := PackedVector3Array()
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty(): result.append_array(vertices)
		else:
			for i in indices: result.append(vertices[i])
	return result

func topology(mesh: Mesh) -> Dictionary:
	var faces := faces_of(mesh)
	var edges := {}
	var volume := 0.0
	var degenerate := 0
	for i in range(0,faces.size(),3):
		var cross := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i])
		if cross.length_squared() < 1e-12: degenerate += 1
		volume += faces[i].dot(faces[i+1].cross(faces[i+2]))/6.0
		for corner in 3:
			var key := edge_key(faces[i+corner],faces[i+(corner+1)%3])
			var use: Vector2i = edges.get(key[0],Vector2i.ZERO)
			edges[key[0]] = use+Vector2i(1,key[1])
	var boundary := 0
	var inconsistent := 0
	for use: Vector2i in edges.values():
		if use.x != 2: boundary += 1
		if use.y != 0: inconsistent += 1
	return {"volume":volume,"boundary":boundary,"inconsistent":inconsistent,"degenerate":degenerate}

func snapshot(node: Node) -> Array:
	var result: Array = [node.name,node.get_meta_list()]
	for key in node.get_meta_list(): result.append(node.get_meta(key))
	if node is Node3D: result.append([node.transform,node.visible])
	if node is MeshInstance3D:
		result.append([node.mesh,node.mesh.get_faces(),node.material_override])
		var mat := node.material_override as StandardMaterial3D
		if mat: result.append([mat.albedo_color,mat.transparency,mat.cull_mode,mat.albedo_texture,mat.uv1_scale])
	for child in node.get_children(): result.append(snapshot(child))
	return result

func first_hit(mesh: Mesh, origin: Vector3, direction: Vector3, front_only: bool) -> float:
	var nearest := INF
	var faces := faces_of(mesh)
	for i in range(0,faces.size(),3):
		var cross := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i])
		if front_only and cross.dot(direction) <= 0.0000001: continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
		if hit != null: nearest = minf(nearest,origin.distance_to(hit))
	return nearest

func validate_rib(body: MeshInstance3D, side: float, label: String) -> void:
	var mesh := body.mesh
	var stats := topology(mesh)
	print(label," topology: ",stats)
	check(stats.boundary == 0 and stats.inconsistent == 0 and stats.degenerate == 0,label+": closed oriented manifold, no split caps")
	var polygon := PackedVector2Array()
	for point in OUTLINE: polygon.append(Vector2(point.x*side,point.y))
	var area := 0.0
	for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])*.5
	check(is_equal_approx(stats.volume,-absf(area)*.46),label+": signed volume matches original extruded outline")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var expected_vertices := {}
	for point in polygon:
		for z in [-.23,.23]: expected_vertices[Vector3(point.x,point.y,z)] = false
	var exact_outline := true
	for point in vertices:
		if not expected_vertices.has(point): exact_outline = false
		else: expected_vertices[point] = true
	check(exact_outline and not expected_vertices.values().has(false),label+": every original outline coordinate retained at both depths")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := -(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
		# ArrayMesh packs normals; allow encoding precision, never reversed/smoothed faces.
		check(normals[a].dot(normal) > .99999 and normals[b].dot(normal) > .99999 and normals[c].dot(normal) > .99999,label+": hard face normals follow clockwise front")
		var center := (vertices[a]+vertices[b]+vertices[c])/3.0
		if absf(normal.z) > .99:
			check(normal.z*center.z > 0,label+": front/back cap normals face outside")
		else:
			var inward := Vector2(center.x-normal.x*.0001,center.y-normal.y*.0001)
			var outward := Vector2(center.x+normal.x*.0001,center.y+normal.y*.0001)
			check(Geometry2D.is_point_in_polygon(inward,polygon) and not Geometry2D.is_point_in_polygon(outward,polygon),label+": side normal points out of actual concave outline")
	# Dense samples of the original cap include the narrow root/shoulder and the
	# bent upper limb. Sixteen cameras expose either cap, edge, top and underside.
	var samples: Array[Vector3] = []
	for xi in 25:
		for yi in 19:
			var p := Vector2(side*(.575+xi*.098),.125+yi*.095)
			if Geometry2D.is_point_in_polygon(p,polygon): samples.append(Vector3(p.x,p.y,0))
	samples.append(Vector3(side*.56,.38,0))
	samples.append(Vector3(side*.80,.40,0))
	check(samples.size() > 80,label+": visibility samples cover curved stock as well as root")
	for z in [-1.0,1.0]:
		for direction in [Vector3(side*2,2.6,z*3.8),Vector3(-side*2,2.6,z*3.8),Vector3(side*4,.3,z),Vector3(-side*4,.3,z),Vector3(.1,4,z),Vector3(.1,-4,z),Vector3(.1,.1,z*4),Vector3(side*2,-2.6,z*3.8)]:
			var visible := true
			for target in samples:
				var origin: Vector3 = target+direction.normalized()*8.0
				var ray: Vector3 = (target-origin).normalized()
				var physical := first_hit(mesh,origin,ray,false)
				var front := first_hit(mesh,origin,ray,true)
				if not is_finite(physical) or not is_finite(front) or absf(physical-front) > .0001: visible = false
			check(visible,label+": first surface visible from "+str(direction))
	check(Preview.outward_mesh(mesh) == mesh,label+": generator requires no preview winding repair")

func make_mesh(faces: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in faces: surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

func part_faces(node: Node3D, pose := Transform3D.IDENTITY) -> PackedVector3Array:
	var result := PackedVector3Array()
	pose = pose*node.transform
	if node is MeshInstance3D:
		for point in faces_of(node.mesh): result.append(pose*point)
	for child in node.get_children():
		if child is Node3D: result.append_array(part_faces(child,pose))
	return result

func segment_hits(faces: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(from,to,faces[i],faces[i+1],faces[i+2]) != null: return true
	return false

func validate_joint_voids(part: Node3D, id: String, label: String) -> void:
	var faces := part_faces(part.get_child(0))
	var station: float = Geometry.STATIONS[int(id.right(1))-1]
	var side := -1.0 if id.begins_with("rib_l") else 1.0
	var has_hole := not id.ends_with("2")
	check(segment_hits(faces,Vector3(side*3.3,2.34,station),Vector3(side*2.3,2.34,station)) != has_hole,label+": transverse mortise remains a real opening (middle rib solid)")
	for sample in [Vector2(1.99,0),Vector2(2.67,0),Vector2(2.34,.205),Vector2(2.34,-.205)]:
		check(segment_hits(faces,Vector3(side*3.3,sample.x,station+sample.y),Vector3(side*2.3,sample.x,station+sample.y)),label+": actual top/bottom/front/back cheek retained")
	check(segment_hits(faces,Vector3(side*.05,.38,station),Vector3(side*.8,.38,station)),label+": real root tenon and shoulder retained")

func test_repair_guard() -> void:
	var cube := BoxMesh.new().get_faces()
	var reversed := cube.duplicate()
	for i in range(0,reversed.size(),3):
		var point := reversed[i+1]
		reversed[i+1] = reversed[i+2]
		reversed[i+2] = point
	var inward := make_mesh(reversed)
	var repaired := Preview.outward_mesh(inward)
	check(repaired != inward and topology(repaired).volume < 0,"Consistently inward closed stock can be reversed")
	check(topology(repaired).inconsistent == 0,"Whole-stock reversal retains oriented edges")
	check(topology(inward).volume > 0,"Repair leaves shared source mesh untouched")
	var broken := reversed.duplicate()
	var point := broken[1]
	broken[1] = broken[2]
	broken[2] = point
	var mixed := make_mesh(broken)
	check(Preview.outward_mesh(mixed) == mixed,"Mixed winding rejected despite every undirected edge occurring twice")
	var multiple := reversed.duplicate()
	multiple.append_array(reversed)
	var overlapping := make_mesh(multiple)
	check(Preview.outward_mesh(overlapping) == overlapping,"Four uses of a shared edge is not closed manifold stock")
	var open := make_mesh(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]))
	check(Preview.outward_mesh(open) == open,"Open surface has no inferred outward direction")

func test_length_surfaces() -> void:
	for length in ["short","correct","long"]:
		var span := Lengths.span("bow",length)
		var dovetail := Lengths._dovetail(4.45-span,4.45)
		var stats := topology(dovetail)
		check(stats.boundary == 0 and stats.inconsistent == 0 and stats.volume < 0,"Length dovetail "+length+": consistently outward closed stock")
		check(Preview.outward_mesh(dovetail) == dovetail,"Length dovetail "+length+": no preview winding repair needed")
		for direction in [Vector3(2.5,1.4,-3.8),Vector3(-2.5,1.4,3.8),Vector3(0,-4,1),Vector3(4,0,1)]:
			var target := Vector3(0,.46,4.45-span*.5)
			var origin: Vector3 = target+direction.normalized()*8
			var ray: Vector3 = (target-origin).normalized()
			check(is_equal_approx(first_hit(dovetail,origin,ray,false),first_hit(dovetail,origin,ray,true)),"Length dovetail "+length+": first cap/side surface visible "+str(direction))
		span = Lengths.span("beam1",length)
		var beam := Lengths._drilled_beam(span)
		var faces := faces_of(beam)
		stats = topology(beam)
		check(stats.volume < 0 and stats.degenerate == 0,"Drilled beam "+length+": unchanged positive stock volume and no degenerate faces")
		check(absf(stats.volume-(-span*.26*.30+2*PI*Lengths.PIN_RADIUS*Lengths.PIN_RADIUS*.26)) < .00002,"Drilled beam "+length+": unchanged stock minus two physical bores")
		check(Preview.outward_mesh(beam) == beam,"Drilled beam "+length+": preview does not infer winding at shared T junctions")
		var center := span*.5-Lengths.PIN_END_DISTANCE
		for x in [-center,center]:
			check(not segment_hits(faces,Vector3(x,-1,0),Vector3(x,1,0)),"Drilled beam "+length+": vertical pin hole stays open")
			check(segment_hits(faces,Vector3(x+.05,-1,0),Vector3(x+.05,1,0)),"Drilled beam "+length+": stock surrounds each bore")
			for interface_x in [x-.06,x+.06]:
				check(not segment_hits(faces,Vector3(interface_x-.005,.02,.09),Vector3(interface_x+.005,.02,.09)),"Drilled beam "+length+": no internal stock/ring sheets")
		var outward := true
		for i in range(0,faces.size(),3):
			var point := (faces[i]+faces[i+1]+faces[i+2])/3
			var normal := -(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			var face_ok := true
			if is_equal_approx(absf(point.y),.13): face_ok = normal.y*point.y > .129
			elif is_equal_approx(absf(point.z),.15): face_ok = normal.z*point.z > .149
			elif is_equal_approx(absf(point.x),span*.5): face_ok = normal.x*point.x > span*.49
			else:
				var bore_center := Vector3(-center if point.x < 0 else center,point.y,0)
				face_ok = normal.dot((bore_center-point).normalized()) > .99
			outward = outward and face_ok
		check(outward,"Drilled beam "+length+": each exposed face points outside stock or into bore; no internal caps")

func run() -> void:
	var mat := Geometry.material(Color("b89569"))
	Geometry.add_subtle_grain(mat,Vector3(.35,5,5))
	var builder = Geometry.new(mat,mat,mat)
	var source = load("res://levels/level01/skeleton_view.gd").new()
	# A real source also exercises no-op guards and shared resource isolation.
	root.add_child(source)
	await process_frame
	for id in ["rib_l1","rib_r1","rib_l2","rib_r2","rib_l3","rib_r3"]:
		var part := Node3D.new()
		builder.build(part,id)
		var side := -1.0 if id.begins_with("rib_l") else 1.0
		var body := part.get_child(0).get_child(0) as MeshInstance3D
		validate_rib(body,side,id+" source")
		validate_joint_voids(part,id,id+" source")
		check(body.material_override.cull_mode == BaseMaterial3D.CULL_BACK,id+": source uses regular back-face culling")
		var unchanged := snapshot(part)
		for length in ["short","correct","long"]:
			var clone := part.duplicate() as Node3D
			Lengths.apply(clone,id,length)
			var before := snapshot(clone)
			Candidate.apply(clone,id,"blind_tenon",source)
			check(snapshot(clone) == before,id+length+": correct candidate exact no-op")
			Preview.solidify(clone)
			validate_joint_voids(clone,id,id+length+" preview")
			check(snapshot(part) == unchanged,id+length+": preview leaves all source resources and poses untouched")
			var clone_body := clone.get_child(0).get_child(0) as MeshInstance3D
			check(clone_body.mesh == body.mesh,id+length+": correct generated body remains shared and unmodified")
			check(clone_body.material_override != body.material_override,id+length+": preview material is private")
			check(clone_body.material_override.albedo_texture == body.material_override.albedo_texture and clone_body.material_override.uv1_scale == body.material_override.uv1_scale,id+length+": original grain retained")
			var tip := clone.find_child("RootTenon",true,false) as MeshInstance3D
			check(is_equal_approx(tip.mesh.get_aabb().size.x,Lengths.span(id,length)),id+length+": real tenon length retained")
			check(is_equal_approx(absf(tip.position.x)+tip.mesh.get_aabb().size.x*.5,.55),id+length+": actual tenon meets original shoulder")
			clone.free()
		part.free()
	test_repair_guard()
	test_length_surfaces()
	source.free()
	print("RIB_SURFACE: ",passed," passed; ",failed," failed")
	quit(1 if failed else 0)
