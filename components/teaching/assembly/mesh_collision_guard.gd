class_name MeshCollisionGuard
extends RefCounted
## Triangle-level, assembly-local, fail-closed rigid motion guard.
## Meshes must be closed, manifold solids with features larger than CLEARANCE.
## Translation is continuous SAT, not endpoint testing. Rotation follows shortest
## quaternion slerp plus linear origin interpolation; the caller must use that path.
## Rotational segments enclose every triangle in its endpoint hull, expanded by
## r * (1 - cos(segment_angle / 2)). No whole-part convexification is performed.
## Non-rigid transforms and exhausted work budgets are deliberately rejected.
const CLEARANCE := 0.00001
const AXIS_EPS := 1.0e-12
const ROTATION_STEP := 0.04
const MAX_SEGMENTS := 96
const MAX_PAIR_TESTS := 100000
const MAX_BROADPHASE_TESTS := 1000000
const MAX_TRIANGLES := 2048
const RAY_DIRECTION := Vector3(0.819231, 0.371391, 0.436217)
var _ray_u := RAY_DIRECTION.cross(Vector3.UP).normalized()
var _ray_v := RAY_DIRECTION.cross(_ray_u).normalized()
var _meshes: Dictionary = {}
var _verified_poses: Dictionary = {}
var _pair_tests := 0
var _broadphase_tests := 0
var last_reason := ""

