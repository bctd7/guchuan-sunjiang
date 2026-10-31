class_name JoineryInteraction
extends Node
const OrbitCamera = preload("res://core/orbit_camera.gd")
const GuidedDrag = preload("res://core/guided_drag.gd")
var orbit = OrbitCamera.new()
## Reusable mouse adapter. Controls consume input before _unhandled_input.
var assembly: JoineryAssembly
var camera: Camera3D
var target: Vector3:
	get: return orbit.target
	set(value): orbit.target = value
var yaw: float:
	get: return orbit.yaw
	set(value): orbit.yaw = value
var pitch: float:
	get: return orbit.pitch
	set(value): orbit.pitch = value
var distance: float:
	get: return orbit.distance
	set(value): orbit.distance = value
var mode: String = "idle"
var drag_id: String = ""
var drag_plane := Plane()
var drag_offset := Vector3.ZERO
var drag_initial := Transform3D.IDENTITY
var keyboard_active := true
var grab_local := Vector3.ZERO
var press_screen := Vector2.ZERO
var last_screen := Vector2.ZERO
var drag_moved := false
var capture_latched := false
var fit_pending := false
var fit_pending_allow_zoom_in := true
@export var capture_radius_pixels := 64.0
@export var capture_exit_multiplier := 1.30
@export var drag_threshold_pixels := 5.0

func configure(value: JoineryAssembly, view: Camera3D) -> void:
	if is_instance_valid(assembly) and assembly.reset_completed.is_connected(cancel):
		assembly.reset_completed.disconnect(cancel)
	if is_instance_valid(assembly) and assembly.connection_succeeded.is_connected(_connection_finished):
		assembly.connection_succeeded.disconnect(_connection_finished)
	assembly = value
	assembly.reset_completed.connect(cancel)
	assembly.connection_succeeded.connect(_connection_finished)
	camera = view
	if orbit.get_parent() == null: add_child(orbit)
	orbit.configure(assembly, camera)
	add_to_group("joinery_interaction")
	for other in get_tree().get_nodes_in_group("joinery_interaction"):
		if other != self and other.get_viewport() == get_viewport(): keyboard_active = false
	update_camera()

func update_camera() -> void:
	orbit.update_camera()

func fit_model(allow_zoom_in: bool = true) -> void:
	fit_pending = false
	fit_pending_allow_zoom_in = true
	orbit.fit_model(0.0 if allow_zoom_in else distance)

func request_fit() -> void:
	fit_pending = true
	fit_pending_allow_zoom_in = true
	if mode == "idle": fit_model()

func _connection_finished(_id: String) -> void:
	for id in assembly.parts:
		if assembly.states[id] != "locked": return
	# Fit the completed assembly only after the held pointer is released.
	fit_pending = true
	fit_pending_allow_zoom_in = false

func begin_drag(id: String, screen: Vector2, grab_world: Variant = null) -> bool:
	if mode != "idle" or not assembly.can_drag(id): return false
	drag_id = id
	drag_initial = assembly.parts[id].transform
	var origin: Vector3 = assembly.parts[id].global_position
	drag_plane = Plane(camera.global_basis.z, origin if grab_world == null else grab_world)
	var hit = drag_plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null: return false
	drag_offset = origin - hit
	grab_local = assembly.parts[id].global_transform.affine_inverse() * hit
	press_screen = screen
	last_screen = screen
	drag_moved = false
	capture_latched = false
	assembly.preview_capture(id,false)
	mode = "drag"
	return true

func cancel() -> void:
	# Releasing ownership never moves a safe piece, including Esc/UI/focus loss.
	mode = "idle"
	drag_id = ""
	capture_latched = false
	if is_instance_valid(assembly):
		assembly.preview_capture("",false)
		assembly.cancel_motion()
	if fit_pending: fit_model(fit_pending_allow_zoom_in)

func release(screen: Variant = null) -> void:
	# Capture happens while held. Release must never advance, align or animate.
	mode = "idle"
	drag_id = ""
	capture_latched = false
	assembly.preview_capture("",false)
	if fit_pending: fit_model(fit_pending_allow_zoom_in)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel()

