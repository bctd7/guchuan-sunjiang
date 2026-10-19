class_name JoineryAssembly
extends Node3D
const MeshCollisionGuard = preload("res://core/mesh_collision_guard.gd")
## Reusable assembly controller. All poses and connector targets are assembly-local.
## This class has no dependency on the demo, camera or UI.
signal changed
signal feedback(message: String)
signal connection_succeeded(part_id: String)
signal disassembled(part_id: String)
signal reset_completed
@export var distance_tolerance: float = 0.35
@export var angle_tolerance_degrees: float = 12.0
@export var insertion_speed: float = 2.2
var definition: Dictionary = {}
var parts: Dictionary = {}
var specs: Dictionary = {}
var states: Dictionary = {}
var occupied: Dictionary = {}
var selected: String = ""
var moving: String = ""
var motion: Tween
var safe_pose := Transform3D.IDENTITY
var ghost: MeshInstance3D
var xray := false
var collision_guard = MeshCollisionGuard.new()
var travelled: Array[Vector3] = []
var travelled_poses: Array[Transform3D] = []
var capture_preview := ""
@export var capture_distance := 1.25
@export var capture_angle_degrees := 35.0

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func pose(position_value: Array, rotation_value: Array = [0,0,0]) -> Transform3D:
	return Transform3D(Basis.from_euler(vector(rotation_value) * PI / 180.0), vector(position_value))

func load_definition(data: Dictionary) -> void:
	_stop_motion()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	parts.clear()
	specs.clear()
	states.clear()
	occupied.clear()
	selected = ""
	ghost = null
	collision_guard = MeshCollisionGuard.new()
	definition = data.duplicate(true)
	for spec in definition.parts:
		var id: String = spec.id
		specs[id] = spec
		var part := StaticBody3D.new()
		part.name = id
		part.set_meta("part_id", id)
		var visual := MeshInstance3D.new()
		visual.name = "Wood"
		visual.mesh = load(spec.mesh) as Mesh
		assert(visual.mesh != null, "Missing mesh: " + str(spec.mesh))
		collision_guard.register_mesh(id, visual.mesh)
		visual.material_override = wood_material(parts.size())
		part.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.shape = visual.mesh.create_trimesh_shape()
		part.add_child(collision)
		add_child(part)
		parts[id] = part
	reset()

