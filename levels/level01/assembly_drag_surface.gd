extends "res://levels/shared/inspection_orbit.gd"
var guidance_blocker: Control
## Preview-only insertion. The owner decides whether an assembly request is valid.
signal zoom_requested(factor: float)
signal assembly_requested
## A visible reference part was pressed before explicit type/length selection.
signal selection_required
signal insertion_progress_changed(progress: float)

enum Gesture { NONE, ORBIT, PART }
const SNAP_DEPTH := .72
const Pinch = preload("res://levels/shared/touch_pinch.gd")
var pinch = Pinch.new()
var assembly_enabled := false
var assembly_dragging := false
var drag_progress := 0.0
var accepted_pose:=Transform3D.IDENTITY
var preview_limit := 1.0
var _part: Node3D
var _rest_pose := Transform3D.IDENTITY
var _seated_pose := Transform3D.IDENTITY
var _grab_local := Vector3.ZERO
var _path_start := Vector2.ZERO
var _path_end := Vector2.ZERO
var _press_point := Vector2.ZERO
var _last_point := Vector2.ZERO
var _moved := false
var _guide_axis:=Vector2.LEFT
var _travel_pixels:=120.0
var _mouth_world:=Vector3.ZERO
var _tip_local:=Vector3.ZERO
var _gesture := Gesture.NONE
# Immutable mesh topology is reused while checking the visible scene.
var _mesh_faces: Dictionary = {}

## Both poses use the part parent's coordinate system. Call after configuring orbit
## and after setting the displayed candidate's separated starting transform.
func configure_assembly(part: Node3D, seated_pose: Transform3D, grab_point_local: Vector3, enabled: bool, mouth_world: Variant = null, tip_local: Variant = null) -> void:
	cancel()
	_mesh_faces.clear()
	_part = part
	_seated_pose = seated_pose
	_grab_local = grab_point_local
	assembly_enabled = enabled and is_instance_valid(part)
	if is_instance_valid(part): _rest_pose = part.transform
	accepted_pose=_rest_pose
	_mouth_world=mouth_world if mouth_world is Vector3 else _parent_world()*(seated_pose*grab_point_local)
	_tip_local=tip_local if tip_local is Vector3 else grab_point_local

func _ready() -> void:
	super._ready()
	resized.connect(cancel)
	get_viewport().size_changed.connect(cancel)

func cancel() -> void:
	pinch.reset()
	if (assembly_dragging or drag_progress>0) and is_instance_valid(_part): _part.transform = _rest_pose
	assembly_dragging = false
	_gesture = Gesture.NONE
	drag_progress = 0.0
	insertion_progress_changed.emit(0.0)
	_moved = false
	super.cancel()

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): cancel()

func _process(delta: float) -> void:
	if _gesture != Gesture.PART: super._process(delta)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(guidance_blocker) and guidance_blocker.is_visible_in_tree():return
	if not active or not assembly_enabled or not is_instance_valid(_part): return
	var grip:=_project(_parent_world()*(_part.transform*_grab_local))
	var path:=target_screen()-drag_start_screen()
	var direction:=_guide_axis if assembly_dragging else (path.normalized() if path.length()>18 else Vector2.UP)
	preload("res://levels/shared/step_guide.gd").draw_direction(self,grip,direction)

func _park_for_pinch() -> void:
	# Changing finger count cancels the pending release, not the real shallow pose.
	assembly_dragging = false
	_gesture = Gesture.NONE
	_moved = false
	super.cancel()

func suspend_gesture() -> void:
	_park_for_pinch()
	pinch.reset()

func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree(): return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		var action: Dictionary = pinch.feed(event)
		if action.interrupt: _park_for_pinch()
		if not is_equal_approx(action.factor, 1.0): zoom_requested.emit(action.factor)
		if action.suppress: return
		if event is InputEventScreenTouch and event.canceled:
			cancel(); return
	# A held part can be released over another GUI control. Process that raw
	# release only if normal GUI delivery did not already finish the gesture.
	if assembly_dragging and _gesture==Gesture.PART:
		var release: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and event.device!=InputEvent.DEVICE_ID_EMULATION
		release=release or (event is InputEventScreenTouch and not event.pressed and not event.canceled and event.index==_touch_index)
		if release:
			call_deferred("_release_from_viewport",_generation,get_global_transform_with_canvas().affine_inverse()*event.position)
	# Base release fallback cancels a gesture whose release never reaches the GUI.
	super._input(event)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: cancel()

