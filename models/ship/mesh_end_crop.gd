extends RefCounted
## Clips actual member meshes for preview only; does not alter source solids.
static func copy_into(node: Node, host: Node3D, bounds: AABB) -> void:
	if node is MeshInstance3D:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces: PackedVector3Array = node.mesh.get_faces()
		var count := 0
		var cap_points := [[],[],[],[],[],[]]
		var source_bounds: AABB = node.global_transform*node.get_aabb()
		for i in range(0,faces.size(),3):
			var poly: Array = [node.global_transform*faces[i],node.global_transform*faces[i+1],node.global_transform*faces[i+2]]
			for axis in 3:
				poly = _clip(poly,axis,bounds.position[axis],true)
				poly = _clip(poly,axis,bounds.end[axis],false)
			if poly.size() < 3: continue
			for axis in 3:
				for side in 2:
					var boundary: float = bounds.position[axis] if side == 0 else bounds.end[axis]
					if source_bounds.position[axis] >= boundary-.00001 or source_bounds.end[axis] <= boundary+.00001: continue
					for vertex in poly:
						if absf(vertex[axis]-boundary) < .00001: cap_points[axis*2+side].append(vertex)
			for j in range(1,poly.size()-1):
				for vertex in [poly[0],poly[j],poly[j+1]]: surface.add_vertex(vertex)
				count += 3
		# These crop planes cross only unperforated stock, outside the joint.
		# Close their convex section so a local cut never appears as hollow skins.
		for index in 6:
			if cap_points[index].size() < 3: continue
			var axis := index/2
			var a := (axis+1)%3
			var b := (axis+2)%3
			var flat := PackedVector2Array()
			for point in cap_points[index]: flat.append(Vector2(point[a],point[b]))
			var hull := Geometry2D.convex_hull(flat)
			if hull.size() < 4: continue
			hull.remove_at(hull.size()-1)
			var indices := Geometry2D.triangulate_polygon(hull)
			for vertex_index in indices:
				var vertex := Vector3.ZERO
				vertex[axis] = bounds.position[axis] if index%2 == 0 else bounds.end[axis]
				vertex[a] = hull[vertex_index].x
				vertex[b] = hull[vertex_index].y
				surface.add_vertex(vertex)
		if count > 0:
			surface.generate_normals()
			var copy := MeshInstance3D.new()
			copy.name = node.name
			copy.mesh = surface.commit()
			copy.material_override = node.material_override
			host.add_child(copy)
	for child in node.get_children(): copy_into(child,host,bounds)
static func _clip(poly: Array, axis: int, boundary: float, greater: bool) -> Array:
	var output: Array = []
	if poly.is_empty(): return output
	for i in poly.size():
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[(i+1)%poly.size()]
		var a_in: bool = a[axis] >= boundary if greater else a[axis] <= boundary
		var b_in: bool = b[axis] >= boundary if greater else b[axis] <= boundary
		if a_in: output.append(a)
		if a_in != b_in:
			output.append(a.lerp(b,(boundary-a[axis])/(b[axis]-a[axis])))
	return output