func wood_material(index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("805b38").lerp(Color("b99569"), float(index % 4) / 4.0)
	material.roughness = 0.72
	return material

func assembled_pose(id: String) -> Transform3D:
	var spec: Dictionary = specs[id]
	return pose(spec.assembled_position, spec.get("assembled_rotation", [0,0,0]))

func entrance_pose(id: String) -> Transform3D:
	var spec: Dictionary = specs[id]
	return pose(spec.insertion_path[0], spec.get("assembled_rotation", [0,0,0]))

func socket_pose(id: String) -> Transform3D:
	var spec: Dictionary = specs[id]
	return pose(spec.get("socket_position", spec.insertion_path[0]), spec.get("socket_rotation", spec.get("assembled_rotation", [0,0,0])))

func connector_pose(id: String) -> Transform3D:
	var spec: Dictionary = specs[id]
	return pose(spec.get("connector_position", [0,0,0]), spec.get("connector_rotation", [0,0,0]))

func reset() -> void:
	# Reset explicitly rebuilds the arrangement; it is not a physical traversal.
	_stop_motion()
	occupied.clear()
	selected = ""
	capture_preview = ""
	for id in parts:
		var spec: Dictionary = specs[id]
		parts[id].transform = assembled_pose(id) if spec.get("fixed", false) else pose(spec.start_position, spec.get("start_rotation", [0,0,0]))
		states[id] = "locked" if spec.get("fixed", false) else "free"
		if spec.get("fixed", false): occupied[id] = id
	hide_ghost()
	changed.emit()
	reset_completed.emit()

func select_part(id: String) -> bool:
	if not parts.has(id) or not moving.is_empty(): return false
	selected = id
	update_ghost()
	changed.emit()
	return true

func is_editable(id: String) -> bool:
	return parts.has(id) and states[id] == "free" and moving.is_empty()

func set_part_pose(id: String, value: Transform3D) -> bool:
	if not is_editable(id): return false
	if not _motion_clear(id, parts[id].transform, value):
		feedback.emit("collision_blocked")
		return false
	parts[id].transform = value
	update_ghost()
	changed.emit()
	return true

func rotate_part(id: String, axis: Vector3, radians: float) -> bool:
	if not is_editable(id): return false
	var value: Transform3D = parts[id].transform
	value.basis = Basis(axis.normalized(), radians) * value.basis
	return set_part_pose(id, value)

func candidate(id: String, socket_id: String = "") -> Dictionary:
	if socket_id.is_empty(): socket_id = id
	if not parts.has(id) or not specs.has(socket_id): return {"ok": false, "reason": "unknown"}
	if socket_id != id: return {"ok": false, "reason": "pair"}
	if occupied.has(socket_id): return {"ok": false, "reason": "occupied"}
	if not is_editable(id): return {"ok": false, "reason": "busy"}
	for dependency in specs[id].get("dependencies", []):
		if states.get(dependency, "") != "locked": return {"ok": false, "reason": "dependency"}
	var current: Transform3D = parts[id].transform * connector_pose(id)
	var target := socket_pose(socket_id)
	var distance := current.origin.distance_to(target.origin)
	var angle := rad_to_deg(current.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion()))
	if distance > distance_tolerance: return {"ok": false, "reason": "distance", "distance": distance, "angle": angle}
	if angle > angle_tolerance_degrees: return {"ok": false, "reason": "angle", "distance": distance, "angle": angle}
	return {"ok": true, "reason": "ready", "distance": distance, "angle": angle}

func snap(id: String) -> bool:
	var result := candidate(id)
	if not result.ok:
		feedback.emit(str(result.reason))
		return false
	var target := socket_pose(id) * connector_pose(id).affine_inverse()
	if not _motion_clear(id, parts[id].transform, target):
		feedback.emit("collision_blocked")
		return false
	parts[id].transform = target
	update_ghost()
	changed.emit()
	return true

