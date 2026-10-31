extends SceneTree
## Verify the two real display paths, original geometry and mutable X-ray alpha.
const Assembly = preload("res://core/assembly.gd")
const Look = preload("res://classroom/display/workshop_look.gd")
const Preview = preload("res://classroom/display/lesson_model_preview.gd")
var passed := 0
var failed := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func run() -> void:
	var assembly := Assembly.new()
	root.add_child(assembly)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	var count := 0
	for definition in catalog:
		assembly.load_definition(definition)
		var preview := Preview.new()
		root.add_child(preview)
		preview.configure(str(definition.id))
		var original: Dictionary = {}
		for id in assembly.parts:
			var part: Node3D = assembly.parts[id]
			var visual: MeshInstance3D = part.get_node("Wood")
			original[id] = [part.transform, visual.mesh, part.get_child(1).shape, assembly.states[id]]
		Look.apply_materials(assembly)
		assembly.set_xray(true)
		Look.apply_materials(assembly)
		for id in assembly.parts:
			var material: StandardMaterial3D = assembly.parts[id].get_node("Wood").material_override
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and is_equal_approx(material.albedo_color.a, .25), str(definition.id)+" translucent section retained "+id)
		assembly.set_xray(false)
		for id in assembly.parts:
			count += 1
			var visual: MeshInstance3D = assembly.parts[id].get_node("Wood")
			var material: StandardMaterial3D = visual.material_override
			var thumbnail: StandardMaterial3D = preview.mesh_nodes[id].material_override
			check(material.albedo_texture != null and material.uv1_triplanar and not material.uv1_world_triplanar, "local UV-independent grain "+id)
			check(material.albedo_texture == thumbnail.albedo_texture and material.albedo_color == thumbnail.albedo_color and material.uv1_scale == thumbnail.uv1_scale and material.roughness == thumbnail.roughness, "classroom and preview timber match "+id)
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(material.albedo_color.a, 1.0), "closing section restores solid timber "+id)
			check(visual.mesh == preview.mesh_nodes[id].mesh, "classroom and preview share repaired display normals " + id)
			var arrays := visual.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var flat := true
			for face in range(0, normals.size(), 3):
				flat = flat and normals[face].is_equal_approx(normals[face+1]) and normals[face].is_equal_approx(normals[face+2])
			check(visual.mesh.get_aabb() == original[id][1].get_aabb(), "exact imported bounds preserved " + id)
			check(flat, "stock corners stay crisp " + id)
			check(assembly.parts[id].transform == original[id][0] and visual.mesh.get_faces() == original[id][1].get_faces() and Look.source_mesh(visual.mesh) == original[id][1] and assembly.parts[id].get_child(1).shape == original[id][2] and assembly.states[id] == original[id][3], "styling leaves physical model unchanged "+id)
		for spec in definition.parts:
			if spec.get("fixed", false): continue
			var id := str(spec.id)
			check(assembly.set_part_pose(id, assembly.entrance_pose(id)), "styled model approach " + id)
			check(assembly.begin_insertion(id), "styled model guide " + id)
			check(assembly.advance_insertion(id, assembly.path_length(id)), "styled model full insertion " + id)
			check(assembly.states[id] == "locked", "styled model locks " + id)
		preview.free()
	check(catalog.size() == 9 and count == 21, "all nine variants and 21 pieces covered")
	assembly.free()
	print("WOOD_MATERIAL ", passed, " passed; ", failed, " failed")
	quit(0 if failed == 0 else 1)
