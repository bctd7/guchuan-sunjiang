extends RefCounted
## Display-only ship copies and contact landmarks for the inspector.
## No UI, animation, input or accepted gameplay state is owned here.
const Lengths=preload("res://models/ship/keel/length_geometry.gd")
const CandidatePreview=preload("res://levels/level01/candidate_preview.gd")

static func create_parts(source_view: Node3D, world: Node3D, piece_id: String, length: String, joint_type: String, observation_mode: bool) -> Dictionary:
	var pieces: Dictionary = {}
	var ids: Array[String]=["keel",piece_id]
	if piece_id.begins_with("beam"):
		ids=["rib_l"+piece_id.right(1),"rib_r"+piece_id.right(1),piece_id]
	for id in ids:
		var copy: Node3D=source_view.duplicate_part(id) if id==piece_id else source_view.pieces[id].duplicate()
		copy.name="Closeup_"+id
		copy.transform=Transform3D.IDENTITY if id==piece_id else source_view.pieces[id].transform
		copy.visible=true
		clone_materials(copy)
		if id==piece_id:
			source_view.apply_fit_geometry(copy,id,joint_type,length if not length.is_empty() else "correct")
			if not observation_mode:copy.transform=source_view.trial_pose(id,length,joint_type)
		world.add_child(copy)
		pieces[id]=copy
	Lengths.set_fasteners_visible(pieces[piece_id],false)
	# Normalize display-only surface direction and opacity; source resources stay intact.
	for part in pieces.values(): CandidatePreview.solidify(part)
	return pieces

static func clone_materials(node: Node) -> void:
	if node is MeshInstance3D and node.material_override:
		node.material_override=node.material_override.duplicate()
	for child in node.get_children(): clone_materials(child)

static func set_transparent(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mat:=node.material_override as StandardMaterial3D
		if mat:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a=.24 if enabled else 1.0
	for child in node.get_children(): set_transparent(child,enabled)

static func receiver_tip(animated_piece: Node3D, animated_piece_id: String) -> MeshInstance3D:
	if animated_piece.has_meta("candidate_tip_path"):return animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	if animated_piece_id.begins_with("rib_"):return animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	return animated_piece.get_child(0).get_child(0) as MeshInstance3D if animated_piece_id in ["bow","stern"] else animated_piece.get_child(0) as MeshInstance3D

static func grab_point(animated_piece: Node3D, animated_piece_id: String, _length: String) -> Vector3:
	var tip: MeshInstance3D
	if animated_piece.has_meta("candidate_tip_path"):
		tip=animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	elif animated_piece_id.begins_with("rib_"):
		tip=animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	elif animated_piece_id in ["bow","stern"]:
		tip=animated_piece.get_child(0).get_child(0) as MeshInstance3D
	else:
		tip=animated_piece.get_child(0) as MeshInstance3D
	if tip==null: return Vector3.ZERO
	var point: Vector3=tip.mesh.get_aabb().get_center()
	if animated_piece_id.begins_with("beam") and not animated_piece.has_meta("candidate_tip_path"):
		point.x=-Lengths.span(animated_piece_id,_length)*.5+.2
	return animated_piece.to_local(tip.to_global(point))

static func tip_front(animated_piece: Node3D, animated_piece_id: String, source_view: Node3D, world: Node3D) -> Vector3:
	var tip: MeshInstance3D
	if animated_piece.has_meta("candidate_tip_path"):
		tip=animated_piece.get_node(animated_piece.get_meta("candidate_tip_path")) as MeshInstance3D
	elif animated_piece_id.begins_with("rib_"):
		tip=animated_piece.find_child("RootTenon",true,false) as MeshInstance3D
	else:
		tip=animated_piece.get_child(0).get_child(0) as MeshInstance3D if animated_piece_id in ["bow","stern"] else animated_piece.get_child(0) as MeshInstance3D
	var outward: Vector3=source_view.insertion_offset(animated_piece_id).normalized()
	var nearest:=INF
	var total:=Vector3.ZERO
	var count:=0
	for vertex in tip.mesh.get_faces():
		var point: Vector3=world.to_local(tip.to_global(vertex))
		var distance: float=point.dot(outward)
		if distance<nearest-.0001:
			nearest=distance
			total=point
			count=1
		elif absf(distance-nearest)<.0001:
			total+=point
			count+=1
	return total/maxi(count,1)

static func entry_mouth(animated_piece_id: String, source_view: Node3D) -> Vector3:
	var mouth: Vector3=source_view.connection_center(animated_piece_id)
	if animated_piece_id.begins_with("rib_"):mouth.x=-.55 if animated_piece_id.begins_with("rib_l") else .55
	elif animated_piece_id in ["bow","stern"]:mouth.z=-4.45 if animated_piece_id=="bow" else 4.45
	else:mouth.x=2.97
	return mouth

