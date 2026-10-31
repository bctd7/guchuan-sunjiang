class_name JoineryGuidedDrag
extends RefCounted
## Pointer-to-polyline mapping, independent of UI and scene lifecycle.
static func apply(assembly: JoineryAssembly, camera: Camera3D, drag_id: String, grab_local: Vector3, movement: Vector2) -> void:
	if movement.length_squared() < 0.000001: return
	var progress: float = assembly.path_progress[drag_id]
	var points: Array = assembly.specs[drag_id].insertion_path
	var walked := 0.0
	var best_score := 0.0
	var best_delta := 0.0
	for index in range(1, points.size()):
		var start := JoineryAssembly.vector(points[index - 1])
		var end := JoineryAssembly.vector(points[index])
		var length := start.distance_to(end)
		if length <= 0.000001: continue
		var end_distance := walked + length
		if progress >= walked - 0.000001 and progress <= end_distance + 0.000001:
			var first := assembly.to_global(start + assembly.entrance_pose(drag_id).basis * grab_local)
			var last := assembly.to_global(end + assembly.entrance_pose(drag_id).basis * grab_local)
			var projected := camera.unproject_position(last) - camera.unproject_position(first)
			# Near end-on views use upward/downward dragging, at a bounded sensitivity.
			if projected.length() < 18.0: projected = Vector2(0, -maxf(80.0, length * 60.0))
			var delta := movement.dot(projected) / projected.length_squared() * length
			var valid := (delta > 0 and progress < end_distance - 0.000001) or (delta < 0 and progress > walked + 0.000001) or (delta < 0 and progress <= 0.000001)
			var score := absf(movement.dot(projected.normalized()))
			if valid and score > best_score:
				best_score = score
				best_delta = clampf(delta, -progress - 0.05 if walked == 0.0 else walked - progress, end_distance - progress)
		walked = end_distance
	if best_score > 0.0:
		assembly.advance_manual(drag_id, best_delta)
