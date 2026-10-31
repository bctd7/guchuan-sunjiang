class_name JoineryAssembly
extends Node3D
const InsertionPath = preload("res://core/insertion_path.gd")
const MeshCollisionGuard = preload("res://core/mesh_collision_guard.gd")
## Reusable assembly controller. All poses and connector targets are assembly-local.
## This class has no dependency on the demo, camera or UI.
signal changed
signal feedback(message: String)
signal connection_succeeded(part_id: String)
signal disassembled(part_id: String) # Retained for embedding compatibility; never emitted.
signal reset_completed
@export var distance_tolerance: float = 0.8
@export var angle_tolerance_degrees: float = 30.0
@export var insertion_speed: float = 2.2
var definition: Dictionary = {}
var parts: Dictionary = {}
var specs: Dictionary = {}
var states: Dictionary = {}
var occupied: Dictionary = {}
var selected: String = ""
var moving: String = ""
var paths: Dictionary = {}
var progress: Dictionary = {}
var path_progress: Dictionary:
	get: return progress
var capture_preview := ""
@export var capture_distance := 1.25
@export var capture_angle_degrees := 35.0
var ghost: MeshInstance3D
var xray := false
var collision_guard = MeshCollisionGuard.new()

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
	paths.clear()
	states.clear()
	occupied.clear()
	selected = ""
	ghost = null
	collision_guard = MeshCollisionGuard.new()
	definition = data.duplicate(true)
	for spec in definition.parts:
		var id: String = spec.id
		specs[id] = spec
		paths[id] = InsertionPath.new(spec.insertion_path)
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
	progress.clear()
	capture_preview = ""
	selected = ""
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

func insert_part(id: String, _legacy_instant: bool = false) -> bool:
	# Compatibility entry point now only engages the guide; never auto-completes.
	return begin_insertion(id)

func is_guided(id: String) -> bool:
	return parts.has(id) and states.get(id, "") == "guided"

func begin_insertion(id: String) -> bool:
	if is_guided(id): return true
	if not parts.has(id) or not capture_candidate(id).ok: return false
	var path = paths[id]
	if not path.valid():
		feedback.emit("invalid_path_pose")
		return false
	var snapped := socket_pose(id) * connector_pose(id).affine_inverse()
	if not snapped.is_equal_approx(entrance_pose(id)):
		feedback.emit("invalid_path_pose")
		return false
	# Calibration is generous, never a collision bypass. Preflight the full route.
	if not _motion_clear(id, parts[id].transform, snapped) or not _path_clear(id, snapped, specs[id].insertion_path, assembled_pose(id)):
		feedback.emit("collision_blocked")
		return false
	parts[id].transform = snapped
	progress[id] = 0.0
	states[id] = "guided"
	hide_ghost()
	feedback.emit("guided")
	changed.emit()
	return true

func advance_insertion(id: String, amount: float) -> bool:
	if not is_guided(id) or not is_finite(amount): return false
	var path = paths[id]
	var destination: float = clampf(float(progress[id]) + amount, 0.0, path.length)
	# Projection can leave a few micrometres after regrabbing. Validate the
	# exact endpoint too, so that exhausted segment input reaches permanent lock.
	if amount > 0.0 and path.length - destination <= 0.00001:
		destination = path.length
	var current: Transform3D = parts[id].transform
	# Validate every segment before committing, so blocked input retains safe pose.
	for point in path.traversal(float(progress[id]), destination):
		var next := Transform3D(current.basis, point)
		if not _motion_clear(id, current, next):
			feedback.emit("collision_blocked")
			return false
		current = next
	parts[id].transform = current
	progress[id] = destination
	if destination >= path.length:
		states[id] = "locked"
		occupied[id] = id
		feedback.emit("locked")
		connection_succeeded.emit(id)
	elif float(progress[id]) == 0.0 and amount < 0.0:
		states[id] = "free"
		progress.erase(id)
		feedback.emit("withdrawn")
	update_ghost()
	changed.emit()
	return true

func can_remove(_id: String) -> bool:
	# A completed connection is permanent for this round, including API callers.
	return false

func remove_part(_id: String, _legacy_instant: bool = false) -> bool:
	feedback.emit("permanent_lock")
	return false

func _stop_motion() -> void:
	moving = ""

func cancel_motion() -> void:
	# Focus loss, Escape and release pause exactly where the player stopped.
	# No tween, rewind, extrapolation or movement occurs without pointer input.
	moving = ""

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
	material.albedo_color = Color(0.18,0.72,0.51,0.28) if candidate(selected).ok else Color(0.24,0.57,0.8,0.16)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = material
	ghost.show()

func set_xray(enabled: bool) -> void:
	xray = enabled
	for id in parts:
		var material: StandardMaterial3D = parts[id].get_node("Wood").material_override
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 0.25 if enabled else 1.0

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
	# The position-only route must end at the complete final pose.
	return previous.is_equal_approx(final_pose)

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
	return {"ok":true,"reason":"manual_ready","distance":distance,"angle":angle}

func preview_capture(id: String, ready: bool) -> void:
	var next := id if ready else ""
	if capture_preview == next: return
	capture_preview = next
	update_ghost()
	changed.emit()
	if ready: feedback.emit("manual_ready")


# Manual pointer interaction API shared by the classroom adapters.
func can_drag(id: String) -> bool:
	return is_editable(id) or is_guided(id)

func path_length(id: String) -> float:
	return paths[id].length if paths.has(id) else 0.0

func path_pose(id: String, value: float) -> Transform3D:
	return Transform3D(entrance_pose(id).basis, paths[id].sample(value))

func begin_manual(id: String) -> bool:
	return begin_insertion(id)

func advance_manual(id: String, amount: float) -> bool:
	return advance_insertion(id, amount)

