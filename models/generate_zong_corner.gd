extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func recipe_mesh(data: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for triangle in data.triangles:
		for index in triangle:
			var v: Array = data.vertices[int(index)]
			vertices.append(Vector3(v[0],v[1],v[2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func run() -> void:
	var base := "res://models/assets/"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty(): base = arguments[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/zong_corner_solids.json"))
	for id in recipe:
		var solid := CSGCombiner3D.new()
		root.add_child(solid)
		for instruction in recipe[id]:
			var piece := CSGMesh3D.new()
			piece.mesh = recipe_mesh(instruction[1])
			piece.operation = CSGShape3D.OPERATION_SUBTRACTION if instruction[0] == "subtract" else CSGShape3D.OPERATION_UNION
			solid.add_child(piece)
		await process_frame
		await process_frame
		var mesh := solid.bake_static_mesh()
		assert(mesh != null and mesh.get_surface_count() > 0, "CSG must produce a solid")
		var faces := mesh.get_faces()
		var volume := 0.0
		for i in range(0,faces.size(),3): volume += faces[i].dot(faces[i+1].cross(faces[i+2])) / 6.0
		var output := FileAccess.open(base + "zong_corner_" + str(id) + ".obj",FileAccess.WRITE)
		output.store_line("# Refined teaching zong corner; Godot CSG baked static solid; Y up")
		output.store_line("s off")
		for vertex in faces: output.store_line("v %.8f %.8f %.8f" % [vertex.x,vertex.y,vertex.z])
		# Explicit hard face normals keep the mortise rims legible. Do not smooth
		# the sloped shoulder and the cavity wall into one apparent broad face.
		for i in range(0,faces.size(),3):
			var normal := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			if volume < 0: normal = -normal
			output.store_line("vn %.8f %.8f %.8f" % [normal.x,normal.y,normal.z])
		for i in range(0,faces.size(),3):
			var n := i/3+1
			output.store_line("f %d//%d %d//%d %d//%d" % [i+1,n,i+2 if volume > 0 else i+3,n,i+3 if volume > 0 else i+2,n])
		output.close()
		print("BAKED ",id," triangles=",faces.size()/3," volume=",absf(volume))
		solid.free()
	quit()
