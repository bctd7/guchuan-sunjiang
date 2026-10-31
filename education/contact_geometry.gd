extends RefCounted
## Select and clip existing triangles, never invent filled quads over a hole.
static func vector(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func extract(mesh: Mesh, spec: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	var normal := vector(spec.normal).normalized()
	var point := vector(spec.point)
	var low := vector(spec.bounds_min)
	var high := vector(spec.bounds_max)
	var vertices := mesh.get_faces()
	for i in range(0,vertices.size(),3):
		var polygon: Array[Vector3] = [vertices[i],vertices[i+1],vertices[i+2]]
		var on_plane := true
		for v in polygon:
			if absf(normal.dot(v-point)) > 0.0005: on_plane = false
		if not on_plane: continue
		for axis in range(3):
			polygon = clip(polygon,axis,low[axis],true)
			polygon = clip(polygon,axis,high[axis],false)
		if polygon.size() < 3: continue
		for j in range(1,polygon.size()-1):
			if (polygon[j]-polygon[0]).cross(polygon[j+1]-polygon[0]).length_squared() < 0.0000000001: continue
			for v in [polygon[0],polygon[j],polygon[j+1]]: result.append(v + normal * 0.003)
	return result

static func clip(input: Array[Vector3], axis: int, bound: float, lower: bool) -> Array[Vector3]:
	var output: Array[Vector3] = []
	if input.is_empty(): return output
	var a: Vector3 = input[-1]
	var a_in := a[axis] >= bound if lower else a[axis] <= bound
	for b in input:
		var b_in := b[axis] >= bound if lower else b[axis] <= bound
		if a_in != b_in:
			output.append(a.lerp(b, (bound-a[axis])/(b[axis]-a[axis])))
		if b_in: output.append(b)
		a = b
		a_in = b_in
	return output