func insert_part(id: String, instant: bool = false) -> bool:
	if not parts.has(id) or not candidate(id).ok: return false
	var snapped := socket_pose(id) * connector_pose(id).affine_inverse()
	# A position-only path cannot silently correct a rotated/offset connector pose.
	if not snapped.is_equal_approx(entrance_pose(id)):
		feedback.emit("invalid_path_pose")
		return false
	if not _motion_clear(id, parts[id].transform, snapped) or not _path_clear(id, snapped, specs[id].insertion_path, assembled_pose(id)):
		feedback.emit("collision_blocked")
		return false
	if not snap(id): return false
	safe_pose = parts[id].transform
	travelled = [safe_pose.origin]
	travelled_poses = [safe_pose]
	moving = id
	states[id] = "inserting"
	hide_ghost()
	var path: Array = specs[id].insertion_path
	if instant:
		parts[id].transform = assembled_pose(id)
		_finish_insert(id)
		return true
	motion = create_tween()
	var previous: Vector3 = parts[id].position
	for point in path:
		var next := vector(point)
		motion.tween_property(parts[id], "position", next, maxf(0.08, previous.distance_to(next) / insertion_speed)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.tween_callback(_record_waypoint.bind(next))
		previous = next
	motion.tween_callback(_finish_insert.bind(id))
	changed.emit()
	return true

func _finish_insert(id: String) -> void:
	parts[id].transform = assembled_pose(id)
	states[id] = "locked"
	occupied[id] = id
	moving = ""
	motion = null
	feedback.emit("locked")
	changed.emit()
	connection_succeeded.emit(id)

func can_remove(id: String) -> bool:
	if not parts.has(id) or specs[id].get("fixed", false) or states[id] != "locked" or not moving.is_empty(): return false
	for other in specs:
		if states[other] == "locked" and id in specs[other].get("dependencies", []): return false
	return true

func remove_part(id: String, instant: bool = false) -> bool:
	if not can_remove(id):
		feedback.emit("remove_dependents_first")
		return false
	var reverse_path: Array = specs[id].insertion_path.duplicate()
	reverse_path.reverse()
	reverse_path.append(specs[id].start_position)
	if not _path_clear(id, parts[id].transform, reverse_path, withdrawn_pose(id)):
		feedback.emit("collision_blocked")
		return false
	moving = id
	safe_pose = parts[id].transform
	travelled = [safe_pose.origin]
	travelled_poses = [safe_pose]
	states[id] = "removing"
	if instant:
		_finish_remove(id)
		return true
	motion = create_tween()
	var previous: Vector3 = parts[id].position
	var path: Array = reverse_path
	for point in path:
		var next := vector(point)
		motion.tween_property(parts[id], "position", next, maxf(0.08, previous.distance_to(next) / insertion_speed)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.tween_callback(_record_waypoint.bind(next))
		previous = next
	motion.tween_callback(_finish_remove.bind(id))
	changed.emit()
	return true

func _finish_remove(id: String) -> void:
	parts[id].transform = withdrawn_pose(id)
	states[id] = "free"
	occupied.erase(id)
	moving = ""
	motion = null
	update_ghost()
	changed.emit()
	disassembled.emit(id)

func _record_waypoint(point: Vector3) -> void:
	travelled.append(point)
	if parts.has(moving): travelled_poses.append(parts[moving].transform)

func _stop_motion() -> void:
	# Internal teardown for reset/model switch. No callback can touch freed parts.
	if is_instance_valid(motion): motion.kill()
	motion = null
	moving = ""
	travelled.clear()
	travelled_poses.clear()
	capture_preview = ""

func cancel_motion() -> void:
	if moving.is_empty():
		return
	var id := moving
	if states[id] == "cancelling": return
	if is_instance_valid(motion): motion.kill()
	motion = null
	var reverse_poses: Array[Transform3D] = []
	for index in range(travelled_poses.size() - 1, -1, -1):
		reverse_poses.append(travelled_poses[index])
	var previous_pose: Transform3D = parts[id].transform
	var clear := true
	for next_pose in reverse_poses:
		if not _motion_clear(id,previous_pose,next_pose): clear = false
		previous_pose = next_pose
	if not clear or not previous_pose.is_equal_approx(safe_pose):
		# Never jump through an unexpected blocker. Reset remains an explicit escape.
		states[id] = "paused"
		moving = ""
		feedback.emit("collision_blocked")
		changed.emit()
		return
	states[id] = "cancelling"
	motion = create_tween()
	previous_pose = parts[id].transform
	for next_pose in reverse_poses:
		motion.tween_property(parts[id], "transform", next_pose, _pose_duration(previous_pose,next_pose,0.04)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		previous_pose = next_pose
	motion.tween_callback(_finish_cancel.bind(id))
	changed.emit()

func _finish_cancel(id: String) -> void:
	parts[id].transform = safe_pose
	states[id] = "locked" if occupied.has(id) else "free"
	moving = ""
	motion = null
	travelled.clear()
	travelled_poses.clear()
	update_ghost()
	changed.emit()

func withdrawn_pose(id: String) -> Transform3D:
	# Park outside the entrance so a removed piece does not block the next exit.
	return pose(specs[id].start_position, specs[id].get("assembled_rotation", [0,0,0]))

func hide_ghost() -> void:
	if is_instance_valid(ghost): ghost.hide()

func update_ghost() -> void:
	if selected.is_empty() or not is_editable(selected):
		hide_ghost()
		return
	if not is_instance_valid(ghost):
		ghost = MeshInstance3D.new()
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
	ghost.mesh = parts[selected].get_node("Wood").mesh
	ghost.transform = entrance_pose(selected)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18,0.72,0.51,0.40) if capture_preview == selected or candidate(selected).ok else Color(0.24,0.57,0.8,0.20)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = material
	ghost.show()

func set_xray(enabled: bool) -> void:
	xray = enabled
	for id in parts:
		var material: StandardMaterial3D = parts[id].get_node("Wood").material_override
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 0.25 if enabled else 1.0

func _exit_tree() -> void:
	if is_instance_valid(motion): motion.kill()

## All other real wood pieces are obstacles, including uninstalled and locked parts.
## Ghost visuals never enter this geometry query. Coordinates stay instance-local.
func _obstacle_poses(id: String) -> Dictionary:
	var obstacles: Dictionary = {}
	for other in parts:
		if other != id: obstacles[other] = parts[other].transform
	return obstacles

func _motion_clear(id: String, from: Transform3D, to: Transform3D) -> bool:
	return collision_guard.motion_is_safe(id, from, to, _obstacle_poses(id))

func _path_clear(id: String, from: Transform3D, points: Array, final_pose: Transform3D) -> bool:
	var previous := from
	for point in points:
		var next := Transform3D(from.basis, vector(point))
		if not previous.is_equal_approx(next) and not _motion_clear(id, previous, next): return false
		previous = next
	# _finish_insert/_finish_remove must never teleport orientation/position.
	return previous.is_equal_approx(final_pose)

## Intent capture is wider than precision mating, but never bypasses physical approach.
## Screen-space target choice belongs to the adapter; these constraints are model-local.
func capture_candidate(id: String) -> Dictionary:
	var result := candidate(id)
	if result.reason not in ["ready","distance","angle"]: return result
	var current: Transform3D = parts[id].transform
	var target_pose := socket_pose(id) * connector_pose(id).affine_inverse()
	if not target_pose.is_equal_approx(entrance_pose(id)):
		return {"ok":false,"reason":"invalid_path_pose"}
	var distance: float = result.distance
	var angle: float = result.angle
	if distance > float(specs[id].get("capture_distance",capture_distance)):
		return {"ok":false,"reason":"distance"}
	if angle > float(specs[id].get("capture_angle_degrees",capture_angle_degrees)):
		return {"ok":false,"reason":"angle"}
	if not _motion_clear(id,current,target_pose):
		return {"ok":false,"reason":"collision_blocked"}
	return {"ok":true,"reason":"release_to_insert","distance":distance,"angle":angle}

func preview_capture(id: String, ready: bool) -> void:
	var next := id if ready else ""
	if capture_preview == next: return
	capture_preview = next
	update_ghost()
	changed.emit()
	if ready: feedback.emit("release_to_insert")

func _pose_duration(from: Transform3D,to: Transform3D,minimum: float = 0.12) -> float:
	var angle := from.basis.get_rotation_quaternion().angle_to(to.basis.get_rotation_quaternion())
	return maxf(minimum,maxf(from.origin.distance_to(to.origin)/insertion_speed,angle/PI))

## Released capture smoothly aligns the entire connector pose before following its path.
func insert_assisted(id: String) -> bool:
	var result := capture_candidate(id)
	if not result.ok:
		feedback.emit(result.reason)
		return false
	var entrance := entrance_pose(id)
	if not _path_clear(id,entrance,specs[id].insertion_path,assembled_pose(id)):
		feedback.emit("collision_blocked")
		return false
	safe_pose = parts[id].transform
	travelled = [safe_pose.origin]
	travelled_poses = [safe_pose]
	moving = id
	states[id] = "inserting"
	capture_preview = ""
	hide_ghost()
	motion = create_tween()
	motion.tween_property(parts[id],"transform",entrance,_pose_duration(safe_pose,entrance)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_callback(_record_waypoint.bind(entrance.origin))
	var previous := entrance
	for point in specs[id].insertion_path:
		var next := Transform3D(entrance.basis,vector(point))
		if previous.is_equal_approx(next): continue
		motion.tween_property(parts[id],"transform",next,_pose_duration(previous,next,0.08)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.tween_callback(_record_waypoint.bind(next.origin))
		previous = next
	motion.tween_callback(_finish_insert.bind(id))
	changed.emit()
	return true
