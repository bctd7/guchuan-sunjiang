extends RefCounted
## Pure ship-part construction. No camera, input, game state or UI dependencies.
## Dimensions, hierarchy, grain and joint voids are preserved from skeleton_view.
const STATIONS := [-2.7, 0.0, 2.7]
var _wood: StandardMaterial3D
var _wood_light: StandardMaterial3D
var _endgrain: StandardMaterial3D
var _tenon: StandardMaterial3D

func _init(wood: StandardMaterial3D, lightwood: StandardMaterial3D, endgrain: StandardMaterial3D) -> void:
	_wood = wood
	_wood_light = lightwood
	_endgrain = endgrain
	# Closed, opaque end stock: a slightly deeper wood tone keeps the small
	# rib tenon readable under the existing warm close-up lighting.
	_tenon = material(Color("9e7952"))
	_tenon.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_tenon.albedo_color.a = 1.0
	_tenon.roughness = .90
	_tenon.metallic_specular = .16
	add_subtle_grain(_tenon,Vector3(.35,5.0,5.0))

func build(host: Node3D, id: String) -> void:
	if id == "keel":
		_build_keel(host)
	elif id.begins_with("rib_"):
		var side := -1.0 if id.begins_with("rib_l") else 1.0
		_build_rib(host,side,STATIONS[int(id.right(1))-1],id.right(1) != "2")
	elif id in ["bow","stern"]:
		_build_extension(host,-1.0 if id == "bow" else 1.0)
	else:
		_build_beam(host,STATIONS[0] if id == "beam1" else STATIONS[2])

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	result.metallic_specular = 0.22
	return result

static func add_subtle_grain(material: StandardMaterial3D, grain_scale: Vector3) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1739
	noise.frequency = .035
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(.86,.84,.81),Color(1,1,1)])
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	texture.seamless = true
	texture.color_ramp = ramp
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_scale = grain_scale

func _build_keel(host: Node3D) -> void:
	# A solid central web closes both side mortises. Slots never meet.
	var web := box(host, Vector3(0.20, 0.32, 7.0), Vector3(0, 0.38, 0), _wood)
	web.name = "BlindSlotWeb"
	box(host, Vector3(1.10, 0.22, 7.0), Vector3(0, 0.11, 0), _wood)
	box(host, Vector3(1.10, 0.18, 7.0), Vector3(0, 0.63, 0), _wood_light)
	var edges := [-3.5, -2.88, -2.52, -0.18, 0.18, 2.52, 2.88, 3.5]
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i+1]
		for side in [-1.0,1.0]:
			box(host, Vector3(.45, .32, b-a), Vector3(side*.325, .38, (a+b)/2.0), _wood)
	for sign_value in [-1.0, 1.0]:
		var joint := Node3D.new()
		host.add_child(joint)
		joint.rotation.y = PI if sign_value < 0 else 0.0
		# Open-ended sliding dovetail: groove is constant along Z.
		box(joint, Vector3(1.10, 0.20, 0.95), Vector3(0, 0.10, 3.975), _wood)
		_prism_z(joint, PackedVector2Array([Vector2(-.55,.2),Vector2(-.42,.2),Vector2(-.25,.72),Vector2(-.55,.72)]), 3.50, 4.45, _wood)
		_prism_z(joint, PackedVector2Array([Vector2(.42,.2),Vector2(.55,.2),Vector2(.55,.72),Vector2(.25,.72)]), 3.50, 4.45, _wood)

func _build_rib(host: Node3D, side: float, station: float, has_through_hole: bool) -> void:
	var form := Node3D.new()
	host.add_child(form)
	form.position.z = station
	# Mirroring the actual polygon preserves left/right symmetry.
	var outline := PackedVector2Array([Vector2(.55,.56),Vector2(1.22,.62),Vector2(1.92,.98),Vector2(2.43,1.50),Vector2(2.73,1.86),Vector2(2.96,1.86),Vector2(2.69,1.30),Vector2(2.12,.64),Vector2(1.34,.25),Vector2(.55,.10)])
	for i in outline.size(): outline[i].x *= side
	_prism_z(form, outline, -.23, .23, _wood_light)
	# Reduced root tenon fits the blind slot; the shoulder stops at x=.55.
	var root_tenon := box(form, Vector3(.42,.27,.30), Vector3(side*.34,.38,0), _tenon)
	root_tenon.name = "RootTenon"
	if has_through_hole:
		# A true hole along X: top/bottom and front/back cheeks only.
		box(form, Vector3(.38,.34,.46),Vector3(side*2.78,1.99,0),_wood_light)
		box(form, Vector3(.38,.30,.46),Vector3(side*2.78,2.67,0),_wood_light)
		for z in [-.205,.205]:
			box(form,Vector3(.38,.36,.05),Vector3(side*2.78,2.34,z),_wood_light)
	else:
		box(form,Vector3(.38,.96,.46),Vector3(side*2.78,2.30,0),_wood_light)
	# Narrow darker end-grain accent, outside the receiving hole.
	box(form,Vector3(.39,.025,.46),Vector3(side*2.78,2.825,0),_endgrain)

func _build_extension(host: Node3D, direction: float) -> void:
	var form := Node3D.new()
	host.add_child(form)
	form.rotation.y = PI if direction < 0 else 0.0
	_prism_z(form,PackedVector2Array([Vector2(-.405,.215),Vector2(.405,.215),Vector2(.237,.705),Vector2(-.237,.705)]),3.52,4.45,_wood_light)
	box(form,Vector3(1.10,.72,.95),Vector3(0,.36,4.925),_wood_light)

func _build_beam(host: Node3D, station: float) -> void:
	# Uniform section can slide through BOTH enclosed mortises; no large shoulders.
	box(host,Vector3(6.32,.26,.30),Vector3(0,2.34,station),_wood)
	for x in [-3.17,3.17]:
		box(host,Vector3(.016,.26,.30),Vector3(x,2.34,station),_endgrain)
	box(host,Vector3(6.25,.005,.009),Vector3(0,2.473,station-.08),_wood_light)

func box(host: Node3D, dimensions: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = center
	instance.material_override = material
	host.add_child(instance)
	return instance

func _prism_z(host: Node3D, polygon: PackedVector2Array, z_min: float, z_max: float, material: Material) -> void:
	# Triangulating the polygon keeps curved ribs and dovetail voids genuinely open.
	# Triangulate_polygon returns CCW cap triangles for either input winding.
	# The side strip needs a CW boundary for Godot's clockwise outside faces;
	# normalize a private copy so mirroring X cannot turn only the sides inward.
	polygon = polygon.duplicate()
	if not Geometry2D.is_polygon_clockwise(polygon): polygon.reverse()
	var indices := Geometry2D.triangulate_polygon(polygon)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in range(0,indices.size(),3):
		for side in [0,1]:
			var order := [0,1,2] if side == 0 else [2,1,0]
			for corner in order:
				var point: Vector2 = polygon[indices[i+corner]]
				surface.add_vertex(Vector3(point.x,point.y,z_min if side == 0 else z_max))
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		for vertex in [Vector3(a.x,a.y,z_min),Vector3(b.x,b.y,z_min),Vector3(b.x,b.y,z_max),Vector3(a.x,a.y,z_min),Vector3(b.x,b.y,z_max),Vector3(a.x,a.y,z_max)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	host.add_child(instance)

