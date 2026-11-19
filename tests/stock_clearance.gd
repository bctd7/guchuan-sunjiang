extends Node
## Independent observer: broad OBB followed by core triangle/containment guard.
## It does not use the production convex SAT solver.
const Guard=preload("res://components/teaching/assembly/mesh_collision_guard.gd")
var guard=Guard.new()
var registered: Dictionary={}
var pair_cache: Dictionary={}
func triangles_intersect(a: Dictionary,b: Dictionary) -> bool:
	# Mirrored far hull uses a determinant -1 basis. Bake that reflection into
	# a separate mesh; the core guard deliberately rejects non-rigid transforms.
	a=a.duplicate();b=b.duplicate()
	for part in [a,b]:
		if part.pose.basis.determinant()<0:
			var mirror_key: String=str(part.mesh.get_instance_id())+"_mirror"
			if not registered.has(mirror_key):
				var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				for vertex in part.mesh.get_faces():tool.add_vertex(vertex*Vector3(1,1,-1))
				registered[mirror_key]=tool.commit()
			part.mesh=registered[mirror_key];part.pose.basis*=Basis.from_scale(Vector3(1,1,-1))
	for part in [a,b]:
		var key: String=str(part.mesh.get_instance_id())
		if not registered.has(key):guard.register_mesh(key,part.mesh);registered[key]=part.mesh
	var signature: Array=[a.mesh,a.pose,b.mesh,b.pose]
	if pair_cache.has(signature):return pair_cache[signature]
	var result: bool=not guard.motion_is_safe(str(a.mesh.get_instance_id()),a.pose,a.pose,{str(b.mesh.get_instance_id()):b.pose})
	# A mesh resource may appear at two locations. Guard identifies registrations,
	# so give the second occurrence its own stable registration when necessary.
	if a.mesh==b.mesh:
		var key: String=str(b.mesh.get_instance_id())+"_other"
		if not registered.has(key):guard.register_mesh(key,b.mesh);registered[key]=b.mesh
		result=not guard.motion_is_safe(str(a.mesh.get_instance_id()),a.pose,a.pose,{key:b.pose})
	# A conservative rotational guard can flag edge-only contacts even when both
	# poses are static. For horizontal extrusions, independent cap polygon areas
	# distinguish that boundary from real wood overlap without using runtime SAT.
	if result:
		var caps_a:=horizontal_caps(a);var caps_b:=horizontal_caps(b)
		if not caps_a.is_empty() and not caps_b.is_empty():
			result=false
			if minf(caps_a.high,caps_b.high)-maxf(caps_a.low,caps_b.low)>.00002:
				for first in caps_a.triangles:
					for second in caps_b.triangles:
						for polygon in Geometry2D.intersect_polygons(first,second):
							var area:=0.0
							for i in range(1,polygon.size()-1):area+=absf((polygon[i]-polygon[0]).cross(polygon[i+1]-polygon[0]))*.5
							if area>.00000001:result=true
	if pair_cache.size()>4096:pair_cache.clear()
	pair_cache[signature]=result
	return result
static func horizontal_caps(part: Dictionary) -> Dictionary:
	var points: Array[Vector3]=[];var low:=INF;var high:=-INF
	for local in part.mesh.get_faces():
		var point: Vector3=part.pose*local;points.append(point)
		low=minf(low,point.y);high=maxf(high,point.y)
	for point in points:
		if absf(point.y-low)>.000001 and absf(point.y-high)>.000001:return {}
	var triangles: Array=[]
	for i in range(0,points.size(),3):
		if absf(points[i].y-low)>.000001 or absf(points[i+1].y-low)>.000001 or absf(points[i+2].y-low)>.000001:continue
		triangles.append(PackedVector2Array([Vector2(points[i].x,points[i].z),Vector2(points[i+1].x,points[i+1].z),Vector2(points[i+2].x,points[i+2].z)]))
	return {"low":low,"high":high,"triangles":triangles} if not triangles.is_empty() else {}
