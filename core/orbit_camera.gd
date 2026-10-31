class_name JoineryOrbitCamera
extends Node
## Perspective orbit rig. The pivot is the assembled model's bounding-box center,
## never the center of the loose parts or a sideways offset for the demo's UI.
var assembly: JoineryAssembly
var camera: Camera3D
## World-space pivot, refreshed from the assembly transform by update_camera().
var target := Vector3.ZERO
var yaw: float = 0.68
var pitch: float = 0.42
var distance: float = 10.0
## Normalized horizontal position of the pivot in the viewport. A left sidebar
## can use e.g. 0.63 without changing target or the geometric orbit center.
var screen_center_x: float = 0.5
var screen_center_y: float = 0.5
## Normalized usable viewport, excluding currently visible UI.
var framing_rect := Rect2(0, 0, 1, 1)
var center_framing_contents := false
var _framing_offset := Vector2.ZERO
## Automatic views target ~50% usable width and <=45% usable height.
var frame_margin: float = 2.0
var vertical_frame_margin: float = 2.25
var minimum_distance: float = 0.25

var _assembled_center := Vector3.ZERO
var _viewport: Viewport

func configure(value: JoineryAssembly, view: Camera3D) -> void:
	if is_instance_valid(_viewport) and _viewport.size_changed.is_connected(update_camera):
		_viewport.size_changed.disconnect(update_camera)
	assembly = value
	camera = view
	_viewport = camera.get_viewport() if is_instance_valid(camera) else null
	if is_instance_valid(_viewport):
		_viewport.size_changed.connect(update_camera)
	fit_model()

func fit_model(distance_floor: float = 0.0, reference_poses: Dictionary = {}) -> void:
	if not is_instance_valid(assembly) or not is_instance_valid(camera): return
	var assembled_bounds := AABB()
	var has_bounds := false
	var framing_points: Array[Vector3] = []
	for id in assembly.parts:
		var part: Node3D = assembly.parts[id]
		var local_corners: Array[Vector3] = []
		_append_mesh_corners(part, Transform3D.IDENTITY, local_corners)
		var assembled: Transform3D = assembly.assembled_pose(id)
		for corner in local_corners:
			var assembled_corner := assembled * corner
			if has_bounds:
				assembled_bounds = assembled_bounds.expand(assembled_corner)
			else:
				assembled_bounds = AABB(assembled_corner, Vector3.ZERO)
				has_bounds = true
			# Both configurations must fit, but only the assembled geometry sets
			# the pivot. A loose piece can move without dragging the orbit center.
			framing_points.append(assembly.to_global(assembled_corner))
			# Reset may measure immutable entry poses with today's viewport; the
			# live part transform/state is never temporarily moved or replaced.
			var framing_pose: Transform3D = reference_poses.get(id,part.transform)
			framing_points.append(assembly.to_global(framing_pose * corner))
	_assembled_center = assembled_bounds.get_center() if has_bounds else Vector3.ZERO
	target = assembly.to_global(_assembled_center)
	if not framing_points.is_empty():
		var view_basis := _orbit_basis()
		_framing_offset = Vector2.ZERO
		if center_framing_contents:
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			for point in framing_points:
				var relative := point - target
				var planar := Vector2(relative.dot(view_basis.x), relative.dot(view_basis.y))
				low = low.min(planar)
				high = high.max(planar)
			# Composition may follow the scattered bounds; the orbit pivot never does.
			_framing_offset = (low + high) * .5
		var tangents := _half_fov_tangents()
		var center_ndc := 2.0 * clampf(screen_center_x, 0.05, 0.95) - 1.0
		var center_y_ndc := 2.0 * clampf(screen_center_y, 0.05, 0.95) - 1.0
		var margin := maxf(frame_margin, 1.0)
		# Fit into the available area centered on the composed pivot, leaving
		# room for a sidebar rather than hiding the leftmost part behind it.
		var horizontal_span := maxf(0.02, 2.0 * minf(screen_center_x - framing_rect.position.x, framing_rect.end.x - screen_center_x)) / margin
		var vertical_span := maxf(0.02, 2.0 * minf(screen_center_y - framing_rect.position.y, framing_rect.end.y - screen_center_y)) / maxf(vertical_frame_margin, 1.0)
		var fitted_distance := maxf(distance_floor, maxf(minimum_distance, camera.near * 2.0))
		var furthest_back := 0.0
		for refinement in range(8 if center_framing_contents else 1):
			fitted_distance = maxf(distance_floor, maxf(minimum_distance, camera.near * 2.0))
			for point in framing_points:
				var offset := point - target
				var x := offset.dot(view_basis.x) - _framing_offset.x
				var y := offset.dot(view_basis.y) - _framing_offset.y
				var z := offset.dot(view_basis.z)
				var horizontal_distance := z + absf(x + center_ndc * z * tangents.x) / (horizontal_span * tangents.x)
				var vertical_distance := z + absf(y - center_y_ndc * z * tangents.y) / (vertical_span * tangents.y)
				fitted_distance = maxf(fitted_distance, maxf(horizontal_distance, vertical_distance))
				fitted_distance = maxf(fitted_distance, z + camera.near * 2.0)
				furthest_back = maxf(furthest_back, -z)
			if center_framing_contents and refinement < 7:
				# Correct the perspective bounds, not just their world-space midpoint.
				var low := Vector2(INF, INF)
				var high := Vector2(-INF, -INF)
				for point in framing_points:
					var offset := point - target
					var z := offset.dot(view_basis.z)
					var planar := Vector2((offset.dot(view_basis.x) - _framing_offset.x + center_ndc * z * tangents.x) / tangents.x, (offset.dot(view_basis.y) - _framing_offset.y - center_y_ndc * z * tangents.y) / tangents.y) / (fitted_distance - z)
					low = low.min(planar)
					high = high.max(planar)
				_framing_offset += (low + high) * .375 * fitted_distance * tangents
		distance = fitted_distance
		camera.far = maxf(camera.far, distance + furthest_back + 1.0)
	update_camera()

