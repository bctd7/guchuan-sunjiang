extends SubViewportContainer
## Read-only original lesson meshes. No Assembly, rules, input or mutable lesson state.
const Look=preload("res://demo/workshop_look.gd")
var definition: Dictionary={}
var mesh_nodes: Dictionary={}
var original_meshes: Dictionary={}
var viewport: SubViewport
var camera: Camera3D

func _ready() -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new()
	viewport.size=Vector2i(420,340)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.gui_disable_input=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("fffaf0")
	env.environment.ambient_light_energy=.36
	world.add_child(env)
	for pose in [Vector3(-48,-30,0),Vector3(-20,140,0)]:
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=pose
		light.light_color=Color("fffbf5")
		light.light_energy=.65 if pose.y<0 else .20
		# Keep suspended specimens clean against the shared paper background.
		light.shadow_enabled=false
		world.add_child(light)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.near=.05
	camera.current=true
	world.add_child(camera)
	viewport.size_changed.connect(_fit)

func configure(id: String) -> void:
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	for item in catalog:
		if item.id==id: definition=item.duplicate(true);break
	if definition.is_empty(): return
	var index:=0
	for spec in definition.parts:
		var visual:=MeshInstance3D.new()
		visual.name=spec.id
		var original: Mesh=load(spec.mesh)
		original_meshes[spec.id]=original
		# Original OBJ normals blend across cut corners. Rebuild only display normals;
		# triangle positions, model resources and classroom meshes remain untouched.
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		for vertex in original.get_faces(): surface.add_vertex(vertex)
		surface.generate_normals()
		visual.mesh=surface.commit()
		visual.position=_vector(spec.start_position)
		visual.rotation_degrees=_vector(spec.get("start_rotation",[0,0,0]))
		var material:=StandardMaterial3D.new()
		material.albedo_color=Look.WOOD_COLORS[index%Look.WOOD_COLORS.size()]
		material.roughness=.88
		material.metallic_specular=.22
		visual.material_override=material
		viewport.add_child(visual)
		mesh_nodes[spec.id]=visual
		index+=1
	_fit()

func _vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func _fit() -> void:
	if mesh_nodes.is_empty() or camera==null: return
	var points: Array[Vector3]=[]
	var bounds: AABB
	var first:=true
	for visual in mesh_nodes.values():
		var box: AABB=visual.transform*visual.mesh.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
		for corner in 8: points.append(box.get_endpoint(corner))
	var center:=bounds.get_center()
	camera.position=center+Vector3(7,5.3,8)
	camera.look_at(center)
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for point in points:
		var local: Vector3=camera.transform.affine_inverse()*point
		low=low.min(Vector2(local.x,local.y))
		high=high.max(Vector2(local.x,local.y))
	var aspect:=float(maxi(viewport.size.x,1))/maxi(viewport.size.y,1)
	var span:=high-low
	camera.size=maxf(span.y,span.x/aspect)*1.20
	var middle: Vector2=(low+high)/2
	camera.position+=camera.basis.x*middle.x+camera.basis.y*middle.y
