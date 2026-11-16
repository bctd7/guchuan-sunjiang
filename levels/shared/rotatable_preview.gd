extends SubViewportContainer
## Isolated real geometry preview; selection and orbit have separate intent signals.
signal activated
signal zoom_changed(factor: float)
const Look=preload("res://classroom/display/workshop_look.gd")
const Orbit=preload("res://levels/shared/selectable_orbit.gd")
var lighting: Node3D
var lighting_profile: Script
var viewport: SubViewport
var camera: Camera3D
var orbit: Control
var model_root: Node3D
var zoom_factor:=1.0
var _height:=1.8
var _width:=2.8
func _ready() -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new();viewport.size=Vector2i(420,132);viewport.own_world_3d=true;viewport.gui_disable_input=true
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	# Model replacement must not remove the preview's environment and lights.
	lighting=Node3D.new();lighting.name="PreviewLighting";viewport.add_child(lighting)
	Look.install(lighting)
	model_root=Node3D.new();viewport.add_child(model_root)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.current=true;viewport.add_child(camera)
	orbit=Orbit.new();add_child(orbit);orbit.activated.connect(func():activated.emit());orbit.zoom_requested.connect(zoom)
	resized.connect(_fit)
	visibility_changed.connect(_sync_activity)
	_sync_activity()
func configure(model: Node3D,center: Vector3,direction: Vector3,height: float,width: float) -> void:
	for child in model_root.get_children():model_root.remove_child(child);child.queue_free()
	model_root.add_child(model)
	_height=height;_width=width;zoom_factor=1.0
	var elevation:=asin(direction.normalized().y)
	orbit.yaw_limit=PI;orbit.pitch_min=elevation-deg_to_rad(75);orbit.pitch_max=elevation+deg_to_rad(75)
	orbit.configure(camera,center,direction,true)
	_fit()
func _fit() -> void:
	if not is_instance_valid(camera):return
	var aspect:=maxf(size.x,1)/maxf(size.y,1)
	camera.size=maxf(_height,_width/aspect)*zoom_factor

func _sync_activity() -> void:
	if not is_instance_valid(orbit):return
	var enabled:=is_visible_in_tree()
	orbit.set_process(enabled);orbit.set_process_input(enabled)
	if not enabled:orbit.suspend_gesture()

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
	else:Look.install(lighting)
