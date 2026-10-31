extends SceneTree
const Trial = preload("res://levels/level01/trial_fit.gd")
const Lengths = preload("res://levels/level01/length_geometry.gd")
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func snapshot(node: Node) -> Array:
	var result: Array=[]
	if node is Node3D: result.append([node.transform,node.visible])
	if node is MeshInstance3D:
		var material:=node.material_override as StandardMaterial3D
		result.append([node.mesh.get_faces(),material.albedo_color if material else Color.WHITE,material.roughness if material else 0.0,material.albedo_texture if material else null])
	for child in node.get_children(): result.append(snapshot(child))
	return result

func faces(node: Node3D, parent_pose := Transform3D.IDENTITY) -> PackedVector3Array:
	var result:=PackedVector3Array()
	if not node.visible: return result
	var pose: Transform3D=parent_pose*node.transform
	if node is MeshInstance3D:
		for vertex in node.mesh.get_faces(): result.append(pose*vertex)
	for child in node.get_children():
		if child is Node3D: result.append_array(faces(child,pose))
	return result

func path_clear(stock: PackedVector3Array, vertices: PackedVector3Array, offset: Vector3) -> bool:
	for vertex in vertices:
		for i in range(0,stock.size(),3):
			var hit: Variant=Geometry3D.segment_intersects_triangle(vertex+offset,vertex,stock[i],stock[i+1],stock[i+2])
			if hit != null and (hit as Vector3).distance_to(vertex)>.0001 and (hit as Vector3).distance_to(vertex+offset)>.0001: return false
	return true

func within_clear(view: Node3D, part: Node3D) -> bool:
	var corners: Array[Vector3]=[]
	view._model_corners(part,part.transform,corners)
	var clear: Rect2=view.workshop_clear_rect().grow(1)
	for corner in corners:
		if not clear.has_point(view.camera.unproject_position(view.global_transform*corner)): return false
	return true

