extends RefCounted
## Intersect the real receiving solids with the same face shown on a candidate.
## A drawing helper only: no candidate code, replacement model or fit verdict.
const Cells=preload("res://models/ship/hull/contact_cells.gd")
static func contours(parts: Array,normal: Vector3,distance: float,right: Vector3) -> Array:
	var result: Array=[]
	for part in parts:
		var cells: Array=Cells.local_cells(part.mesh)
		if part.mesh is BoxMesh:
			var vertices: Array[Vector3]=[]
			for index in 8:vertices.append(part.mesh.get_aabb().get_endpoint(index))
			cells=[{"vertices":vertices}]
		for cell in cells:
			var points:=PackedVector2Array()
			for original in cell.vertices:
				var a: Vector3=part.pose*original
				var da: float=normal.dot(a)-distance
				if absf(da)<.000001:points.append(Vector2(right.dot(a),a.y))
				for other in cell.vertices:
					var b: Vector3=part.pose*other
					var db: float=normal.dot(b)-distance
					if da*db<0:
						var point: Vector3=a.lerp(b,da/(da-db))
						points.append(Vector2(right.dot(point),point.y))
			if points.size()<3:continue
			var polygon:=Geometry2D.convex_hull(points)
			if polygon.size()>3:
				polygon.remove_at(polygon.size()-1);result.append(polygon)
	return result
