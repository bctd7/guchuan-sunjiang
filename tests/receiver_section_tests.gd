extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1;push_error(label)
func signature(node: Node) -> Array:
	var out: Array=[]
	if node is Node3D:out.append([node.transform,node.visible])
	if node is MeshInstance3D:out.append(node.mesh.get_faces())
	for child in node.get_children():out.append(signature(child))
	return out
func inspect(node: Node, counts: Array[int]) -> void:
	if node.has_meta("section_original"):counts[0]+=1
	if node is MeshInstance3D and node.is_visible_in_tree():
		var material:=node.material_override as StandardMaterial3D
		check(material!=null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a==1.0,"section remains opaque wood")
	for child in node.get_children():inspect(child,counts)
func run() -> void:
	var source=load("res://levels/level01/skeleton_view.gd").new();root.add_child(source)
	var inspector=load("res://levels/level01/joint_inspector.gd").new();root.add_child(inspector);inspector.configure(source)
	await process_frame
	var original:=signature(source)
	for id in ["bow","beam1"]:
		for kind in ["blind_tenon","dovetail","through_tenon"]:
			for length in ["short","correct","long"]:
				inspector.show_connection(id,length,false,kind,true)
				var baseline:=signature(inspector.world)
				for repeat in 2:
					inspector.xray_button.set_pressed(true)
					var counts: Array[int]=[0]
					for part in inspector.pieces.values():inspect(part,counts)
					check(counts[0]>0,"section opens receiver cheek or roof "+id+kind+length)
					inspector.xray_button.set_pressed(false)
					check(signature(inspector.world)==baseline,"closing section restores exact trial view "+id+kind+length)
				check(signature(source)==original,"section leaves source geometry untouched")
	inspector.free();source.free()
	print("RECEIVER_SECTION ",passed," passed; ",failed," failed")
	quit(0 if failed==0 else 1)
