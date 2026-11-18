extends RefCounted
## Camera framing and host/subviewport projection only; no chapter state or geometry IDs.
var camera: Camera3D
var surface: Control
var viewport: SubViewport
var orbit: Control
var _overview_size:=11.5
var _inspection_size:=4.0
const MIN_ZOOM:=.25
const MAX_ZOOM:=1.6
var zoom_factor:=1.0
var _last_angles:=Vector2.ZERO
var _frame_center:=Vector3.ZERO
var _zoom_focus:=Vector3.ZERO
func configure(value: Camera3D) -> void:camera=value
func configure_workspace(value: Control,target: SubViewport,controller: Control) -> void:
	surface=value;viewport=target;orbit=controller
func inspect(center: Vector3,direction: Vector3,reset: bool) -> void:
	camera.h_offset=0;camera.v_offset=0
	_frame_center=center;_zoom_focus=center
	var elevation:=asin(direction.normalized().y)
	orbit.yaw_limit=PI;orbit.pitch_min=elevation-deg_to_rad(75);orbit.pitch_max=elevation+deg_to_rad(75)
	if reset:zoom_factor=1.0
	orbit.configure(camera,center,direction,reset)
func fit(points: Array[Vector3],center_members:=false) -> void:
	if points.is_empty() or not is_instance_valid(viewport):return
	var aspect:=float(maxi(viewport.size.x,1))/maxi(viewport.size.y,1)
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for point in points:
		var local:=camera.global_basis.inverse()*(point-_frame_center)
		low=low.min(Vector2(local.x,local.y));high=high.max(Vector2(local.x,local.y))
	if center_members:
		var midpoint: Vector2=(low+high)*.5
		_frame_center+=camera.global_basis.x*midpoint.x+camera.global_basis.y*midpoint.y
		low-=midpoint;high-=midpoint
		orbit._center=_frame_center.lerp(_zoom_focus,clampf((1.0-zoom_factor)/.75,0,1))
		orbit._apply_camera()
	# Orbit pivots may be off-centre. Fit both sides without moving the actual socket.
	_inspection_size=maxf(maxf(absf(low.y),absf(high.y))*2.5,maxf(absf(low.x),absf(high.x))*2.5/aspect)
	camera.size=maxf(_inspection_size,.8)*zoom_factor
func has_rotated() -> bool:
	if orbit.angles==_last_angles:return false
	_last_angles=orbit.angles
	return true
func rotate(delta: Vector2) -> void:orbit.rotate_delta(delta)
func zoom(factor: float,focus: Vector3) -> void:
	_zoom_focus=focus
	zoom_factor=clampf(zoom_factor*factor,MIN_ZOOM,MAX_ZOOM)
	orbit._center=_frame_center.lerp(_zoom_focus,clampf((1.0-zoom_factor)/.75,0,1))
	orbit._apply_camera()
	camera.size=maxf(_inspection_size,.8)*zoom_factor
func contains(point: Vector2,inspected: bool) -> bool:
	return inspected and is_instance_valid(surface) and surface.get_global_rect().has_point(point)
func project(point: Vector3,inspected: bool) -> Vector2:
	var projected:=camera.unproject_position(point)
	if inspected and is_instance_valid(surface):
		return surface.get_global_transform_with_canvas()*(projected*surface.size/Vector2(viewport.size))
	return projected
func camera_point(point: Vector2,inspected: bool) -> Vector2:
	return (surface.get_global_transform_with_canvas().affine_inverse()*point)*Vector2(viewport.size)/surface.size if inspected and is_instance_valid(surface) else point
func overview(from: Vector3,target: Vector3,size_value: float,viewport_size: Vector2) -> void:
	camera.position=from;camera.look_at(target)
	_overview_size=size_value;fit_overview(viewport_size)
	camera.h_offset=-1.35;camera.v_offset=.08
func fit_overview(viewport_size: Vector2) -> void:
	camera.size=_overview_size*maxf(1.0,(1440.0/900.0)/(viewport_size.x/viewport_size.y))
static func corners(node: Node,points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		for index in 8:points.append(node.global_transform*node.get_aabb().get_endpoint(index))
	for child in node.get_children():corners(child,points)

func reset_view() -> void:
	zoom_factor=1.0
	orbit.configure(camera,_frame_center,orbit._direction,true)
	camera.size=maxf(_inspection_size,.8)
