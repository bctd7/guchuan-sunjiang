extends RefCounted
## Continuous grain in the parent stock's frame, across separate notch solids.
static func uv(point: Vector3,normal: Vector3,axis: Vector3) -> Vector2:
	axis=axis.normalized()
	if absf(normal.dot(axis))>.85:
		var across:=axis.cross(Vector3.UP).normalized()
		if across.length_squared()<.5:across=Vector3.RIGHT
		return Vector2(point.dot(across),point.dot(axis.cross(across)))*5.0
	return Vector2(point.dot(axis)*.35,point.dot(normal.cross(axis).normalized())*5.0)

static func bake(source: Mesh,pose: Transform3D,axis: Vector3) -> ArrayMesh:
	var faces:=source.get_faces()
	var smooth: bool=source.get_meta("loft_normals",false)
	var source_normals=source.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] if smooth else null
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_smooth_group(-1)
	for index in range(0,faces.size(),3):
		# Godot's front face is clockwise.
		var normal: Vector3=(faces[index+2]-faces[index]).cross(faces[index+1]-faces[index]).normalized()
		var stock_normal: Vector3=(pose.basis.inverse().transposed()*normal).normalized()
		for corner in 3:
			var point: Vector3=faces[index+corner]
			tool.set_uv(uv(pose*point,stock_normal,axis))
			if smooth:tool.set_normal(source_normals[index+corner])
			tool.add_vertex(point)
	if not smooth:tool.generate_normals()
	var mesh:=tool.commit()
	mesh.set_meta("wood_box",source is BoxMesh or source.get_meta("wood_box",false))
	mesh.set_meta("wood_uv_pose",pose);mesh.set_meta("wood_uv_axis",axis)
	for key in ["joinery_contact_cells","loft_normals"]:
		if source.has_meta(key):mesh.set_meta(key,source.get_meta(key))
	return mesh
