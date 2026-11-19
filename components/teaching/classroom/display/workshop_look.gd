extends RefCounted
## Shared rendering setup only. Triangle positions, colliders and assembly rules are untouched.
const FriendlyTheme = preload("res://components/ui/friendly_theme.gd")
const WOOD_COLORS := [Color("b89569"),Color("dcc29b"),Color("9e805d"),Color("c9ac83")]
# Same restrained, matte timber recipe as the ship in the levels. Shared by all
# specimens and previews; each material keeps its own colour and grain direction.
static var _grain_texture: NoiseTexture2D
static var _display_meshes: Dictionary = {}

static func install(host: Node3D, camera: Camera3D = null) -> void:
	# A single shared viewport setting; no subdivision or geometry changes.
	host.get_viewport().msaa_3d = Viewport.MSAA_8X
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f3ead7")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fffaf0")
	environment.environment.ambient_light_energy = .32
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# A hidden level's WorldEnvironment still belongs to the shared World3D.
	# Bind the lesson environment to its camera so embedded and standalone views
	# match, without changing the source level's environment on entry or return.
	if camera != null:
		camera.environment = environment.environment
		environment.free()
	else:
		host.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-30,0)
	key.light_color = Color("fffbf5")
	key.light_energy = .65
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 24.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	host.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20,140,0)
	fill.light_color = Color("edf2e5")
	fill.light_energy = .20
	host.add_child(fill)

static func apply_materials(assembly: Node3D) -> void:
	var index := 0
	for id in assembly.parts:
		var visual := assembly.parts[id].get_node("Wood") as MeshInstance3D
		var material := visual.material_override as StandardMaterial3D
		if material == null: continue
		var source := source_mesh(visual.mesh)
		visual.mesh = display_mesh(source)
		configure_wood(material, index, source)
		index += 1

static func wood_material(index: int, mesh: Mesh) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	configure_wood(material, index, mesh)
	return material

static func configure_wood(material: StandardMaterial3D, index: int, mesh: Mesh) -> void:
	# Keep StandardMaterial3D and its alpha/transparency: Assembly.set_xray mutates
	# them directly. Texture coordinates are local, so grain follows moving stock.
	var alpha := material.albedo_color.a
	material.albedo_color = WOOD_COLORS[index % WOOD_COLORS.size()]
	material.albedo_color.a = alpha
	material.roughness = .86
	material.metallic_specular = .22
	material.rim_enabled = false
	material.vertex_color_use_as_albedo = true
	material.uv1_triplanar_sharpness = 16.0
	material.albedo_texture = grain_texture()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = grain_scale(mesh)

static func grain_scale(mesh: Mesh) -> Vector3:
	# The longest local dimension is the stock's fibre direction. This also keeps
	# upright posts, cross rails and thin boards consistent without OBJ UV edits.
	var size := mesh.get_aabb().size
	var scale := Vector3(5.0, 5.0, 5.0)
	scale[size.max_axis_index()] = .35
	return scale

static func grain_texture() -> NoiseTexture2D:
	if _grain_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 1739
		noise.frequency = .035
		noise.fractal_octaves = 3
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(.64,.58,.49), Color.WHITE])
		_grain_texture = NoiseTexture2D.new()
		_grain_texture.width = 256
		_grain_texture.height = 256
		_grain_texture.noise = noise
		_grain_texture.seamless = true
		_grain_texture.color_ramp = ramp
	return _grain_texture

static func source_mesh(mesh: Mesh) -> Mesh:
	return mesh.get_meta("wood_source_mesh", mesh) as Mesh

static func display_mesh(mesh: Mesh) -> Mesh:
	mesh = source_mesh(mesh)
	if _display_meshes.has(mesh): return _display_meshes[mesh]
	# Imported OBJ files have no normals. Their generated smooth normals shade
	# flat stock like moulded plastic. Repair only render normals/vertex colours:
	# every triangle stays in place; Assembly's collider and guard retain the OBJ.
	var faces := mesh.get_faces()
	var axis := mesh.get_aabb().size.max_axis_index()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for triangle in range(0, faces.size(), 3):
		var normal := (faces[triangle + 1] - faces[triangle]).cross(faces[triangle + 2] - faces[triangle]).normalized()
		# A small warm end-stock tint makes cut ends and mortise floors legible.
		var tint := Color(.88,.82,.72) if absf(normal[axis]) > .85 else Color.WHITE
		for corner in 3:
			surface.set_color(tint)
			surface.add_vertex(faces[triangle + corner])
	surface.generate_normals()
	var generated := surface.commit()
	# OBJ compression keeps an original surface AABB that is slightly different
	# from its decoded vertices. Preserve that serialized bound exactly: camera
	# fitting and symmetric pointer hit tests must keep the original behaviour.
	var surfaces: Array = generated.get("_surfaces")
	surfaces[0]["aabb"] = mesh.get_aabb()
	var display := ArrayMesh.new()
	display.set("_surfaces", surfaces)
	display.set_meta("wood_source_mesh", mesh)
	_display_meshes[mesh] = display
	return display

static func style_lesson(presenter: CanvasLayer) -> void:
	# The scene's educational drawing/lifecycle are left entirely to its module.
	presenter.panel.theme = FriendlyTheme.make_theme(true)

