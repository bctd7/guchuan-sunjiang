extends RefCounted
## Opaque cutaway on close-up clones, rather than translucent wood over stock.
const Relief=preload("res://levels/level01/trial_receiver.gd")
static func restore(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("section_segment"):
			node.remove_child(child);child.queue_free()
		else:
			if child.has_meta("section_original"):
				child.show();child.remove_meta("section_original")
			restore(child)
static func collect(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh and node.is_visible_in_tree():output.append(node)
	for child in node.get_children():collect(child,output)
static func bounds_in(mesh: MeshInstance3D, transform: Transform3D) -> AABB:
	var source: AABB=mesh.mesh.get_aabb()
	var result:=AABB(transform*source.position,Vector3.ZERO)
	for index in 8:result=result.expand(transform*source.get_endpoint(index))
	return result
static func apply(id: String, receiver: Node3D, stock: Node3D, final_pose: Transform3D, tip: MeshInstance3D, camera: Camera3D) -> void:
	var items: Array[MeshInstance3D]=[]
	collect(receiver,items)
	if id.begins_with("beam"):
		var station: float=-2.7 if id=="beam1" else 2.7
		var front: float=signf(camera.position.z-station)
		for mesh in items:
			var bounds:=bounds_in(mesh,mesh.global_transform)
			var center:=bounds.get_center()
			if bounds.size.z<.055 and absf(center.y-2.34)<.23 and (center.z-station)*front>.17 and absf(center.z-station)<.24:
				mesh.set_meta("section_original",true);mesh.hide()
		return
	if id not in ["bow","stern"]:return
	var end_sign: float=-1 if id=="bow" else 1
	var depth:=1.0
	if is_instance_valid(tip):depth=maxf(depth,tip.mesh.get_aabb().size.z+.15)
	var low: float=-4.55 if id=="bow" else 4.45-depth
	var window:=AABB(Vector3(-.6,.51,low),Vector3(1.2,.7,depth+.1))
	var camera_side: float=signf(camera.position.x)
	for mesh in items:
		var bounds:=bounds_in(mesh,mesh.global_transform)
		var center:=bounds.get_center()
		if mesh.mesh is ArrayMesh and absf(center.z-end_sign*3.975)<.6 and center.x*camera_side>.1:
			mesh.set_meta("section_original",true);mesh.hide()
		elif mesh.mesh is BoxMesh:
			var inverse:=mesh.global_transform.affine_inverse()
			var cut:=AABB(inverse*window.position,Vector3.ZERO)
			for index in 8:cut=cut.expand(inverse*window.get_endpoint(index))
			var overlap: AABB=mesh.mesh.get_aabb().intersection(cut)
			if not overlap.has_volume():continue
			for box in Relief.subtract_box(mesh.mesh.get_aabb(),overlap):
				var segment:=MeshInstance3D.new();segment.name="SectionRelief";segment.set_meta("section_segment",true)
				var shape:=BoxMesh.new();shape.size=box.size;segment.mesh=shape
				segment.transform=mesh.transform*Transform3D(Basis.IDENTITY,box.get_center())
				segment.material_override=mesh.material_override.duplicate() if mesh.material_override else null
				mesh.get_parent().add_child(segment)
			mesh.set_meta("section_original",true);mesh.hide()
