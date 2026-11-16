extends RefCounted
## One fixed studio rig for the hull, candidate cards and inspection windows.
## No camera-relative light: orbiting reveals the same object under the same sun.
static func install(host: Node3D) -> Environment:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("f3ead7")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("fffaf0")
	environment.ambient_light_energy=.40
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	world.environment=environment;host.add_child(world)
	var key:=DirectionalLight3D.new();key.name="TimberKey"
	key.rotation_degrees=Vector3(-48,-35,0)
	key.light_color=Color("fffbf5");key.light_energy=.55
	key.shadow_enabled=true;key.shadow_opacity=.65
	key.directional_shadow_max_distance=24.0
	key.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	host.add_child(key)
	var fill:=DirectionalLight3D.new();fill.name="TimberFill"
	fill.rotation_degrees=Vector3(-30,145,0)
	fill.light_color=Color("fffaf0");fill.light_energy=.16
	host.add_child(fill)
	return environment