func register_mesh(id: String, mesh: Mesh) -> void:
	_verified_poses.clear()
	if mesh == null:
		_meshes.erase(id)
		return
	var faces := mesh.get_faces()
	if faces.size() % 3 != 0 or faces.size() / 3 > MAX_TRIANGLES:
		_meshes.erase(id)
		return
	var triangles: Array = []
	var samples: Array[Vector3] = []
	var radius := 0.0
	for i in range(0, faces.size(), 3):
		var tri := PackedVector3Array([faces[i], faces[i + 1], faces[i + 2]])
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() <= AXIS_EPS:
			continue
		triangles.append(tri)
		for vertex in tri:
			radius = maxf(radius, vertex.length())
	var query := _prepare_query(triangles)
	# Interior witnesses also detect coincident solids whose surfaces only touch.
	# Test both sides, so this does not depend on imported winding orientation.
	for tri: PackedVector3Array in triangles:
		var center := (tri[0] + tri[1] + tri[2]) / 3.0
		var normal := (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for sign_value in [-1.0, 1.0]:
			var sample: Vector3 = center + normal * CLEARANCE * 4.0 * sign_value
			if _inside(sample, triangles, query):
				samples.append(sample)
	_meshes[id] = {"triangles": triangles, "samples": samples, "radius": radius, "query": query, "bounds": _bounds_all(triangles) if not triangles.is_empty() else AABB(), "tree": _build_tree(range(triangles.size()), triangles) if not triangles.is_empty() else {}}

func clear() -> void:
	_meshes.clear()
	_verified_poses.clear()

func motion_is_safe(id: String, from: Transform3D, to: Transform3D, obstacles: Dictionary) -> bool:
	last_reason = ""
	_pair_tests = 0
	_broadphase_tests = 0
	if not _meshes.has(id) or not _rigid(from) or not _rigid(to):
		return _reject("Missing mesh or non-rigid transform")
	var known_start: bool = _verified_poses.has(id) and _verified_poses[id].pose == from and _verified_poses[id].obstacles == obstacles
	if known_start and from == to:
		return true
	var qa := from.basis.get_rotation_quaternion()
	var qb := to.basis.get_rotation_quaternion()
	var angle := qa.angle_to(qb)
	var count := maxi(1, int(ceil(angle / ROTATION_STEP)))
	if count > MAX_SEGMENTS:
		return _reject("Rotation exceeds conservative sweep budget")
	var moving: Dictionary = _meshes[id]
	if moving.triangles.is_empty():
		return _reject("Mesh contains no triangles")
	for other_id in obstacles:
		if other_id == id:
			continue
		if not _meshes.has(other_id) or not obstacles[other_id] is Transform3D:
			return _reject("Unknown obstacle")
		if _meshes[other_id].triangles.is_empty():
			return _reject("Obstacle contains no triangles")
		var obstacle_pose: Transform3D = obstacles[other_id]
		if not _rigid(obstacle_pose):
			return _reject("Non-rigid obstacle")
		var obstacle_inverse := obstacle_pose.affine_inverse()
		var fixed: Array = _meshes[other_id].triangles
		var fixed_bounds: AABB = _meshes[other_id].bounds
		var sweep_bounds := _bounds_all(_transform_triangles(moving.triangles, obstacle_inverse * from))
		sweep_bounds = sweep_bounds.merge(_bounds_all(_transform_triangles(moving.triangles, obstacle_inverse * to)))
		# A zero-volume intersection of whole swept AABBs is only contact.
		# Keep this distinct from triangle AABBs, which may be zero-thickness.
		if angle < 0.000001 and not _volume_overlap(sweep_bounds, fixed_bounds):
			continue
		sweep_bounds = sweep_bounds.grow(float(moving.radius) * (1.0 - cos(angle * 0.5)) + CLEARANCE)
		if not _overlap(sweep_bounds, fixed_bounds):
			continue
		if not known_start and _contained(moving, from, _meshes[other_id], obstacle_pose):
			return _reject("Initial solid containment")
		for segment in count:
			var t0 := float(segment) / count
			var t1 := float(segment + 1) / count
			var a := obstacle_inverse * Transform3D(Basis(qa.slerp(qb, t0)), from.origin.lerp(to.origin, t0))
			var b := obstacle_inverse * Transform3D(Basis(qa.slerp(qb, t1)), from.origin.lerp(to.origin, t1))
			var padding := float(moving.radius) * (1.0 - cos(angle / count * 0.5))
			var translating := angle < 0.000001
			for local_tri: PackedVector3Array in moving.triangles:
				var start := _transform_triangle(local_tri, a)
				var finish := _transform_triangle(local_tri, b)
				var hull := start.duplicate()
				hull.append_array(finish)
				var box := _bounds(hull).grow(padding + CLEARANCE)
				var candidates := _query_tree(_meshes[other_id].tree, box)
				if _broadphase_tests > MAX_BROADPHASE_TESTS:
					return _reject("Broadphase sweep budget exceeded")
				for j: int in candidates:
					if not _overlap(box, _bounds(fixed[j])):
						continue
					_pair_tests += 1
					if _pair_tests > MAX_PAIR_TESTS:
						return _reject("Triangle sweep budget exceeded")
					if translating:
						if _translation_hit(start, fixed[j], b.origin - a.origin):
							return _reject("Swept triangle intersection")
					elif _hull_hit(hull, fixed[j], padding):
						return _reject("Conservative rotational sweep intersection")
		if _contained(moving, to, _meshes[other_id], obstacle_pose):
			return _reject("Final solid containment")
	# Only a completely accepted destination is cached. Every obstacle ID and
	# exact pose must match, and register_mesh/clear invalidate all certificates.
	_verified_poses[id] = {"pose": to, "obstacles": obstacles.duplicate()}
	return true

func _build_tree(indices: Array, triangles: Array) -> Dictionary:
	var box := _bounds(triangles[indices[0]])
	for index: int in indices:
		box = box.merge(_bounds(triangles[index]))
	if indices.size() <= 8:
		return {"box": box, "indices": indices}
	var axis := box.size.max_axis_index()
	indices.sort_custom(func(i: int, j: int) -> bool:
		return _bounds(triangles[i]).get_center()[axis] < _bounds(triangles[j]).get_center()[axis])
	var middle := indices.size() / 2
	return {"box": box, "left": _build_tree(indices.slice(0, middle), triangles), "right": _build_tree(indices.slice(middle), triangles)}

func _query_tree(tree: Dictionary, box: AABB) -> Array:
	var result: Array = []
	var pending: Array = [tree]
	while not pending.is_empty():
		_broadphase_tests += 1
		if _broadphase_tests > MAX_BROADPHASE_TESTS:
			return result
		var node: Dictionary = pending.pop_back()
		if not _overlap(node.box, box):
			continue
		if node.has("indices"):
			result.append_array(node.indices)
		else:
			pending.append(node.left)
			pending.append(node.right)
	return result

func _reject(reason: String) -> bool:
	last_reason = reason
	return false

func _rigid(pose: Transform3D) -> bool:
	return pose.is_finite() and absf(pose.basis.determinant() - 1.0) < 0.0001 and pose.basis.is_equal_approx(pose.basis.orthonormalized())

func _transform_triangle(tri: PackedVector3Array, pose: Transform3D) -> PackedVector3Array:
	return PackedVector3Array([pose * tri[0], pose * tri[1], pose * tri[2]])

func _transform_triangles(triangles: Array, pose: Transform3D) -> Array:
	var result: Array = []
	for tri: PackedVector3Array in triangles:
		result.append(_transform_triangle(tri, pose))
	return result

func _bounds(vertices: PackedVector3Array) -> AABB:
	var result := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		result = result.expand(vertex)
	return result

func _bounds_all(triangles: Array) -> AABB:
	var result := _bounds(triangles[0])
	for tri: PackedVector3Array in triangles:
		result = result.merge(_bounds(tri))
	return result

func _overlap(a: AABB, b: AABB) -> bool:
	return a.position.x <= b.end.x and b.position.x <= a.end.x and a.position.y <= b.end.y and b.position.y <= a.end.y and a.position.z <= b.end.z and b.position.z <= a.end.z

func _volume_overlap(a: AABB, b: AABB) -> bool:
	return minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) > CLEARANCE and minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y) > CLEARANCE and minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z) > CLEARANCE

