extends RefCounted
## Broad bounds plus exact convex cells for the ship's extruded joint solids.
const Cells=preload("res://models/ship/hull/contact_cells.gd")
const GAP:=.012
const REST_GAP:=.0012
# Exceed mesh quantization and the independent triangle guard's contact padding.
# Wrong stock must stop outside an edge, not rely on a zero-clearance sliver.
const EDGE_CLEARANCE:=.0002
static func meshes(root: Node3D,pose: Transform3D) -> Array:
	var result: Array=[]
	for child in root.get_children():_meshes(child,pose,result)
	return result
static func _meshes(node: Node,pose: Transform3D,result: Array) -> void:
	if node is Node3D:pose*=node.transform
	if node is MeshInstance3D:result.append({"mesh":node.mesh,"pose":pose})
	for child in node.get_children():_meshes(child,pose,result)
static func points(parts: Array) -> Array[Vector3]:
	var output: Array[Vector3]=[]
	for part in parts:
		for vertex in part.mesh.get_faces():output.append(part.pose*vertex)
	return output
static func bounds(parts: Array) -> AABB:
	var vertices:=points(parts);var box:=AABB(vertices[0],Vector3.ZERO)
	for point in vertices:box=box.expand(point)
	return box
static func _axis(axes: Array[Vector3],value: Vector3) -> void:
	if value.length_squared()<.00000001:return
	value=value.normalized()
	for axis in axes:
		if absf(axis.dot(value))>.99999:return
	axes.append(value)
static func box(part: Dictionary) -> Dictionary:
	# Keep a broad outer hull, then test prism cells without filling concavities.
	var geometry: Dictionary=part.mesh.get_meta("trial_contact_geometry",{})
	if geometry.is_empty():
		var local_vertices: Array[Vector3]=[];var local_normals: Array[Vector3]=[];var local_edges: Array[Vector3]=[]
		if part.mesh.has_meta("joinery_contact_cells"):
			# AABB is broad phase only. Curved timber uses its actual small cells
			# below, so rebuilding thousands of outer SAT axes adds no accuracy.
			var aabb: AABB=part.mesh.get_aabb()
			for x in [aabb.position.x,aabb.end.x]:
				for y in [aabb.position.y,aabb.end.y]:
					for z in [aabb.position.z,aabb.end.z]:local_vertices.append(Vector3(x,y,z))
			local_normals.assign([Vector3.RIGHT,Vector3.UP,Vector3.BACK]);local_edges.assign(local_normals)
		else:
			var faces: PackedVector3Array=part.mesh.get_faces()
			for vertex in faces:
				if not local_vertices.has(vertex):local_vertices.append(vertex)
			for index in range(0,faces.size(),3):
				var a:=faces[index];var b:=faces[index+1];var c:=faces[index+2]
				_axis(local_normals,(b-a).cross(c-a));_axis(local_edges,b-a);_axis(local_edges,c-b);_axis(local_edges,a-c)
		geometry={"vertices":local_vertices,"normals":local_normals,"edges":local_edges};part.mesh.set_meta("trial_contact_geometry",geometry)
	var vertices: Array[Vector3]=[];var normals: Array[Vector3]=[];var edges: Array[Vector3]=[]
	for vertex in geometry.vertices:vertices.append(part.pose*vertex)
	var normal_basis: Basis=part.pose.basis.inverse().transposed()
	for axis in geometry.normals:normals.append((normal_basis*axis).normalized())
	for axis in geometry.edges:edges.append((part.pose.basis*axis).normalized())
	var bounds:=AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices:bounds=bounds.expand(vertex)
	var result: Dictionary={"vertices":vertices,"normals":normals,"edges":edges,"bounds":bounds}
	var cells:=Cells.local_cells(part.mesh)
	if not cells.is_empty():
		result["cells"]=[]
		for cell in cells:result.cells.append(Cells.transformed(cell,part.pose))
	return result
static func _separates(a: Array[Vector3],b: Array[Vector3],axis: Vector3,clearance:=EDGE_CLEARANCE,translation:=Vector3.ZERO) -> bool:
	if axis.length_squared()<.00000001:return false
	axis=axis.normalized();var low_a:=INF;var high_a:=-INF;var low_b:=INF;var high_b:=-INF
	for vertex in a:
		var distance:=vertex.dot(axis)+translation.dot(axis);low_a=minf(low_a,distance);high_a=maxf(high_a,distance)
	for vertex in b:
		var distance:=vertex.dot(axis);low_b=minf(low_b,distance);high_b=maxf(high_b,distance)
	return minf(high_a,high_b)-maxf(low_a,low_b)<-clearance
static func intersects(a: Dictionary,b: Dictionary,clearance:=EDGE_CLEARANCE,translation:=Vector3.ZERO) -> bool:
	var overlap: AABB=AABB(a.bounds.position+translation,a.bounds.size).grow(maxf(0,clearance)).intersection(b.bounds.grow(maxf(0,clearance)))
	if minf(overlap.size.x,minf(overlap.size.y,overlap.size.z))<=.000001:return false
	if a.has("cells"):
		for cell in a.cells:
			if intersects(cell,b,clearance,translation):return true
		return false
	if b.has("cells"):
		for cell in b.cells:
			if intersects(a,cell,clearance,translation):return true
		return false
	for axis in a.normals:
		if _separates(a.vertices,b.vertices,axis,clearance,translation):return false
	for axis in b.normals:
		if _separates(a.vertices,b.vertices,axis,clearance,translation):return false
	for first in a.edges:
		for second in b.edges:
			if _separates(a.vertices,b.vertices,first.cross(second),clearance,translation):return false
	return true
