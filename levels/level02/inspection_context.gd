extends RefCounted
const WoodSurface=preload("res://levels/level02/wood_surface.gd")
## Read-only cut section of actual installed mesh, for the local ship workspace.
## Duplicates are hidden in overview and never used as collision/state substitutes.
static func clip(polygon: PackedVector3Array,axis: int,limit: float,keep_above: bool) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for index in polygon.size():
		var a:=polygon[index];var b:=polygon[(index+1)%polygon.size()]
		var inside_a: bool=a[axis]>=limit if keep_above else a[axis]<=limit
		var inside_b: bool=b[axis]>=limit if keep_above else b[axis]<=limit
		if inside_a:result.append(a)
		if inside_a!=inside_b:result.append(a.lerp(b,(limit-a[axis])/(b[axis]-a[axis])))
	return result
static func append(host: Node3D,source: Node3D,pose: Transform3D,left: float,right: float,top:=INF,seal_convex:=false) -> void:
	if source is MeshInstance3D and source.mesh!=null:
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_smooth_group(-1)
		var inverse:=pose.affine_inverse()
		var count:=0;var faces: PackedVector3Array=source.mesh.get_faces()
		var planes: Array=[[0,left,true],[0,right,false]]
		if is_finite(top):planes.append([1,top,false])
		var caps: Array=[]
		for plane in planes:caps.append(PackedVector3Array())
		for index in range(0,faces.size(),3):
			var polygon:=PackedVector3Array([pose*faces[index],pose*faces[index+1],pose*faces[index+2]])
			for plane in planes:polygon=clip(polygon,plane[0],plane[1],plane[2])
			if source.mesh is BoxMesh or source.mesh.get_meta("wood_box",false) or seal_convex:
				for plane in planes.size():
					for point in polygon:
						if absf(point[planes[plane][0]]-planes[plane][1])<.00001 and not Array(caps[plane]).any(func(other):return other.distance_to(point)<.00001):caps[plane].append(point)
			for vertex in range(1,polygon.size()-1):
				var triangle:=PackedVector3Array([inverse*polygon[0],inverse*polygon[vertex],inverse*polygon[vertex+1]])
				append_triangle(tool,triangle,source.mesh);count+=3
		# Seal box cuts and explicitly convex support ribs. Irregular joint stock
		# is never filled across its real slot or concave mouth.
		for plane in planes.size():
			var cap: Array=Array(caps[plane])
			if cap.size()<3:continue
			var center:=Vector3.ZERO
			for point in cap:center+=point
			center/=cap.size()
			var x_axis: int=1 if planes[plane][0]==0 else 2
			var y_axis: int=2 if planes[plane][0]==0 else 0
			cap.sort_custom(func(a,b):return atan2(a[y_axis]-center[y_axis],a[x_axis]-center[x_axis])<atan2(b[y_axis]-center[y_axis],b[x_axis]-center[x_axis]))
			for edge in cap.size():
				var triangle: Array=[center,cap[edge],cap[(edge+1)%cap.size()]]
				if (not planes[plane][2])!=(pose.basis.determinant()<0):triangle.reverse()
				append_triangle(tool,PackedVector3Array([inverse*triangle[0],inverse*triangle[1],inverse*triangle[2]]),source.mesh);count+=3
		if count>0:
			tool.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit();mesh.transform=pose
			mesh.material_override=source.material_override.duplicate() if source.material_override!=null else null
			host.add_child(mesh)
	for child in source.get_children():
		if child is Node3D:append(host,child,pose*child.transform,left,right,top,seal_convex)

static func append_triangle(tool: SurfaceTool,triangle: PackedVector3Array,source: Mesh) -> void:
	var normal: Vector3=(triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
	var pose: Transform3D=source.get_meta("wood_uv_pose",Transform3D.IDENTITY)
	var axis: Vector3=source.get_meta("wood_uv_axis",Vector3.ZERO)
	for point in triangle:
		if axis.length_squared()>.5:tool.set_uv(WoodSurface.uv(pose*point,(pose.basis.inverse().transposed()*normal).normalized(),axis))
		tool.add_vertex(point)
