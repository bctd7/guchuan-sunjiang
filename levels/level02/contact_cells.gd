extends RefCounted
## Ship ArrayMeshes are closed prisms extruded along local Y. Their cap
## triangles partition the actual solid, preserving the empty joint pockets.
static func local_cells(mesh: Mesh) -> Array:
	if mesh is BoxMesh:return []
	if mesh.has_meta("joinery_contact_cells"):return mesh.get_meta("joinery_contact_cells")
	var faces:=mesh.get_faces()
	var bounds:=mesh.get_aabb()
	var low:=bounds.position.y
	var high:=bounds.end.y
	var cells: Array=[]
	if high-low<=.000001:return cells
	for point in faces:
		if absf(point.y-low)>.000001 and absf(point.y-high)>.000001:
			return cells # Other mesh families retain the conservative fallback.
	for i in range(0,faces.size(),3):
		var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
		if absf(a.y-low)>.000001 or absf(b.y-low)>.000001 or absf(c.y-low)>.000001:continue
		if absf((b-a).cross(c-a).y)<.000000001:continue
		var vertices: Array[Vector3]=[a,b,c,Vector3(a.x,high,a.z),Vector3(b.x,high,b.z),Vector3(c.x,high,c.z)]
		var edges: Array[Vector3]=[b-a,c-b,a-c,Vector3.UP]
		var normals: Array[Vector3]=[Vector3.UP,(b-a).cross(Vector3.UP),(c-b).cross(Vector3.UP),(a-c).cross(Vector3.UP)]
		cells.append({"vertices":vertices,"edges":edges,"normals":normals})
	mesh.set_meta("joinery_contact_cells",cells)
	return cells

static func transformed(cell: Dictionary,pose: Transform3D) -> Dictionary:
	var vertices: Array[Vector3]=[];var normals: Array[Vector3]=[];var edges: Array[Vector3]=[]
	for point in cell.vertices:vertices.append(pose*point)
	var normal_basis:=pose.basis.inverse().transposed()
	for normal in cell.normals:normals.append((normal_basis*normal).normalized())
	for edge in cell.edges:edges.append((pose.basis*edge).normalized())
	var bounds:=AABB(vertices[0],Vector3.ZERO)
	for point in vertices:bounds=bounds.expand(point)
	return {"vertices":vertices,"normals":normals,"edges":edges,"bounds":bounds}
