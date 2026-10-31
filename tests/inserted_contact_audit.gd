extends SceneTree
## Geometric diagnostics only; independent of native mouse validation.
var cases: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh and node.is_visible_in_tree():output.append(node)
	for child in node.get_children():meshes(child,output)
func inside_mesh(point: Vector3, faces: PackedVector3Array) -> bool:
	var direction:=Vector3(.371,.619,.829).normalized()
	var distances: Array[float]=[]
	for i in range(0,faces.size(),3):
		var hit=Geometry3D.ray_intersects_triangle(point,direction,faces[i],faces[i+1],faces[i+2])
		if hit==null:continue
		var distance: float=(hit-point).length()
		if distance<.002:return false
		var duplicate:=false
		for old in distances:if absf(old-distance)<.0005:duplicate=true;break
		if not duplicate:distances.append(distance)
	return distances.size()%2==1
func audit(inspector: Node) -> Array[Dictionary]:
	var stock: Array[MeshInstance3D]=[]
	meshes(inspector.animated_piece,stock)
	var hits: Array[Dictionary]=[]
	for id in inspector.pieces:
		if id==inspector.animated_piece_id:continue
		var receivers: Array[MeshInstance3D]=[]
		meshes(inspector.pieces[id],receivers)
		for receiver in receivers:
			var inner: AABB=receiver.mesh.get_aabb().grow(-.002)
			if not inner.has_volume():continue
			var target_faces: PackedVector3Array=receiver.mesh.get_faces()
			for item in stock:
				var transform: Transform3D=receiver.global_transform.affine_inverse()*item.global_transform
				var points:=PackedVector3Array()
				for vertex in item.mesh.get_faces():points.append(transform*vertex)
				var bounds:=AABB(points[0],Vector3.ZERO)
				for point in points:bounds=bounds.expand(point)
				if not bounds.intersection(inner).has_volume():continue
				var found:=false
				if receiver.mesh is BoxMesh:
					for i in range(0,points.size(),3):
						for edge in 3:
							var a:=points[i+edge];var b:=points[i+(edge+1)%3]
							if inner.has_point(a) or inner.intersects_segment(a,b):found=true;break
						if found:break
				else:
					for point in points:
						if inner.has_point(point) and inside_mesh(point,target_faces):found=true;break
				if found:hits.append({"receiver":id+"/"+str(inspector.pieces[id].get_path_to(receiver)),"stock":str(inspector.animated_piece.get_path_to(item)),"test":"edge/inner-box" if receiver.mesh is BoxMesh else "vertex/closed-mesh-ray"})
	return hits
func run() -> void:
	var source=load("res://levels/level01/skeleton_view.gd").new();root.add_child(source)
	var inspector=load("res://levels/level01/joint_inspector.gd").new();root.add_child(inspector);inspector.configure(source)
	await process_frame
	var count:=0
	var path_cases: Array[Dictionary]=[]
	for id in ["rib_l1","bow","beam1"]:
		for kind in ["blind_tenon","dovetail","through_tenon"]:
			for length in ["short","correct","long"]:
				inspector.show_connection(id,length,false,kind,true)
				var hits:=audit(inspector)
				cases.append({"socket":id,"kind":kind,"length":length,"contacts":hits,"reliefs":inspector.animated_piece.get_meta("trial_receiver_reliefs",0)})
				count+=hits.size()
				var final: Transform3D=source.trial_pose(id,length,kind)
				var entry: Transform3D=inspector._safe_trial_entry(final)
				# Removable pins are hidden during real dragging/replay; including
				# seated pins in path diagnostics creates impossible false positives.
				var fasteners=inspector.animated_piece.get_node_or_null("LengthFasteners")
				if fasteners:fasteners.hide()
				for progress in [0.0,.05,.1,.15,.3,.5,.75,.9,.95]:
					inspector.animated_piece.transform=entry.interpolate_with(final,progress)
					var path_hits:=audit(inspector)
					if not path_hits.is_empty():path_cases.append({"socket":id,"kind":kind,"length":length,"progress":progress,"contacts":path_hits})
				inspector.animated_piece.transform=final
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/contact-audit/"))
	FileAccess.open("res://tests/evidence/contact-audit/report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"suspected_penetrations":count,"path_suspects":path_cases,"method":"Final and nine insertion samples of visible stock/receiver meshes, with removable pins hidden during motion. Box inner-volume edge checks; non-box receiver point-in-solid rays. Diagnostic program geometry, not visual or native input acceptance."},"  "))
	print("CONTACT_AUDIT cases=",cases.size()," final suspected mesh pairs=",count," path suspect samples=",path_cases.size())
	inspector.free();source.free();quit(0)