static func clear(parts: Array,obstacles: Array,clearance:=EDGE_CLEARANCE) -> bool:
	for part in parts:
		var moving:=box(part)
		for obstacle in obstacles:
			if intersects(moving,obstacle,clearance):return false
	return true
static func patches(parts: Array,height: float) -> Array:
	var result: Array=[]
	for part in parts:
		var vertices:=PackedVector2Array()
		for vertex in part.mesh.get_faces():
			var point: Vector3=part.pose*vertex
			if absf(point.y-height)<.0001:vertices.append(Vector2(point.x,point.z))
		if vertices.is_empty():continue
		var hull:=Geometry2D.convex_hull(vertices)
		if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.remove_at(hull.size()-1)
		result.append(hull)
	return result
static func supports(a: PackedVector2Array,b: PackedVector2Array) -> bool:
	if a.size()>=3 and b.size()>=3 and not Geometry2D.intersect_polygons(a,b).is_empty():return true
	for point in a:
		if b.size()>=3 and Geometry2D.is_point_in_polygon(point,b):return true
	for point in b:
		if a.size()>=3 and Geometry2D.is_point_in_polygon(point,a):return true
	for i in (1 if a.size()==2 else a.size()):
		for j in (1 if b.size()==2 else b.size()):
			if Geometry2D.segment_intersects_segment(a[i],a[(i+1)%a.size()],b[j],b[(j+1)%b.size()])!=null:return true
	return false
static func supported(bottom: Array,top: Array) -> bool:
	for a in bottom:
		for b in top:
			if supports(a,b):return true
	return false
static func flat(root: Node3D,basis: Basis,receivers: Array,obstacles: Array,target_x: float) -> Dictionary:
	var support_bounds:=bounds(receivers);var top:=patches(receivers,support_bounds.end.y)
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for patch in top:
		for vertex in patch:low=low.min(vertex);high=high.max(vertex)
	var center: Vector2=(low+high)*.5
	# A continuous starter may support any board location; smaller receivers use their own centre.
	if high.x-low.x>5.0:center.x=clampf(target_x,low.x+.15,high.x-.15)
	var local:=bounds(meshes(root,Transform3D(basis,Vector3.ZERO)))
	var offsets: Array[Vector2]=[]
	for x in range(-6,7):
		for z in range(-6,7):offsets.append(Vector2(x*.12,z*.12))
	offsets.sort_custom(func(a,b):return a.length_squared()<b.length_squared() if not is_equal_approx(a.length_squared(),b.length_squared()) else a.y>b.y)
	var fallback:=Transform3D(basis,Vector3(center.x-local.get_center().x,support_bounds.end.y+GAP-local.position.y,center.y-local.get_center().z))
	for offset in offsets:
		var pose:=fallback;pose.origin+=Vector3(offset.x,0,offset.y)
		var candidate:=meshes(root,pose)
		if not supported(patches(candidate,support_bounds.end.y+GAP),top):continue
		if clear(candidate,obstacles):return {"pose":pose,"clear":true,"distance":0.0}
	return {"pose":fallback,"clear":false,"distance":0.0}
static func clear_translated(solids: Array,obstacles: Array,translation: Vector3,clearance: float) -> bool:
	for solid in solids:
		for obstacle in obstacles:
			if intersects(solid,obstacle,clearance,translation):return false
	return true
static func solid_boxes(root: Node3D,pose: Transform3D) -> Array:
	var result: Array=[]
	for part in meshes(root,pose):result.append(box(part))
	return result
static func blocked(root: Node3D,nominal: Transform3D,direction: Vector3,obstacles: Array,outside_distance:=1.2) -> Dictionary:
	# Approach from outside. An empty pocket behind a solid shoulder is not a
	# reachable resting place, even if a static test there would be clear.
	var solids:=solid_boxes(root,nominal)
	var outside: float=outside_distance
	while outside<=4.0:
		var start:=nominal;start.origin+=direction*outside
		if clear_translated(solids,obstacles,direction*outside,-.00002):break
		outside+=.1
	if outside>4.0:return {"pose":nominal,"clear":false,"distance":0.0}
	var previous:=outside
	for step in range(1,ceili(outside/.01)+1):
		var distance: float=maxf(0.0,outside-step*.01)
		var pose:=nominal;pose.origin+=direction*distance
		if not clear_translated(solids,obstacles,direction*distance,-.00002):
			var low: float=distance
			var high: float=previous
			for iteration in 14:
				var middle: float=(low+high)*.5
				var candidate:=nominal;candidate.origin+=direction*middle
				if clear_translated(solids,obstacles,direction*middle,-.00002):high=middle
				else:low=middle
			distance=high+REST_GAP
			pose=nominal;pose.origin+=direction*distance
			return {"pose":pose,"clear":true,"distance":distance}
		previous=distance
	return {"pose":nominal,"clear":true,"distance":0.0}

static func approach_clear(root: Node3D,contact: Transform3D,offset: Vector3,obstacles: Array) -> bool:
	var solids:=solid_boxes(root,contact)
	for step in range(ceili(offset.length()/.01)+1):
		var fraction:=float(step)/maxi(1,ceili(offset.length()/.01))
		var pose:=contact;pose.origin+=offset*(1.0-fraction)
		# Mating faces may touch; reject penetration beyond mesh roundoff.
		if not clear_translated(solids,obstacles,offset*(1.0-fraction),-.00002):return false
	return true