func _projection(vertices: PackedVector3Array, axis: Vector3) -> Vector2:
	var result := Vector2(INF, -INF)
	for vertex in vertices:
		var value := vertex.dot(axis)
		result.x = minf(result.x, value)
		result.y = maxf(result.y, value)
	return result

func _translation_hit(a: PackedVector3Array, b: PackedVector3Array, velocity: Vector3) -> bool:
	var ea := [a[1] - a[0], a[2] - a[1], a[0] - a[2]]
	var eb := [b[1] - b[0], b[2] - b[1], b[0] - b[2]]
	var na: Vector3 = ea[0].cross(ea[1]).normalized()
	var nb: Vector3 = eb[0].cross(eb[1]).normalized()
	if velocity.length_squared() <= AXIS_EPS:
		# Static surface contact at an edge/vertex is not solid penetration.
		# A proper transverse surface crossing straddles both triangle planes.
		# Coincident/contained solids are handled by interior witnesses separately.
		var b_plane := _projection(b, na) - Vector2.ONE * a[0].dot(na)
		var a_plane := _projection(a, nb) - Vector2.ONE * b[0].dot(nb)
		if b_plane.x >= -CLEARANCE or b_plane.y <= CLEARANCE or a_plane.x >= -CLEARANCE or a_plane.y <= CLEARANCE:
			return false
	# Coplanar faces may slide against one another without penetrating material.
	if na.cross(nb).length_squared() < AXIS_EPS and absf(na.dot(b[0] - a[0])) <= CLEARANCE and absf(na.dot(velocity)) <= CLEARANCE:
		return false
	var axes: Array[Vector3] = [na, nb]
	for edge_a: Vector3 in ea:
		axes.append(na.cross(edge_a))
		for edge_b: Vector3 in eb:
			axes.append(edge_a.cross(edge_b))
	for edge_b: Vector3 in eb:
		axes.append(nb.cross(edge_b))
	var enter := 0.0
	var leave := 1.0
	for raw_axis in axes:
		if raw_axis.length_squared() <= AXIS_EPS:
			continue
		var axis := raw_axis.normalized()
		var pa := _projection(a, axis)
		var pb := _projection(b, axis)
		var speed := velocity.dot(axis)
		# Require genuine overlap where both triangles have extent. This permits
		# shared edges and flush contact while retaining zero-width plane crossings.
		var inset := CLEARANCE if minf(pa.y - pa.x, pb.y - pb.x) > CLEARANCE * 4.0 else 0.0
		var lo := pb.x - pa.y + inset
		var hi := pb.y - pa.x - inset
		if absf(speed) <= 1.0e-10:
			if lo > 0.0 or hi < 0.0:
				return false
		else:
			var t_lo := lo / speed
			var t_hi := hi / speed
			enter = maxf(enter, minf(t_lo, t_hi))
			leave = minf(leave, maxf(t_lo, t_hi))
			if enter > leave:
				return false
	# Contact solely at the very beginning or very end is permitted. A crossing
	# anywhere in the open interval is blocked, regardless of its duration.
	if velocity.length_squared() > AXIS_EPS:
		var time_epsilon := minf(0.0000001, CLEARANCE / maxf(velocity.length(), CLEARANCE))
		return leave > time_epsilon and enter < 1.0 - time_epsilon
	return enter <= leave

