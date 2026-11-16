extends RefCounted
## Ship-local visual snapshot. No State, Rules, View or completion decision lives here.
class LoosePart:
	extends RefCounted
	var id: String
	var node: Node3D
	var rest: Transform3D
	var withdraw: Vector3
	func _init(value: String,part: Node3D,pose: Transform3D,direction:=Vector3.UP) -> void:
		id=value;node=part;rest=pose;withdraw=direction
var type_error_ids: Array[String]=[]
var structural_ids: Array[String]=[]
var seam_rows: Array[int]=[]
var seam_poses: Array[Transform3D]=[]
var connection_points: Array[Vector3]=[]
var loose_parts: Array[LoosePart]=[]
func snapshot():
	var copy=get_script().new()
	copy.type_error_ids.assign(type_error_ids)
	copy.structural_ids.assign(structural_ids)
	copy.seam_rows.assign(seam_rows)
	copy.seam_poses.assign(seam_poses)
	copy.connection_points.assign(connection_points)
	for part in loose_parts:copy.loose_parts.append(LoosePart.new(part.id,part.node,part.rest,part.withdraw))
	return copy
