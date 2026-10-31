extends SceneTree
const Assembly = preload("res://core/assembly.gd")
const Presenter = preload("res://classroom/science/presenter.gd")
const Guard = preload("res://core/mesh_collision_guard.gd")
const Geometry = preload("res://classroom/science/contact_geometry.gd")
var failures := 0
var assertions := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var assembly := Assembly.new()
	root.add_child(assembly)
	var presenter := Presenter.new()
	root.add_child(presenter)
	presenter.configure(assembly)
	check(not presenter.enabled,"default collapsed/off")
	var panel: Control = presenter.create_panel()
	root.add_child(panel)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	check(catalog.size()==9 and presenter.profiles.size()==9,"all nine profiles")
	for joint in catalog:
		assembly.load_definition(joint)
		for profile in presenter.profiles[joint.id]:
			assembly.reset()
			assembly.select_part(profile.part)
			presenter.set_enabled(true)
			check(not presenter.seated,joint.id+" separated hides force/motion")
			for spec in profile.faces:
				var vertices := Geometry.extract(assembly.parts[profile.part].get_node("Wood").mesh,spec)
				print("PATCH ",joint.id,"/",profile.part," ",spec.label," triangles=",vertices.size()/3)
				check(vertices.size()>0,joint.id+" "+profile.part+" grounded mesh patch")
				var normal := Geometry.vector(spec.normal).normalized()
				var point := Geometry.vector(spec.point)
				for index in range(0,vertices.size(),3):
					var center: Vector3 = (vertices[index]+vertices[index+1]+vertices[index+2])/3.0
					check(has_opposing_surface(assembly,profile.part,center,normal,profile.get("required_neighbors",[])),joint.id+" "+profile.part+" candidate has nearby opposing mesh surface")
				for v in vertices: check(absf(normal.dot(v-normal*0.003-point))<0.00051,"patch remains original face plane")
			for id in assembly.parts: assembly.parts[id].transform = assembly.assembled_pose(id)
			var before: Dictionary = {}
			for id in assembly.parts: before[id] = assembly.parts[id].transform
			var states: Dictionary = assembly.states.duplicate(true)
			assembly.changed.emit()
			check(presenter.removal_blocked == (joint.id == "three_way_lap" and profile.part == "middle"),"stacked middle withdrawal conditional")
			check(presenter.seated,joint.id+" assembled pose recognized")
			# Contact support is independent of the gameplay insertion dependency graph.
			for neighbor in profile.get("required_neighbors",[]):
				var original: Transform3D = assembly.parts[neighbor].transform
				assembly.parts[neighbor].position += Vector3(0,-2,0)
				assembly.changed.emit()
				check(not presenter.seated,joint.id+" missing contact neighbor hides arrows: "+neighbor)
				check(presenter.patch_triangles>0,"separated contact neighbor retains candidate faces")
				assembly.parts[neighbor].transform = original
				assembly.changed.emit()
				check(presenter.seated,"restoring contact neighbor restores arrows")
			if joint.id == "zong_corner":
				check(profile.required_neighbors == ["leg"],"zong shoulders require current leg")
				check(assembly.specs.xrail.fixed,"fixed gameplay reference is preserved")
				var guard := Guard.new()
				var obstacles := {}
				for id in assembly.parts:
					guard.register_mesh(id,assembly.parts[id].get_node("Wood").mesh)
					if id != profile.part: obstacles[id] = assembly.assembled_pose(id)
				for distance in [0.1,1.2]:
					check(guard.motion_is_safe(profile.part,Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3.UP*distance),obstacles),"current rail +Y withdrawal clears both other meshes")
				check(not guard.motion_is_safe(profile.part,Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3.DOWN*0.1),obstacles),"current rail -Y is blocked after shoulder clearance closes")
			check(presenter.patch_triangles>0,joint.id+" visible original faces")
			for case in range(2):
				presenter.set_case(case)
				check(presenter.visuals.get_child_count()>0,"case visuals")
				for layer in ["force","contact","motion"]:
					presenter.set_layer(layer,false)
					presenter.set_layer(layer,true)
			for id in assembly.parts: check(before[id].is_equal_approx(assembly.parts[id].transform),"read-only transforms")
			check(states==assembly.states,"read-only gameplay states")
			check(presenter.summary().contains("交互规则"),"lock disclaimer")
			check(presenter.summary().contains("不是九种古船"),"archaeology disclaimer")
			assembly.global_position = Vector3(2,3,4)
			presenter.refresh()
			check(presenter.global_transform.is_equal_approx(assembly.global_transform),"assembly coordinate mapping")
			assembly.global_position = Vector3.ZERO
			presenter.set_enabled(false)
			check(presenter.visuals.get_child_count()==0,"disabled clears overlays")
	panel.queue_free()
	presenter.queue_free()
	assembly.queue_free()
	await process_frame
	print("EDUCATION: ",assertions," assertions; ",failures," failures")
	quit(1 if failures else 0)

func has_opposing_surface(assembly: Node3D, moving: String, center: Vector3, direction: Vector3, required: Array = []) -> bool:
	for id in assembly.parts:
		if id == moving or (not required.is_empty() and id not in required): continue
		var mesh: Mesh = assembly.parts[id].get_node("Wood").mesh
		var faces := mesh.get_faces()
		for i in range(0,faces.size(),3):
			var hit = Geometry3D.ray_intersects_triangle(center-direction*0.004,direction,faces[i],faces[i+1],faces[i+2])
			if hit != null and center.distance_to(hit)<0.065: return true
	return false