func _gui_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventScreenTouch and event.pressed: pinch.claim(event.index)
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and pinch.suppress_current:
		accept_event(); return
	if event is InputEventMouse and pinch.blocked:
		accept_event(); return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if not assembly_dragging:zoom_requested.emit(.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.15)
		accept_event();return
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		_mouse_down = false
		if event.canceled:
			cancel()
		elif event.pressed and _touch_index < 0:
			super.cancel()
			_touch_index = event.index
			_origin = event.position
			_begin_preview(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release_preview(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_move_pointer(event.position, event.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _last_touch_ms >= 450:
			if event.pressed and _touch_index < 0 and pinch.points.is_empty():
				super.cancel()
				_mouse_down = true
				_origin = event.position
				_begin_preview(event.position)
			elif not event.pressed and _mouse_down:
				_release_preview(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _mouse_down and _touch_index < 0 and event.device != InputEvent.DEVICE_ID_EMULATION:
			_move_pointer(event.position, event.relative)
		elif not assembly_dragging:
			mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if _hit_part(event.position) or _on_grip_handle(event.position) else Control.CURSOR_DRAG
		accept_event()

func _release_from_viewport(generation: int, point: Vector2) -> void:
	if generation==_generation and assembly_dragging:_release_preview(point)

func _begin_preview(point: Vector2) -> void:
	# Lock ownership on press; moving over wood never changes a camera gesture.
	_gesture = Gesture.ORBIT
	if not _hit_part(point) and not _on_grip_handle(point): return
	_gesture = Gesture.PART
	if not assembly_enabled:
		selection_required.emit()
		return
	_path_start=drag_start_screen()
	_path_end=target_screen()
	var path:=_path_end-_path_start
	# Same projected-path approach as core/guided_drag, with bounded sensitivity
	# for a long beam or end-on camera. The hand never aims at a receiving circle.
	_guide_axis=path.normalized() if path.length()>=18 else Vector2.UP
	_travel_pixels=clampf(path.length(),80,220)
	assembly_dragging=true
	_press_point=point
	_last_point=point
	_moved=false

func _move_pointer(point: Vector2, relative: Vector2) -> void:
	if _gesture==Gesture.ORBIT:
		_rotate_drag(point,relative)
		return
	if _gesture!=Gesture.PART or not assembly_dragging:return
	if not is_instance_valid(_part):cancel();return
	if point.distance_to(_press_point)<=(TOUCH_DRAG_SLOP if _touch_index>=0 else DRAG_SLOP) and not _moved:return
	drag_progress=clampf(drag_progress+(point-_last_point).dot(_guide_axis)/_travel_pixels,0,preview_limit)
	_last_point=point
	_part.transform=_rest_pose.interpolate_with(_seated_pose,drag_progress)
	_moved=_moved or not _part.transform.is_equal_approx(_rest_pose)
	insertion_progress_changed.emit(drag_progress)

func _release_preview(point: Vector2) -> void:
	var request:=false
	var was_dragging:=assembly_dragging
	if assembly_dragging and is_instance_valid(_part):
		_move_pointer(point,Vector2.ZERO)
		request=_moved and drag_progress>=SNAP_DEPTH
		if request:accepted_pose=_part.transform
	if request:
		cancel()
		assembly_requested.emit()
	elif was_dragging:
		# Keep a shallow release at its real partial pose. Re-grab to continue or
		# withdraw. Focus loss, explicit cancel and closing still reset safely.
		assembly_dragging=false
		_gesture=Gesture.NONE
		_moved=false
		super.cancel()
	else:cancel()

func _on_grip_handle(point: Vector2) -> bool:
	return assembly_enabled and is_instance_valid(_part) and point.distance_to(_project(_parent_world()*(_part.transform*_grab_local)))<=20.0

func _in_capture_zone(_point: Vector2) -> bool:
	return is_instance_valid(_part) and drag_progress>=SNAP_DEPTH

## Coordinates local to this overlay, independent of viewport render scale.

func drag_start_screen() -> Vector2:
	if not is_instance_valid(_part): return Vector2(-10000, -10000)
	var pose := _rest_pose
	return _project(_parent_world() * (pose * _grab_local))

func target_screen() -> Vector2:
	if not is_instance_valid(_part): return Vector2(-10000, -10000)
	return _project(_parent_world() * (_seated_pose * _grab_local))

func _parent_world() -> Transform3D:
	var parent := _part.get_parent() as Node3D
	return parent.global_transform if parent else Transform3D.IDENTITY

func _project(world_point: Vector3) -> Vector2:
	if not is_instance_valid(camera) or camera.is_position_behind(world_point): return Vector2(-10000, -10000)
	var viewport_size := Vector2(camera.get_viewport().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0: return Vector2(-10000, -10000)
	return camera.unproject_position(world_point) * size / viewport_size

func _hit_part(point: Vector2) -> bool:
	if not is_instance_valid(_part) or not is_instance_valid(camera): return false
	if not Rect2(Vector2.ZERO, size).has_point(point): return false
	var viewport_size := Vector2(camera.get_viewport().size)
	if size.x <= 0.0 or size.y <= 0.0: return false
	var pixel := point * viewport_size / size
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	# The nearest rendered triangle owns the pixel. This covers the whole beam,
	# preserves holes, and prevents a receiver in front from grabbing the part.
	var hit := {"distance": INF, "part": false}
	_pick_visible(camera.get_viewport(), origin, direction, hit)
	return hit.part

func _pick_visible(node: Node, origin: Vector3, direction: Vector3, hit: Dictionary) -> void:
	if node is Viewport and node != camera.get_viewport(): return
	if node is MeshInstance3D and node.mesh and node.is_visible_in_tree() and node.layers & camera.cull_mask:
		var candidate := node == _part or _part.is_ancestor_of(node)
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction: Vector3 = inverse.basis * direction
		for surface_index in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface_index)
			# Cutaway receivers are deliberately transparent; opaque wood still
			# occludes, including the blind mortise's solid bottom.
			if not candidate and not _is_opaque(node, material): continue
			var faces := _surface_faces(node.mesh, surface_index)
			for index in range(0, faces.size(), 3):
				var a: Vector3 = faces[index]
				var b: Vector3 = faces[index + 1]
				var c: Vector3 = faces[index + 2]
				var facing := (b - a).cross(c - a).dot(local_direction)
				# Godot meshes use clockwise front-face winding.
				var cull := BaseMaterial3D.CULL_BACK
				if material is BaseMaterial3D: cull = material.cull_mode
				if cull == BaseMaterial3D.CULL_BACK and facing <= 0.0: continue
				if cull == BaseMaterial3D.CULL_FRONT and facing >= 0.0: continue
				var intersection = Geometry3D.ray_intersects_triangle(local_origin, local_direction, a, b, c)
				if intersection == null: continue
				var world_point: Vector3 = node.global_transform * intersection
				var depth := -camera.to_local(world_point).z
				if depth < camera.near or depth > camera.far: continue
				var distance := (world_point - origin).dot(direction)
				if distance >= 0.0 and distance < hit.distance:
					hit.distance = distance
					hit.part = candidate
	for child in node.get_children(): _pick_visible(child, origin, direction, hit)

func _is_opaque(node: MeshInstance3D, material: Material) -> bool:
	if node.transparency > 0.0: return false
	if material is BaseMaterial3D:
		return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	# Custom shaders in this scene are treated as solid, as they are rendered.
	return true

func _surface_faces(mesh: Mesh, surface_index: int) -> PackedVector3Array:
	var key := "%s:%d" % [mesh.get_instance_id(), surface_index]
	if _mesh_faces.has(key): return _mesh_faces[key]
	var faces := PackedVector3Array()
	if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES: return faces
	var arrays := mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty(): faces = vertices
	else:
		for index in indices: faces.append(vertices[index])
	_mesh_faces[key] = faces
	return faces