func run() -> void:
	root.size=Vector2i(1440,900)
	var view=load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(view)
	await process_frame
	check(Trial.is_stable("keel","correct","base"),"fixed foundation retains its base joint")
	var references: Dictionary={}
	for id in view.IDS:
		var baseline: Node3D=view.duplicate_part(id)
		references[id]=snapshot(baseline)
		baseline.free()
	var keel: Node3D=view.duplicate_part("keel")
	var keel_faces:=faces(keel)
	keel.free()
	for id in view.IDS:
		if id == "keel": continue
		var receivers:=keel_faces
		if id.begins_with("beam"):
			receivers=PackedVector3Array()
			for side in ["l","r"]:
				var rib: Node3D=view.duplicate_part("rib_"+side+("1" if id=="beam1" else "3"))
				receivers.append_array(faces(rib))
				rib.free()
		for length in ["short","correct","long"]:
			for joint in ["blind_tenon","dovetail","through_tenon"]:
				var label: String=id+"/"+joint+"/"+length
				var part: Node3D=view.pieces[id]
				view.apply_fit_geometry(part,id,joint,length)
				var expected: Node3D=view.duplicate_part(id)
				Lengths.apply(expected,id,length)
				Candidate.apply(expected,id,joint,view)
				part.transform=Transform3D.IDENTITY
				part.show()
				expected.show()
				check(snapshot(part)==snapshot(expected),"actual selected shape retained "+label)
				var first_child: Node=part.get_child(0)
				view.apply_fit_geometry(part,id,joint,length)
				check(first_child==part.get_child(0),"refresh reuses geometry "+label)
				var fresh: Node3D=view.duplicate_part(id)
				check(snapshot(fresh)==references[id],"immutable baseline survives selected geometry "+label)
				fresh.free()
				expected.transform=view.trial_pose(id,length,joint)
				if joint==Lengths.kind(id):
					check(path_clear(receivers,faces(expected),view.trial_entry_offset(id,length,joint)),"correct geometry path clears receiving stock "+label)
				else:
					check(expected.transform==Lengths.seated_pose(id,length),"wrong shape reaches actual assembled location rather than outside clearance "+label)
				check(Trial.is_stable(id,length,joint)==(joint==Lengths.kind(id) and length=="correct"),"stability requires matching shape and length "+label)
				if joint==Lengths.kind(id):
					check(view.trial_pose(id,length,joint)==view.final_pose(id,length),"correct shape preserves all old length poses "+label)
					check(view.trial_entry_offset(id,length,joint)==view.insertion_offset(id),"correct shape preserves old entry offset "+label)
				expected.free()
				# Exercise the actual world tween, sampling its geometry through the camera.
				view.show_automatic_overview([id],length,joint)
				view.prepare_place(id,length,joint)
				check(not part.visible and part.position.is_equal_approx(view.trial_pose(id,length,joint).origin+view.trial_entry_offset(id,length,joint)),"prepared entry is hidden and complete "+label)
				view.animate_place(id,length,joint)
				var tween: Tween=view.animations[id]
				var contained:=true
				for frame in 36:
					contained=contained and within_clear(view,part)
					tween.custom_step(.05)
				check(contained,"whole trial start, intermediate and end geometry fit clear camera area "+label)
				check(part.transform.is_equal_approx(view.trial_pose(id,length,joint)),"actual tween reaches safe trial pose "+label)
				if id.begins_with("beam") and joint!=Lengths.kind(id): check(not part.get_node("LengthFasteners").visible,"wrong beam never locks fasteners "+label)
				view.sync_state({"keel":{"joint":"","length":"correct"},id:{"joint":joint,"length":length}},"ribs","")
				check(part.transform.is_equal_approx(view.trial_pose(id,length,joint)),"state refresh retains trial pose "+label)
				if not Trial.is_stable(id,length,joint):
					var base: Transform3D=view.trial_pose(id,length,joint)
					var instability: Tween=view.show_instability({id:{"joint":joint,"length":length}})
					instability.custom_step(.15)
					check((part.position-base.origin).dot(view.trial_entry_offset(id,length,joint))>0,"unstable selected joint loosens only outward "+label)
					instability.custom_step(1.10)
					check(part.transform.is_equal_approx(base),"instability returns to safe contact pose "+label)
		# Restoring expected geometry must remove stale paths and wrong tips.
		view.apply_fit_geometry(view.pieces[id],id,Lengths.kind(id),"correct")
		check(not view.pieces[id].has_meta("candidate_tip_path") and not view.pieces[id].has_meta("candidate_axis"),"correction removes wrong-shape metadata "+id)
		check(view.pieces[id].find_child("CandidateTenon",true,false)==null,"correction removes wrong-shape child "+id)
	# A correct candidate always starts from baseline, even while the installed
	# source currently carries a different shape. This is the top-gallery path.
	var preview=load("res://levels/level01/candidate_preview.gd").new()
	root.add_child(preview)
	for id in ["rib_l1","bow","beam1"]:
		var wrong := "dovetail" if id != "bow" else "blind_tenon"
		view.apply_fit_geometry(view.pieces[id],id,wrong,"long")
		var source_snapshot:=snapshot(view.pieces[id])
		preview.configure(view,id,Lengths.kind(id),"correct")
		check(snapshot(view.pieces[id])==source_snapshot,"correct preview does not mutate installed wrong source "+id)
		var specimen: Node3D=preview.specimen
		check(not specimen.has_meta("candidate_tip_path") and specimen.find_child("CandidateTenon",true,false)==null,"correct top-gallery starts with clean baseline "+id)
		var tip: MeshInstance3D=specimen.find_child("RootTenon",true,false) if id.begins_with("rib_") else (specimen.get_child(0).get_child(0) if id=="bow" else specimen.get_child(0))
		var size: float=tip.mesh.get_aabb().size.z if id=="bow" else tip.mesh.get_aabb().size.x
		check(is_equal_approx(size,Lengths.span(id,"correct")),"correct preview restores original physical span "+id)
	preview.free()
	# Removing the level from a campaign keeps construction originals available.
	root.remove_child(view)
	root.add_child(view)
	var detached_clone: Node3D=view.duplicate_part("rib_l1")
	check(snapshot(detached_clone)==references.rib_l1,"campaign detach and reattach retains baseline")
	detached_clone.free()
	view.cancel_animations()
	view.free()
	print("TRIAL_FIT_GEOMETRY: ",passed," passed; ",failed," failed")
	quit(1 if failed else 0)
