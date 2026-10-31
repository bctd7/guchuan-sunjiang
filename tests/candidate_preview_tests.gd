extends SceneTree
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
const Preview = preload("res://levels/level01/candidate_preview.gd")
const TypeGallery = preload("res://levels/level01/type_gallery.gd")
const LengthGallery = preload("res://levels/level01/length_candidate_gallery.gd")
const Lengths = preload("res://models/ship/keel/length_geometry.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func snapshot(node: Node) -> Array:
	var result: Array = [node.name,node.get_meta_list()]
	for key in node.get_meta_list(): result.append(node.get_meta(key))
	if node is Node3D: result.append([node.transform,node.visible])
	if node is MeshInstance3D:
		result.append([node.mesh,node.mesh.get_faces(),node.material_override])
		if node.material_override is StandardMaterial3D:
			result.append([node.material_override.albedo_color,node.material_override.transparency,node.material_override.cull_mode])
	for child in node.get_children(): result.append(snapshot(child))
	return result

func mesh_volume(mesh: Mesh) -> float:
	var faces := mesh.get_faces()
	var result := 0.0
	for i in range(0,faces.size(),3): result += faces[i].dot(faces[i+1].cross(faces[i+2]))/6.0
	return result

func validate_wood(node: Node) -> void:
	if node is MeshInstance3D:
		check(node.mesh != null,"Mesh retained")
		var material := node.material_override as StandardMaterial3D
		check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(material.albedo_color.a,1.0),"Opaque private wooden material")
		if node.mesh is ArrayMesh:
			check(mesh_volume(node.mesh) < -.0000001,"Closed stock has clockwise outward winding")
	for child in node.get_children(): validate_wood(child)

func run() -> void:
	var source = load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(source)
	await process_frame
	var type_gallery := TypeGallery.new()
	var length_gallery := LengthGallery.new()
	root.add_child(type_gallery)
	root.add_child(length_gallery)
	type_gallery.size = Vector2(1200,174)
	length_gallery.size = Vector2(320,224)
	for id in ["rib_l1","rib_r1","rib_l2","rib_r3","bow","stern","beam1","beam3"]:
		var original: Node3D = source.pieces[id]
		var unchanged := snapshot(original)
		for length in ["short","correct","long"]:
			var clone := original.duplicate() as Node3D
			Lengths.apply(clone,id,length)
			var before := snapshot(clone)
			Candidate.apply(clone,id,Lengths.kind(id),source)
			check(snapshot(clone) == before,"Correct candidate exact no-op after length: "+id+length)
			clone.free()
		for kind in ["blind_tenon","dovetail","through_tenon"]:
			type_gallery.configure(source,id)
			type_gallery.set_selected("")
			check(type_gallery.buttons.size() == 3,"Three visible type choices")
			for button in type_gallery.buttons.values(): check(not button.button_pressed,"Type starts unselected")
			var preview: SubViewportContainer = type_gallery.previews[kind]
			check(preview.custom_minimum_size.y >= 130,"Type preview large enough")
			var specimen: Node3D = preview.specimen
			check(specimen.get_child_count() >= original.get_child_count(),"Complete source hierarchy retained")
			check(specimen.visible and specimen.scale.is_equal_approx(Vector3.ONE),"Actual wood retains physical scale")
			check(specimen.get_parent() == preview.viewport,"Full specimen lives in candidate viewport")
			validate_wood(specimen)
			await process_frame
			check(preview.size.y >= 130.0 and preview.size.x >= 250.0,"Type projection has a large visible canvas")
			check(preview.camera.size <= 1.4,"Camera remains close enough to read end shape")
			length_gallery.configure(source,id,kind)
			length_gallery.set_selected("")
			var spans: Array[float] = []
			for length in LengthGallery.ORDER:
				var lp = length_gallery.previews[length]
				var wood: Node3D = lp.specimen
				var tip: MeshInstance3D
				if id.begins_with("rib_"): tip = wood.find_child("RootTenon",true,false)
				elif id in ["bow","stern"]: tip = wood.get_child(0).get_child(0)
				else: tip = wood.get_child(0)
				spans.append(tip.mesh.get_aabb().size.x if id.begins_with("rib_") or id.begins_with("beam") else tip.mesh.get_aabb().size.z)
				check(not length_gallery.buttons[length].button_pressed,"Length starts unselected")
				check(length_gallery.buttons[length].get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,"Whole row remains a button")
				check(wood.has_meta("length_geometry"),"Physical length metadata retained")
				await process_frame
				check(length_gallery.buttons[length].get_global_rect().size.x >= 300.0,"Length button spans whole row")
				check(lp.camera.size*lp.size.x/lp.size.y >= (7.5 if id.begins_with("beam") else 2.5),"All lengths share enough projection width")
				validate_wood(wood)
			check(spans[0] > spans[2] and spans[2] > spans[1],"All three real lengths differ: "+id+kind)
		length_gallery.configure(source,id,"")
		for length in LengthGallery.ORDER:
			check(not length_gallery.buttons[length].button_pressed,"Physical reference never preselects a length answer")
			check(str(length_gallery.viewports[length].get_meta("comparison_kind")).is_empty(),"No default type hidden in reference metadata")
		Candidate.apply(original,id,"dovetail",source)
		check(snapshot(original) == unchanged,"Source meshes/materials/metadata/pose untouched: "+id)
	# Validate the actual generated normals as well as closure/volume, both axes.
	for direction in [-1.0,1.0]:
		var dovetail := Candidate._dovetail_x(.62,.27,.22,.48,direction)
		check(mesh_volume(dovetail) < 0.0,"Dovetail outside winding")
		var arrays := dovetail.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			check(vertices[index].dot(normals[index]) > 0.0,"Dovetail generated normals face out")
		check(Preview.outward_mesh(dovetail) == dovetail,"Correct winding needs no replacement")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3.ZERO,Vector3.RIGHT,Vector3.UP]: surface.add_vertex(point)
	surface.generate_normals()
	var open_mesh := surface.commit()
	check(Preview.outward_mesh(open_mesh) == open_mesh,"Open surface left untouched")
	type_gallery.free()
	length_gallery.free()
	source.free()
	print("CANDIDATE_PREVIEW: ",passed," passed; ",failed," failed")
	quit(1 if failed else 0)
