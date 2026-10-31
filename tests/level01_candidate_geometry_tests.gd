extends SceneTree
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
var failed := 0
var passed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func snapshot(node: Node) -> Array:
	var result: Array = []
	if node is Node3D: result.append([node.name,node.transform,node.visible])
	if node is MeshInstance3D: result.append([node.mesh,node.mesh.get_faces(),node.material_override])
	for child in node.get_children(): result.append(snapshot(child))
	return result

func run() -> void:
	var source = load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(source)
	await process_frame
	for id in ["rib_l1","rib_r1","rib_l2","rib_r3","bow","stern","beam1","beam3"]:
		var original: Node3D = source.pieces[id]
		var unchanged := snapshot(original)
		var expected := "blind_tenon" if id.begins_with("rib_") else ("through_tenon" if id.begins_with("beam") else "dovetail")
		for kind in ["", "blind_tenon", "dovetail", "through_tenon"]:
			var clone := original.duplicate() as Node3D
			root.add_child(clone)
			var before := snapshot(clone)
			var pose := clone.transform
			Candidate.apply(clone,id,kind,source)
			check(snapshot(original) == unchanged,"Source unchanged: "+id+kind)
			check(clone.transform == pose,"Root pose unchanged: "+id+kind)
			if kind == expected:
				check(snapshot(clone) == before,"Correct type exact no-op: "+id)
			elif kind.is_empty():
				var hidden: MeshInstance3D = clone.find_child("RootTenon",true,false) if id.begins_with("rib_") else (clone.find_child("CandidateTenon",true,false) if id.begins_with("beam") else clone.get_child(0).get_child(0))
				check(not hidden.visible,"Unset type has no default tip: "+id)
			else:
				var tip := clone.get_node(clone.get_meta("candidate_tip_path")) as MeshInstance3D
				check(tip.mesh.get_faces().size() >= 36,"Closed real 3D mesh: "+id+kind)
				check(tip.has_node("CandidateTipFocus"),"Tip focus marker: "+id+kind)
				var axis: Vector3 = clone.get_meta("candidate_axis")
				check(axis.is_equal_approx(-source.insertion_offset(id).normalized()),"Insertion axis matches source: "+id+kind)
				var bounds := tip.mesh.get_aabb()
				if id.begins_with("rib_"):
					var side := -1.0 if id.begins_with("rib_l") else 1.0
					check(is_equal_approx(tip.position.x+side*bounds.size.x/2.0,side*.55),"Rib shoulder retained: "+id+kind)
					check(is_equal_approx(tip.position.y,.38),"Rib tip height retained: "+id+kind)
					if kind == "through_tenon": check(is_equal_approx(bounds.size.x,1.18),"Through tip penetrates full keel width")
				if id in ["bow","stern"]:
					check(is_equal_approx(tip.position.z+bounds.size.z/2.0,4.45),"Extension shoulder retained")
					check(is_equal_approx(bounds.size.z,.44 if kind == "blind_tenon" else 1.48),"Blind/through depths differ")
				if kind == "dovetail":
					var head_width := 0.0
					var neck_width := 0.0
					for vertex in tip.mesh.get_faces():
						if vertex.x*axis.x > 0: head_width = maxf(head_width,absf(vertex.z)*2.0)
						else: neck_width = maxf(neck_width,absf(vertex.z)*2.0)
					check(head_width > neck_width*1.5,"Dovetail flares toward inserted head: "+id)
				if id.begins_with("beam"):
					check(is_equal_approx(tip.position.x+bounds.size.x/2.0,-2.59),"Beam reduced tip meets shoulder")
			clone.free()
		Candidate.apply(original,id,"",source)
		check(snapshot(original) == unchanged,"Guard rejects source mutation: "+id)
	for length in ["short","correct","long"]:
		var clone: Node3D = source.pieces.rib_l1.duplicate()
		root.add_child(clone)
		source.apply_length_geometry(clone,"rib_l1",length)
		var span: float = clone.find_child("RootTenon",true,false).mesh.size.x
		Candidate.apply(clone,"rib_l1","dovetail",source)
		check(is_equal_approx(clone.find_child("RootTenon",true,false).mesh.get_aabb().size.x,span),"Dovetail respects chosen length: "+length)
		clone.free()
	var gallery = load("res://levels/level01/type_gallery.gd").new()
	root.add_child(gallery)
	for id in ["rib_l1","rib_r1","bow","stern","beam1"]:
		gallery.configure(source,id)
		check(gallery.buttons.size() == 3,"All three choices visible before selection: "+id)
		for kind in gallery.viewports:
			var viewport: SubViewport = gallery.viewports[kind]
			var specimen := viewport.get_node("CandidateSpecimen") as Node3D
			check(specimen.visible and specimen.get_child_count()>0,"Gallery keeps actual timber shoulder and tenon: "+id+kind)
			check(specimen.scale.is_equal_approx(Vector3.ONE),"Gallery retains physical scale: "+id+kind)
			check(viewport.get_node("SpecimenCamera").size>0,"Gallery has physical near-joint framing: "+id+kind)
	if DisplayServer.get_name() != "headless":
		source.hide()
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(1000,200)
		gallery.size = Vector2(1000,160)
		gallery.configure(source,"rib_r1")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/27902/Documents/Codex/2026-10-27/task/evidence/type_gallery.png")
	gallery.free()
	print("CANDIDATE_GEOMETRY: ",passed," passed; ",failed," failed")
	source.free()
	quit(1 if failed else 0)