var level_provider: Callable
var samples:=0
var violations: Dictionary={}
static func shape(node: Node3D) -> Dictionary:
	var points: Array[Vector3]=[]
	var inverse:=node.global_transform.affine_inverse()
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for index in 8:points.append(inverse*mesh.global_transform*mesh.get_aabb().get_endpoint(index))
	if node is MeshInstance3D:
		for index in 8:points.append(node.get_aabb().get_endpoint(index))
	if points.is_empty():return {}
	var box:=AABB(points[0],Vector3.ZERO)
	for point in points:box=box.expand(point)
	var basis:=node.global_basis
	if minf(basis.x.length_squared(),minf(basis.y.length_squared(),basis.z.length_squared()))<.000001:return {}
	return {"center":node.global_transform*box.get_center(),"axes":[basis.x.normalized(),basis.y.normalized(),basis.z.normalized()],"half":box.size*.5*Vector3(basis.x.length(),basis.y.length(),basis.z.length())}
static func intersects(a: Dictionary,b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():return false
	var axes: Array=[];axes.append_array(a.axes);axes.append_array(b.axes)
	for x in a.axes:
		for y in b.axes:axes.append(x.cross(y))
	for raw in axes:
		var axis: Vector3=raw
		if axis.length_squared()<.000001:continue
		axis=axis.normalized()
		var first:=0.0;var second:=0.0
		for i in 3:first+=a.half[i]*absf(a.axes[i].dot(axis));second+=b.half[i]*absf(b.axes[i].dot(axis))
		if first+second-absf((b.center-a.center).dot(axis))<=.0005:return false
	return true
static func mesh_shapes(node: Node3D) -> Array:
	var result: Array=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):result.append({"shape":shape(mesh),"mesh":mesh.mesh,"pose":mesh.global_transform})
	if node is MeshInstance3D:result.append({"shape":shape(node),"mesh":node.mesh,"pose":node.global_transform})
	return result
func _process(_delta: float) -> void:
	if not level_provider.is_valid():return
	sample(level_provider.call())
func sample(level) -> void:
	if not is_instance_valid(level) or not is_instance_valid(level.get("view")):return
	var view=level.view
	if not view.is_inside_tree():return
	if not view.get("resting") is Dictionary:return
	if not view.contact_failures.is_empty():violations["no supported clear pose: "+str(view.contact_failures)]=true
	var nodes: Dictionary={};var obstacles: Dictionary={};var narrow: Dictionary={}
	for id in view.pieces:
		if view.pieces[id].is_visible_in_tree() and (level.state.placed.has(id) or view.preview_id==id):nodes[id]=view.pieces[id]
	for key in view.fixed:nodes["fixed:"+key]=view.fixed[key]
	for key in nodes:obstacles[key]=shape(nodes[key])
	for id in view.pieces:
		if not view.resting.get(id,false) or not obstacles.has(id):continue
		samples+=1
		for other in obstacles:
			if other==id or not intersects(obstacles[id],obstacles[other]):continue
			if not narrow.has(id):narrow[id]=mesh_shapes(nodes[id])
			if not narrow.has(other):narrow[other]=mesh_shapes(nodes[other])
			for a in narrow[id]:
				for b in narrow[other]:
					if intersects(a.shape,b.shape) and triangles_intersect(a,b):
						var key: String=id+" / "+other
						if not violations.has(key):print("CLEARANCE_CONTEXT ",JSON.stringify({"pair":key,"selected":level.state.selected,"joint":level.state.joint,"opening":level.state.opening,"placed":level.state.placed.get(id,{}),"inspected":view.inspected,"depth":view.preview_progress,"phase":view.trial.phase,"actual":str(nodes[id].transform),"rest":str(view.poses[id]),"reason":guard.last_reason}))
						violations[key]=true