func update_camera() -> void:
	if not is_instance_valid(camera): return
	if is_instance_valid(assembly):
		# Follow translated/rotated/scaled assembly instances, not moving parts.
		target = assembly.to_global(_assembled_center)
	distance = maxf(distance, maxf(minimum_distance, camera.near * 2.0))
	var view_basis := _orbit_basis()
	camera.global_transform = Transform3D(view_basis, target + view_basis.z * distance)
	var center_ndc := 2.0 * clampf(screen_center_x, 0.05, 0.95) - 1.0
	camera.h_offset = _framing_offset.x - center_ndc * distance * _half_fov_tangents().x
	camera.v_offset = _framing_offset.y + (2.0 * clampf(screen_center_y, 0.05, 0.95) - 1.0) * distance * _half_fov_tangents().y

func _orbit_basis() -> Basis:
	# Avoid the look-at singularity at the poles while retaining underside views.
	pitch = clampf(pitch, -PI * 0.5 + 0.01, PI * 0.5 - 0.01)
	var backward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := Vector3.UP.cross(backward).normalized()
	return Basis(right, backward.cross(right).normalized(), backward)

func _half_fov_tangents() -> Vector2:
	var viewport_size := Vector2(1.0, 1.0)
	if is_instance_valid(_viewport): viewport_size = _viewport.get_visible_rect().size
	var aspect := maxf(viewport_size.x, 1.0) / maxf(viewport_size.y, 1.0)
	var tangent := tan(deg_to_rad(clampf(camera.fov, 1.0, 179.0)) * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		return Vector2(tangent, tangent / aspect)
	return Vector2(tangent * aspect, tangent)

func _append_mesh_corners(node: Node, relative: Transform3D, points: Array[Vector3]) -> void:
	# Traverse only real part descendants, so ghost and workshop decoration never
	# influence framing. Preserve mesh-local transforms, including nested meshes.
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.mesh.get_aabb()
		for index in range(8): points.append(relative * bounds.get_endpoint(index))
	for child in node.get_children():
		var child_relative := relative
		if child is Node3D: child_relative = relative * child.transform
		_append_mesh_corners(child, child_relative, points)