func _input(event: InputEvent) -> void:
	# Release must be observed even over a UI panel, which consumes press/motion.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode != "idle":
		if mode == "drag" and get_viewport().gui_get_hovered_control() != null:
			cancel()
		else:
			release(event.position)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and keyboard_active:
		cancel()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(assembly) or not is_instance_valid(camera): return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not keyboard_active: return
			if mode == "drag":
				get_viewport().set_input_as_handled()
				return
			distance = maxf(maxf(orbit.minimum_distance, camera.near * 2.0), distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1))
			update_camera()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and mode == "idle":
			var ray := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(event.position), camera.project_ray_origin(event.position) + camera.project_ray_normal(event.position) * 100.0)
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider.has_meta("part_id"):
				var id: String = hit.collider.get_meta("part_id")
				if not owns_collider(hit.collider): return
				activate()
				assembly.select_part(id)
				if not begin_drag(id, event.position, hit.position):
					mode = "orbit"
			else:
				if not keyboard_active: return
				mode = "orbit"
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if mode == "orbit":
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.008, -1.2, 1.3)
			update_camera()
		elif mode == "drag" and assembly.can_drag(drag_id):
			drag_moved = drag_moved or event.position.distance_to(press_screen) >= drag_threshold_pixels
			if assembly.is_guided(drag_id):
				_drag_on_path(event.position - last_screen)
			else:
				var hit = drag_plane.intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
				if hit != null:
					var value: Transform3D = assembly.parts[drag_id].transform
					value.origin = assembly.to_local(hit + drag_offset)
					assembly.set_part_pose(drag_id, value)
				_update_capture(event.position,last_screen)
			last_screen = event.position
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and keyboard_active:
		if event.keycode == KEY_ENTER and not assembly.selected.is_empty(): assembly.insert_part(assembly.selected)
		if event.keycode == KEY_DELETE and not assembly.selected.is_empty(): assembly.remove_part(assembly.selected)
		if event.keycode in [KEY_ENTER, KEY_DELETE]: get_viewport().set_input_as_handled()

func owns_collider(collider: Object) -> bool:
	if not collider.has_meta("part_id"): return false
	var id: String = collider.get_meta("part_id")
	return assembly.parts.has(id) and assembly.parts[id] == collider

func activate() -> void:
	for other in get_tree().get_nodes_in_group("joinery_interaction"):
		if other.get_viewport() == get_viewport(): other.keyboard_active = (other == self)

## Projected intent fixes unreachable camera-plane depth. Physical validation stays in core.
func _update_capture(screen: Vector2, previous: Vector2) -> void:
	if not drag_moved or drag_id.is_empty(): return
	var entrance := assembly.global_transform * assembly.entrance_pose(drag_id)
	var trigger := entrance * grab_local
	if camera.is_position_behind(trigger): return
	var projected := camera.unproject_position(trigger)
	var radius: float = assembly.specs[drag_id].get("capture_radius_pixels",capture_radius_pixels)
	radius *= float(get_viewport().get_visible_rect().size.y) / 900.0
	var distance := screen.distance_to(projected)
	# A broad calibration radius must not pull a piece inward while the user
	# deliberately drags away. Keep the close-center tolerance for fine alignment.
	if distance > radius*.25 and distance > previous.distance_to(projected)+.25:
		capture_latched = false
		assembly.preview_capture(drag_id,false)
		return
	var crossed := Geometry2D.get_closest_point_to_segment(projected,previous,screen).distance_to(projected) <= radius
	var inside := distance <= radius or ((capture_latched or crossed) and distance <= radius*capture_exit_multiplier)
	var result := {"ok":false,"reason":"distance"}
	if inside: result = assembly.capture_candidate(drag_id)
	capture_latched = inside and result.ok
	assembly.preview_capture(drag_id,capture_latched)
	if capture_latched:
		assembly.begin_manual(drag_id)
	if inside and not result.ok: assembly.feedback.emit(str(result.reason))

## Project only onto the current segment. At a corner choose the outgoing or
## incoming segment from the signed mouse direction, never cut the corner.
func _drag_on_path(movement: Vector2) -> void:
	GuidedDrag.apply(assembly, camera, drag_id, grab_local, movement)
