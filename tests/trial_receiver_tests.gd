extends SceneTree
const Relief=preload("res://models/ship/keel/trial_receiver.gd")
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func snapshot(node: Node) -> Array:
	var data: Array=[]
	if node is Node3D:data.append([node.transform,node.visible])
	if node is MeshInstance3D:data.append(node.mesh.get_faces())
	for child in node.get_children():data.append(snapshot(child))
	return data
func run() -> void:
	var solid:=AABB(Vector3(-2,-2,-2),Vector3(4,4,4))
	for cut in [AABB(Vector3(-1,-1,-1),Vector3(2,2,2)),AABB(Vector3(-2,-1,-1),Vector3(2,3,3)),solid]:
		var pieces:=Relief.subtract_box(solid,cut)
		var volume: float=cut.get_volume()
		for i in pieces.size():
			volume+=pieces[i].get_volume()
			check(not pieces[i].intersection(cut).has_volume(),"closed relief blocks exclude receiving void")
			for j in range(i):check(not pieces[i].intersection(pieces[j]).has_volume(),"relief blocks do not overlap each other")
		check(is_equal_approx(volume,solid.get_volume()),"subtraction preserves all wood outside void")
	var source=load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(source)
	var inspector=load("res://levels/level01/joint_inspector.gd").new()
	root.add_child(inspector)
	inspector.configure(source)
	await process_frame
	var baseline:=snapshot(source)
	for id in ["rib_l1","bow","beam1"]:
		for joint in ["blind_tenon","dovetail","through_tenon"]:
			for length in ["short","correct","long"]:
				inspector.show_connection(id,length,false,joint,true)
				check(snapshot(source)==baseline,"source geometry untouched "+id+joint+length)
				if id=="bow" and joint=="through_tenon":
					check(inspector.animated_piece.get_meta("trial_receiver_reliefs",0)>0,"deep wrong stock has a local receiving relief "+length)
					var stock: Node3D=inspector.animated_piece
					var tip: MeshInstance3D=stock.get_node(stock.get_meta("candidate_tip_path"))
					var boxes: Array[MeshInstance3D]=[]
					Relief._collect_boxes(inspector.pieces.keel,boxes)
					for box in boxes:
						var bounds: AABB=tip.mesh.get_aabb()
						var transform: Transform3D=box.global_transform.affine_inverse()*tip.global_transform
						var tip_bounds:=AABB(transform*bounds.position,Vector3.ZERO)
						for index in 8:tip_bounds=tip_bounds.expand(transform*bounds.get_endpoint(index))
						check(not box.mesh.get_aabb().intersection(tip_bounds).has_volume(),"end receiver has no box volume inside wrong stock "+length)
				if joint==inspector.joint_id_for(id):
					check(not inspector.animated_piece.has_meta("trial_receiver_reliefs"),"matching type keeps original receiver "+id+length)
				inspector.show_connection(id,length,false,joint)
				check(snapshot(source)==baseline,"take-back source preserved "+id+joint+length)
				for part in inspector.pieces.values():check(part.find_children("TrialRelief*","MeshInstance3D",true,false).is_empty(),"selection restores real target void")
	inspector.free()
	source.free()
	print("TRIAL_RECEIVER ",passed," passed; ",failed," failed")
	quit(0 if failed==0 else 1)
