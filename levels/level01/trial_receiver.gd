extends RefCounted
## Private close-up receiver relief for deliberately incompatible trial stock.
## Observation/source geometry and the recorded choice are never changed.

static func apply(receiver: Node3D, stock: Node3D, final_pose: Transform3D, tip: MeshInstance3D, entry_pose: Variant = null) -> int:
	if not is_instance_valid(tip): return 0
	var tip_in_stock: Transform3D=stock.global_transform.affine_inverse()*tip.global_transform
	var final_tip: Transform3D=stock.get_parent().global_transform*final_pose*tip_in_stock
	var entry_tip: Transform3D=stock.get_parent().global_transform*entry_pose*tip_in_stock if entry_pose is Transform3D else final_tip
	var meshes: Array[MeshInstance3D]=[]
	_collect_boxes(receiver,meshes)
	var count:=0
	for mesh in meshes:
		var to_mesh: Transform3D=mesh.global_transform.affine_inverse()*final_tip
		var bounds: AABB=tip.mesh.get_aabb()
		var cut:=AABB(to_mesh*bounds.position,Vector3.ZERO)
		for index in 8: cut=cut.expand(to_mesh*bounds.get_endpoint(index))
		var entry_in_mesh: Transform3D=mesh.global_transform.affine_inverse()*entry_tip
		for index in 8:cut=cut.expand(entry_in_mesh*bounds.get_endpoint(index))
		# The leading head also crosses earlier receivers (notably the first
		# crossbeam mortise). Clear its whole swept envelope, not only its seat.
		var direction: Vector3=entry_in_mesh.origin-to_mesh.origin
		var margin: Vector3=direction.normalized().abs()*.055+Vector3.ONE*.01 if direction.length()>.001 else Vector3.ONE*.065
		cut.position-=margin
		cut.size+=margin*2
		var solid: AABB=mesh.mesh.get_aabb()
		var overlap:=solid.intersection(cut)
		if not overlap.has_volume(): continue
		var pieces:=subtract_box(solid,overlap)
		for piece in pieces:
			var segment:=MeshInstance3D.new()
			segment.name="TrialRelief"
			segment.set_meta("trial_relief_segment",true)
			var box:=BoxMesh.new()
			box.size=piece.size
			segment.mesh=box
			segment.transform=mesh.transform*Transform3D(Basis.IDENTITY,piece.get_center())
			segment.material_override=mesh.material_override.duplicate() if mesh.material_override else null
			mesh.get_parent().add_child(segment)
		# Keep this private original for inspection/debugging; retry rebuilds a
		# fresh clone, so there is no persistent or cumulative receiver edit.
		mesh.hide()
		mesh.set_meta("trial_relief_original",true)
		count+=1
	return count

static func restore(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("trial_relief_segment"):
			node.remove_child(child)
			child.queue_free()
		else:
			if child.has_meta("trial_relief_original"):
				child.show()
				child.remove_meta("trial_relief_original")
			restore(child)

static func _collect_boxes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh and node.visible:
		output.append(node)
	for child in node.get_children(): _collect_boxes(child,output)

static func subtract_box(solid: AABB, cut: AABB) -> Array[AABB]:
	var result: Array[AABB]=[]
	var low:=solid.position
	var high:=solid.end
	var a:=cut.position
	var b:=cut.end
	# Six non-overlapping, closed rectangular volumes surround the local void.
	_append(result,low,Vector3(a.x,high.y,high.z))
	_append(result,Vector3(b.x,low.y,low.z),high)
	_append(result,Vector3(a.x,low.y,low.z),Vector3(b.x,a.y,high.z))
	_append(result,Vector3(a.x,b.y,low.z),Vector3(b.x,high.y,high.z))
	_append(result,Vector3(a.x,a.y,low.z),Vector3(b.x,b.y,a.z))
	_append(result,Vector3(a.x,a.y,b.z),Vector3(b.x,b.y,high.z))
	return result

static func _append(output: Array[AABB], low: Vector3, high: Vector3) -> void:
	var bounds:=AABB(low,high-low)
	if bounds.size.x>.0001 and bounds.size.y>.0001 and bounds.size.z>.0001: output.append(bounds)
