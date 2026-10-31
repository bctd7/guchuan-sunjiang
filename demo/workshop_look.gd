extends RefCounted
## Shared rendering setup only. Meshes, colliders and assembly rules are untouched.
const FriendlyTheme = preload("res://demo/friendly_theme.gd")
const WOOD_COLORS := [Color("b89569"),Color("dcc29b"),Color("9e805d"),Color("c9ac83")]

static func install(host: Node3D) -> void:
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
		var material := assembly.parts[id].get_node("Wood").material_override as StandardMaterial3D
		if material == null: continue
		var alpha := material.albedo_color.a
		material.albedo_color = WOOD_COLORS[index%WOOD_COLORS.size()]
		material.albedo_color.a = alpha
		material.roughness = .88
		material.metallic_specular = .22
		material.albedo_texture = null
		material.rim_enabled = false
		index += 1

static func style_lesson(presenter: CanvasLayer) -> void:
	# The scene's educational drawing/lifecycle are left entirely to its module.
	presenter.panel.theme = FriendlyTheme.make_theme(true)