func _hull_hit(hull: PackedVector3Array, tri: PackedVector3Array, padding: float) -> bool:
	var edges := [tri[1] - tri[0], tri[2] - tri[1], tri[0] - tri[2]]
	var normal: Vector3 = edges[0].cross(edges[1])
	var axes: Array[Vector3] = [normal]
	for i in hull.size():
		for j in range(i + 1, hull.size()):
			var edge := hull[j] - hull[i]
			for other_edge: Vector3 in edges:
				axes.append(edge.cross(other_edge))
			for k in range(j + 1, hull.size()):
				axes.append(edge.cross(hull[k] - hull[i]))
	# These extra axes handle a degenerate planar endpoint hull.
	for edge: Vector3 in edges:
		axes.append(normal.cross(edge))
	for raw_axis in axes:
		if raw_axis.length_squared() <= AXIS_EPS:
			continue
		var axis := raw_axis.normalized()
		var pa := _projection(hull, axis)
		var pb := _projection(tri, axis)
		if pa.y + padding < pb.x - CLEARANCE or pb.y < pa.x - padding - CLEARANCE:
			return false
	return true

func _contained(a: Dictionary, pose_a: Transform3D, b: Dictionary, pose_b: Transform3D) -> bool:
	var a_to_b := pose_b.affine_inverse() * pose_a
	for sample: Vector3 in a.samples:
		if b.bounds.has_point(a_to_b * sample) and _inside(a_to_b * sample, b.triangles, b.query):
			return true
	var b_to_a := a_to_b.affine_inverse()
	for sample: Vector3 in b.samples:
		if a.bounds.has_point(b_to_a * sample) and _inside(b_to_a * sample, a.triangles, a.query):
			return true
	return false

func _prepare_query(triangles: Array) -> Array:
	var query: Array = []
	for tri: PackedVector3Array in triangles:
		var u := _projection(tri, _ray_u)
		var v := _projection(tri, _ray_v)
		query.append(Vector4(u.x - CLEARANCE, u.y + CLEARANCE, v.x - CLEARANCE, v.y + CLEARANCE))
	return query

func _inside(point: Vector3, triangles: Array, query: Array = []) -> bool:
	# Non-axis ray and deduplicated crossings avoid triangulated-face double hits.
	var direction := RAY_DIRECTION.normalized()
	var projected := Vector2(point.dot(_ray_u), point.dot(_ray_v))
	var hits: Array[float] = []
	for i in triangles.size():
		if not query.is_empty():
			var box: Vector4 = query[i]
			if projected.x < box.x or projected.x > box.y or projected.y < box.z or projected.y > box.w:
				continue
		var tri: PackedVector3Array = triangles[i]
		var edge1 := tri[1] - tri[0]
		var edge2 := tri[2] - tri[0]
		var normal := edge1.cross(edge2)
		var offset := point - tri[0]
		var dot00 := edge1.dot(edge1)
		var dot01 := edge1.dot(edge2)
		var dot11 := edge2.dot(edge2)
		var denominator := dot00 * dot11 - dot01 * dot01
		if absf(normal.normalized().dot(offset)) < CLEARANCE and absf(denominator) > AXIS_EPS:
			var u := (dot11 * offset.dot(edge1) - dot01 * offset.dot(edge2)) / denominator
			var v := (dot00 * offset.dot(edge2) - dot01 * offset.dot(edge1)) / denominator
			if u >= -0.000001 and v >= -0.000001 and u + v <= 1.000001:
				return false
		var p := direction.cross(edge2)
		var determinant := edge1.dot(p)
		if absf(determinant) < AXIS_EPS:
			continue
		var inverse := 1.0 / determinant
		var u := offset.dot(p) * inverse
		if u < 0.0 or u > 1.0:
			continue
		var q := offset.cross(edge1)
		var v := direction.dot(q) * inverse
		if v < 0.0 or u + v > 1.0:
			continue
		var distance := edge2.dot(q) * inverse
		if distance > CLEARANCE:
			hits.append(distance)
	hits.sort()
	var crossings := 0
	var previous := -INF
	for distance in hits:
		if distance - previous > CLEARANCE:
			crossings += 1
		previous = distance
	return crossings % 2 == 1
