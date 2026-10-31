extends RefCounted
## Preview-only edits. Call once on a fresh clone after apply_length_geometry.
## The accepted type is deliberately an exact no-op, including resources/pose.

static func apply(part: Node3D, piece_id: String, joint_type: String, source_view: Node3D) -> void:
	if not is_instance_valid(part) or not is_instance_valid(source_view): return
	if source_view.pieces.values().has(part): return
	var expected := "blind_tenon" if piece_id.begins_with("rib_") else ("through_tenon" if piece_id.begins_with("beam") else "dovetail")
	if piece_id == "keel" or joint_type == expected: return
	if joint_type not in ["", "blind_tenon", "through_tenon", "dovetail"]: return
	var tip: MeshInstance3D
	var axis := Vector3.ZERO
	if piece_id.begins_with("rib_"):
		tip = part.find_child("RootTenon", true, false) as MeshInstance3D
		if tip == null: return
		var side := -1.0 if piece_id.begins_with("rib_l") else 1.0
		axis = Vector3(-side,0,0)
		var original_span: float = tip.mesh.get_aabb().size.x
		var span := original_span * (1.18/.42 if joint_type == "through_tenon" else 1.0)
		tip.position = Vector3(side*(.55-span/2.0),.38,0)
		tip.mesh = _dovetail_x(span,.27,.22,.48,-side) if joint_type == "dovetail" else _box(Vector3(span,.27,.30))
	elif piece_id in ["bow", "stern"]:
		var form := part.get_child(0) as Node3D
		tip = form.get_child(0) as MeshInstance3D
		var nominal_ratio := 1.0
		if part.has_meta("length_geometry"):
			nominal_ratio = float(part.get_meta("length_geometry").span)/.93
		var span := (.44 if joint_type in ["", "blind_tenon"] else 1.48)*nominal_ratio
		tip.mesh = _box(Vector3(.46,.36,span))
		tip.position = Vector3(0,.46,4.45-span/2.0)
		axis = Vector3(0,0,1 if piece_id == "bow" else -1)
	elif piece_id.begins_with("beam"):
		# Insertion is toward -X. Keep the body and expose a reduced leading tip.
		var body := part.get_child(0) as MeshInstance3D
		var station := body.position.z
		var half_span := body.mesh.get_aabb().size.x*.5
		var shoulder := -half_span+.57
		body.mesh = _box(Vector3(half_span-shoulder,.26,.30))
		body.position.x = (half_span+shoulder)/2.0
		for i in range(1,part.get_child_count()):
			var child := part.get_child(i) as MeshInstance3D
			if child == null: continue
			if child.position.x < 0: child.hide()
			elif child.mesh is BoxMesh and child.mesh.size.x > 5.0:
				child.mesh = _box(Vector3(half_span-.04-shoulder,.005,.009))
				child.position.x = (half_span-.04+shoulder)/2.0
		var span := .38 if joint_type in ["", "blind_tenon"] else .64
		tip = MeshInstance3D.new()
		tip.name = "CandidateTenon"
		tip.material_override = body.material_override
		tip.mesh = _dovetail_x(span,.19,.16,.38,-1.0) if joint_type == "dovetail" else _box(Vector3(span,.18,.20))
		tip.position = Vector3(shoulder-span/2.0,2.34,station)
		part.add_child(tip)
		axis = Vector3.LEFT
	else: return
	if joint_type.is_empty():
		tip.hide()
		return
	var focus := Marker3D.new()
	focus.name = "CandidateTipFocus"
	tip.add_child(focus)
	part.set_meta("candidate_tip_path",part.get_path_to(tip))
	part.set_meta("candidate_axis",axis)

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _dovetail_x(span: float, height: float, neck: float, head: float, direction: float) -> ArrayMesh:
	# A genuine flared prism: shoulder neck and wider inserted head, both on X.
	var vertices: Array[Vector3] = []
	for x_end in [-1.0,1.0]:
		var width := head if x_end == direction else neck
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			vertices.append(Vector3(x_end*span/2.0,corner.x*height/2.0,corner.y*width/2.0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# Godot front faces are clockwise. Reverse every triangle, including caps,
	# so outside faces and generated normals describe opaque solid stock.
	for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for index in [0,2,1,0,3,2]: surface.add_vertex(vertices[face[index]])
	surface.generate_normals()
	return surface.commit()
