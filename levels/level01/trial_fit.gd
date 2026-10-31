extends RefCounted
## Visual insertion poses. Trial attachment is deliberately separate from fit.
## Incorrect stock is retained, then visibly loosens instead of stopping outside.
const Lengths = preload("res://levels/level01/length_geometry.gd")

static func expected_joint(id: String) -> String:
	if id == "keel": return "base"
	return Lengths.kind(id)

static func resolved_joint(id: String, joint: String = "") -> String:
	return expected_joint(id) if joint.is_empty() else joint

static func is_stable(id: String, length: String = "correct", joint: String = "") -> bool:
	return length == "correct" and resolved_joint(id,joint) == expected_joint(id)

static func entry_offset(id: String, _length: String = "correct", _joint: String = "") -> Vector3:
	if id.begins_with("rib_"): return Vector3(-1.9 if id.begins_with("rib_l") else 1.9,0,0)
	if id in ["bow","stern"]: return Vector3(0,0,-1.8 if id == "bow" else 1.8)
	if id.begins_with("beam"): return Vector3(6.6,0,0)
	return Vector3(0,1.65,0)

static func pose(id: String, length: String = "correct", _joint: String = "") -> Transform3D:
	# A trial is a visual seating demonstration, not a collision solver. Opaque
	# receiver surfaces occlude internal overlap; actual candidate meshes and the
	# recorded choice are unchanged. Stability alone evaluates the mismatch.
	return Lengths.seated_pose(id,length)

static func gesture_pose(rest: Transform3D, seated: Transform3D, approach_distance: float) -> Transform3D:
	# A child pushes the stock into the opening, then the insertion animation
	# completes the slide. Do not demand a whole crossbeam's length of pointer
	# travel or use an outside-mouth clearance pose as the release destination.
	var distance:=rest.origin.distance_to(seated.origin)
	return rest.interpolate_with(seated,minf(1.0,approach_distance/maxf(distance,.001)))
