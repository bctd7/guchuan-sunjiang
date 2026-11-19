extends "res://components/preview/rotatable_preview.gd"
## Keel-specific geometry and framing, using the common viewport lifecycle.
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
const Lengths = preload("res://models/ship/keel/length_geometry.gd")
var specimen: Node3D

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	super._ready()
	viewport.name = "CandidateViewport"

func configure(source: Node3D, piece_id: String, kind: String, length: String = "correct", compare_lengths: bool = false) -> void:
	if not is_instance_valid(source) or not source.pieces.has(piece_id): return
	var stock_length := length if not length.is_empty() else "correct"
	var key := "%s:%s:%s" % [piece_id, kind, stock_length]
	specimen = source.candidate_variants.instantiate(key, _build_specimen.bind(source, piece_id, kind, stock_length))
	replace_model(specimen)
	_frame_joint(piece_id,compare_lengths)
	viewport.set_meta("comparison_kind",kind)

func _build_specimen(source: Node3D, piece_id: String, kind: String, length: String) -> Node3D:
	var stock: Node3D = source.duplicate_part(piece_id)
	stock.name = "CandidateSpecimen"
	stock.transform = Transform3D.IDENTITY
	stock.visible = true
	Lengths.apply(stock, piece_id, length)
	if not kind.is_empty():
		Candidate.apply(stock, piece_id, kind, source)
	solidify(stock)
	return stock

static func solidify(node: Node) -> void:
	# Intended only for disposable clones, never the source ship.
	if node is MeshInstance3D:
		if node.mesh is ArrayMesh: node.mesh = outward_mesh(node.mesh)
		if node.material_override is StandardMaterial3D:
			var material := node.material_override.duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			material.albedo_color.a = 1.0
			material.cull_mode = BaseMaterial3D.CULL_BACK
			node.material_override = material
	for child in node.get_children(): solidify(child)

static func outward_mesh(mesh: ArrayMesh) -> ArrayMesh:
	# Only a closed, consistently oriented manifold can be reversed as a whole.
	# Undirected even edge counts also admit mixed cap/side winding and duplicated
	# surfaces; their signed volume cannot diagnose a safe whole-mesh repair.
	# Godot clockwise outside faces have negative volume.
	var faces := PackedVector3Array()
	for surface_index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES: return mesh
		# Inspect rendered vertices, not get_faces()'s snapped collision cache.
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty(): faces.append_array(vertices)
		else:
			if indices.size()%3 != 0: return mesh
			for index in indices: faces.append(vertices[index])
	if faces.is_empty() or faces.size()%3 != 0: return mesh
	var edges: Dictionary = {}
	var volume := 0.0
	for i in range(0,faces.size(),3):
		if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared() < 1e-12: return mesh
		volume += faces[i].dot(faces[i+1].cross(faces[i+2]))
		for corner in 3:
			var a: Vector3 = faces[i+corner].snapped(Vector3.ONE*.00001)
			var b: Vector3 = faces[i+(corner+1)%3].snapped(Vector3.ONE*.00001)
			var key := str(a)+"/"+str(b) if str(a) < str(b) else str(b)+"/"+str(a)
			if a == b: return mesh
			var use: Vector2i = edges.get(key,Vector2i.ZERO)
			edges[key] = use+Vector2i(1,1 if str(a) < str(b) else -1)
	for use: Vector2i in edges.values():
		if use.x != 2 or use.y != 0: return mesh
	if volume <= .000001: return mesh
	var result := ArrayMesh.new()
	for surface_index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES: return mesh
		var arrays := mesh.surface_get_arrays(surface_index).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for i in range(0,indices.size(),3):
			var temporary := indices[i+1]
			indices[i+1] = indices[i+2]
			indices[i+2] = temporary
		arrays[Mesh.ARRAY_INDEX] = indices
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in normals.size(): normals[i] = -normals[i]
		arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(mesh.surface_get_primitive_type(surface_index),arrays)
		result.surface_set_material(surface_index,mesh.surface_get_material(surface_index))
	return result

func _install_default_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("fff7e9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fffaf0")
	environment.ambient_light_energy = .48
	world.environment = environment
	lighting.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-30,0)
	light.light_energy = .95
	lighting.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,145,0)
	fill.light_energy = .30
	lighting.add_child(fill)

func _frame_joint(piece_id: String, compare_lengths: bool) -> void:
	var target := Vector3.ZERO
	var direction := Vector3(2.0,2.6,3.8)
	var frame_height := 1.08
	if piece_id.begins_with("rib_"):
		var side := -1.0 if piece_id.begins_with("rib_l") else 1.0
		var tip := specimen.find_child("RootTenon",true,false) as MeshInstance3D
		var shoulder := tip.global_position + Vector3(side*tip.mesh.get_aabb().size.x*.5,0,0)
		target = shoulder + Vector3(-side*.12,.04,0)
		direction.x = -side*2.0
		frame_height = .85
		_width = 2.6 if compare_lengths else 2.3
	elif piece_id in ["bow","stern"]:
		var form := specimen.get_child(0) as Node3D
		target = form.to_global(Vector3(0,.43,4.25))
		direction = form.basis*Vector3(2.5,1.4,-3.8)
		frame_height = 1.32
		_width = 2.7
	elif piece_id.begins_with("beam"):
		var body := specimen.get_child(0) as MeshInstance3D
		if compare_lengths:
			target = body.global_position
			direction = Vector3(.3,1.6,5.0)
			frame_height = .65
			_width = 7.65
		else:
			var left := body.global_position.x-body.mesh.get_aabb().size.x*.5
			var tip := specimen.find_child("CandidateTenon",true,false) as MeshInstance3D
			if tip != null: left = tip.global_position.x-tip.mesh.get_aabb().size.x*.5
			target = Vector3(left+.58,body.global_position.y,body.global_position.z)
			direction = Vector3(-2.0,1.35,3.8)
			frame_height = .96
			_width = 1.9
	camera.name = "SpecimenCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = frame_height
	_height = frame_height
	camera.near = .01
	camera.far = 100.0
	var elevation:=asin(direction.normalized().y)
	orbit.yaw_limit=PI;orbit.pitch_min=elevation-deg_to_rad(75);orbit.pitch_max=elevation+deg_to_rad(75)
	zoom_factor=1.0;orbit.configure(camera,target,direction.normalized()*8.0,true)
	camera.current = true
	_fit()
	viewport.set_meta("focus",target)

func _fit() -> void:
	if not is_instance_valid(camera): return
	var aspect := maxf(size.x,120.0)/maxf(size.y,66.0)
	camera.size = maxf(_height,_width/aspect)*zoom_factor
	request_frame()
