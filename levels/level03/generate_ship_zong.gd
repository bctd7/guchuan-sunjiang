extends SceneTree
## Build NEW ship-frame solids from the published convex/cut parameter recipe.
## No teaching OBJ is loaded or modified. The stock dimensions are ship-specific
## before CSG union/subtraction, and only level03/assets is written.
func _initialize() -> void: call_deferred("run")
func recipe_mesh(data: Dictionary, id: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for triangle in data.triangles:
		for index in triangle:
			var v: Array = data.vertices[int(index)]
			var point := Vector3(v[0],v[1],v[2])
			if id == "xrail" and point.x > 1.01: point.x = 1.0+(point.x-1.0)*1.7
			if id == "zrail" and point.z > 1.01: point.z = 1.0+(point.z-1.0)*1.7
			if id == "leg" and point.y < -.5: point.y = -.5+(point.y+.5)*1.15
			vertices.append(point)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func run() -> void:
	var folder := "res://levels/level03/assets/"
	DirAccess.make_dir_recursive_absolute(folder)
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/zong_corner_solids.json"))
	for id in ["xrail","zrail","leg"]:
		var solid := CSGCombiner3D.new()
		root.add_child(solid)
		for instruction in recipe[id]:
			var shape := CSGMesh3D.new()
			shape.mesh = recipe_mesh(instruction[1],id)
			shape.operation = CSGShape3D.OPERATION_SUBTRACTION if instruction[0] == "subtract" else CSGShape3D.OPERATION_UNION
			solid.add_child(shape)
		await process_frame
		await process_frame
		var mesh := solid.bake_static_mesh()
		assert(mesh != null and mesh.get_surface_count()>0)
		var faces := mesh.get_faces()
		var volume := 0.0
		for i in range(0,faces.size(),3): volume += faces[i].dot(faces[i+1].cross(faces[i+2]))/6.0
		var file := FileAccess.open(folder+"ship_mastframe_"+id+".obj",FileAccess.WRITE)
		file.store_line("# NEW level03 ship mast-frame stock; convex recipe -> independent CSG bake; Y up")
		file.store_line("# frame arms 4.4; corner leg bottom -2.225; join shoulders unchanged")
		file.store_line("s off")
		for vertex in faces: file.store_line("v %.8f %.8f %.8f" % [vertex.x,vertex.y,vertex.z])
		for i in range(0,faces.size(),3):
			var normal := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			if volume < 0: normal = -normal
			file.store_line("vn %.8f %.8f %.8f" % [normal.x,normal.y,normal.z])
		for i in range(0,faces.size(),3):
			var n := i/3+1
			file.store_line("f %d//%d %d//%d %d//%d" % [i+1,n,i+2 if volume>0 else i+3,n,i+3 if volume>0 else i+2,n])
		file.close()
		print("NEW SHIP STOCK ",id," triangles=",faces.size()/3," volume=",absf(volume))
		solid.free()
	quit()
