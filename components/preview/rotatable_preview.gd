class_name JointPreview
extends SubViewportContainer
## Isolated real geometry preview; selection and orbit have separate intent signals.
signal activated
signal zoom_changed(factor: float)
const Look=preload("res://components/teaching/classroom/display/workshop_look.gd")
const Orbit=preload("res://components/preview/selectable_orbit.gd")
var lighting: Node3D
var lighting_profile: Script
var viewport: SubViewport
var camera: Camera3D
var orbit: Control
var model_root: Node3D
var zoom_factor:=1.0
var _height:=1.8
var _width:=2.8
var _suspended := false
var _animating := false
var _interactive := true
func _ready() -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new();viewport.size=Vector2i(420,132);viewport.own_world_3d=true;viewport.gui_disable_input=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	# Model replacement must not remove the preview's environment and lights.
	lighting=Node3D.new();lighting.name="PreviewLighting";viewport.add_child(lighting)
	_install_default_lighting()
	model_root=Node3D.new();viewport.add_child(model_root)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.current=true;viewport.add_child(camera)
	orbit=Orbit.new();add_child(orbit);orbit.activated.connect(func():activated.emit());orbit.zoom_requested.connect(zoom)
	orbit.camera_changed.connect(request_frame)
	resized.connect(_fit)
	visibility_changed.connect(_sync_activity)
	_sync_activity()
func replace_model(model: Node3D) -> void:
	for child in model_root.get_children():model_root.remove_child(child);child.queue_free()
	model_root.add_child(model)
	request_frame()

func show_model(model: Node3D,center: Vector3,direction: Vector3,height: float,width: float) -> void:
	replace_model(model)
	_height=height;_width=width;zoom_factor=1.0
	var elevation:=asin(direction.normalized().y)
	orbit.yaw_limit=PI;orbit.pitch_min=elevation-deg_to_rad(75);orbit.pitch_max=elevation+deg_to_rad(75)
	orbit.configure(camera,center,direction,true)
	_fit()
	# A new viewport may submit its first frame before its camera/layout changes.
	# Redraw once with the committed transform before freezing the specimen.
	if not get_tree().process_frame.is_connected(_draw_settled_model):
		get_tree().process_frame.connect(_draw_settled_model, CONNECT_ONE_SHOT)

func _draw_settled_model() -> void:
	camera.force_update_transform()
	request_frame()

func _fit() -> void:
	if not is_instance_valid(camera):return
	var aspect:=maxf(size.x,1)/maxf(size.y,1)
	camera.size=maxf(_height,_width/aspect)*zoom_factor
	request_frame()

func _sync_activity() -> void:
	if not is_instance_valid(orbit):return
	var enabled := is_visible_in_tree() and not _suspended
	var input_enabled := enabled and _interactive
	orbit.set_process(input_enabled);orbit.set_process_input(input_enabled)
	orbit.mouse_filter = Control.MOUSE_FILTER_STOP if input_enabled else Control.MOUSE_FILTER_IGNORE
	if not input_enabled:
		orbit.suspend_gesture()
	if enabled:
		request_frame()
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func request_frame() -> void:
	if is_instance_valid(viewport) and is_visible_in_tree() and not _suspended:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if _animating else SubViewport.UPDATE_ONCE
		if not _animating and not RenderingServer.frame_post_draw.is_connected(_finish_frame):
			RenderingServer.frame_post_draw.connect(_finish_frame, CONNECT_ONE_SHOT)

func _finish_frame() -> void:
	if not _animating:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_animating(value: bool) -> void:
	_animating = value
	request_frame()

func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	_sync_activity()

func set_interactive(value: bool) -> void:
	_interactive = value
	_sync_activity()

func _install_default_lighting() -> void:
	Look.install(lighting)

func zoom(factor: float) -> void:
	zoom_factor=clampf(zoom_factor*factor,.30,1.6)
	_fit();zoom_changed.emit(zoom_factor)
func reset_view() -> void:
	zoom_factor=1.0;orbit.configure(camera,orbit._center,orbit._direction,true);_fit();zoom_changed.emit(zoom_factor)

func frame(center: Vector3,direction: Vector3,height: float,width: float) -> void:
	_height=height;_width=width;zoom_factor=1.0
	orbit.configure(camera,center,direction,true);_fit();zoom_changed.emit(zoom_factor)
func frame_model(node: Node3D,direction: Vector3) -> void:
	var points: Array[Vector3]=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for index in 8:points.append(mesh.global_transform*mesh.get_aabb().get_endpoint(index))
	if points.is_empty():return
	var bounds:=AABB(points[0],Vector3.ZERO)
	for point in points:bounds=bounds.expand(point)
	var center:=bounds.get_center();orbit.configure(camera,center,direction,true)
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for point in points:
		var local:=camera.global_transform.affine_inverse()*point
		low=low.min(Vector2(local.x,local.y));high=high.max(Vector2(local.x,local.y))
	_height=maxf(.2,(high.y-low.y)*1.35);_width=maxf(.3,(high.x-low.x)*1.35);zoom_factor=1.0;_fit();zoom_changed.emit(zoom_factor)

func set_lighting_profile(profile: Script) -> void:
	if lighting_profile==profile:return
	lighting_profile=profile
	for child in lighting.get_children():
		lighting.remove_child(child);child.free()
	if profile!=null:profile.install(lighting)
	else:_install_default_lighting()
	request_frame()
