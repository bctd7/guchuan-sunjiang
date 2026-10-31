extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func verify(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		push_error(label)
func meshes(node: Node, list: Array) -> void:
	if node is MeshInstance3D: list.append(node)
	for child in node.get_children(): meshes(child,list)
func same_vertices(a: PackedVector3Array,b: PackedVector3Array) -> bool:
	if a.size()!=b.size(): return false
	var left: Array[String]=[]
	var right: Array[String]=[]
	for point in a: left.append(str(point))
	for point in b: right.append(str(point))
	left.sort()
	right.sort()
	return left==right

func run() -> void:
	root.size=Vector2i(1440,900)
	var source=load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(source)
	var inspector=load("res://levels/level01/joint_inspector.gd").new()
	root.add_child(inspector)
	inspector.configure(source)
	await process_frame
	for id in ["rib_l1","rib_r2","bow","stern","beam1","beam3"]:
		var expected: String="blind_tenon" if id.begins_with("rib_") else ("through_tenon" if id.begins_with("beam") else "dovetail")
		inspector.show_connection(id,"correct",false,expected)
		verify(not inspector.animated_piece.position.is_zero_approx(),"inspection opens separated real joint "+id)
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/level01"))
			root.get_texture().get_image().save_png("res://tests/evidence/level01/ship-separated-"+id+".png")
		inspector.show_connection(id,"correct",true,expected)
		verify(inspector.opened,"open real ship connection "+id)
		if id.begins_with("rib_"):
			verify(inspector.animated_piece.transform.origin.is_equal_approx(source.insertion_offset(id)),"same rib insertion offset "+id)
		else:
			var outward: Vector3=source.insertion_offset(id).normalized()
			verify((inspector._tip_front()-inspector._entry_mouth()).dot(outward)>=.749,"actual leading head starts visibly outside the mouth "+id)
		var originals: Array=[]
		var copies: Array=[]
		meshes(source.pieces[id],originals)
		meshes(inspector.pieces[id],copies)
		var same: bool=originals.size()==copies.size()
		for i in originals.size():
			var matching_mesh: bool=same_vertices(originals[i].mesh.get_faces(),copies[i].mesh.get_faces())
			same=same and matching_mesh and originals[i].transform==copies[i].transform
		verify(same,"same actual meshes and local geometry "+id)
		verify(originals[0].material_override!=copies[0].material_override,"independent display materials "+id)
		var initial: Transform3D=inspector.animated_piece.transform
		await create_timer(0.7).timeout
		verify(not initial.is_equal_approx(inspector.animated_piece.transform),"continuous motion "+id)
		var deadline := Time.get_ticks_msec()+7000
		while inspector.is_animating and Time.get_ticks_msec()<deadline:
			await process_frame
		verify(inspector.animation_finished,"animation finished "+id)
		verify(inspector.animated_piece.transform.is_equal_approx(source.final_pose(id)),"same final ship pose "+id)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/level01"))
			root.get_texture().get_image().save_png("res://tests/evidence/level01/ship-closeup-"+id+".png")
		inspector.xray_button.set_pressed(true)
		verify(inspector.xray_button.button_pressed,"xray accessible "+id)
		if DisplayServer.get_name() != "headless" and id == "rib_l1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/evidence/level01/ship-cutaway-rib_l1.png")
		inspector.close()
		verify(not inspector.opened and not inspector.visible,"close "+id)
	inspector.show_connection("rib_l1","",false,"")
	verify(inspector.selected_joint.is_empty() and inspector.selected_length.is_empty(),"no implied selected type or length")
	verify(inspector.candidate_panel.visible and inspector.length_buttons.size()==3,"all three length options visible without a default")
	for length_button in inspector.length_buttons.values(): verify(not length_button.button_pressed,"neutral length button is unselected")
	verify(inspector.joint_choices.viewports.size()==3,"three real candidate meshes precede choice")
	verify(inspector.animated_piece.find_child("RootTenon",true,false).visible and not inspector.orbit.assembly_enabled,"unchosen real reference stays visible without enabling assembly")
	var shapes: Array[String]=[]
	for kind in ["blind_tenon","dovetail","through_tenon"]:
		inspector.joint_buttons[kind].pressed.emit()
		verify(inspector.selected_joint==kind and inspector.selected_length.is_empty(),"type selection does not supply a length: "+kind)
		verify(inspector.candidate_panel.visible,"length ruler remains visible for every type: "+kind)
		inspector.length_buttons["correct"].pressed.emit()
		var tip: MeshInstance3D=inspector.animated_piece.get_node_or_null(inspector.animated_piece.get_meta("candidate_tip_path")) if inspector.animated_piece.has_meta("candidate_tip_path") else inspector.animated_piece.find_child("RootTenon",true,false)
		shapes.append(str(tip.mesh.get_faces()))
		verify(tip.visible,"selected candidate actually visible: "+kind)
		inspector.xray_button.set_pressed(true)
		verify(tip.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and tip.material_override.albedo_color.a==1.0,"candidate remains opaque in cutaway: "+kind)
		verify(inspector.pieces.keel.find_child("BlindSlotWeb",true,false).material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"actual blind bottom stays solid in cutaway")
		inspector.show_connection("rib_l1","",false,kind)
	verify(shapes[0]!=shapes[1] and shapes[0]!=shapes[2] and shapes[1]!=shapes[2],"half and through are genuinely different geometries")
	var length_events: Array[String]=[]
	inspector.length_chosen.connect(func(id: String): length_events.append(id))
	for id in ["rib_l1","bow","beam1"]:
		var kind: String=source.Rules.expected_joint(id)
		inspector.show_connection(id)
		verify(inspector.selected_joint.is_empty() and inspector.selected_length.is_empty(),"default invocation supplies neither answer "+id)
		inspector.joint_buttons[kind].pressed.emit()
		var signatures: Array[String]=[]
		for length in ["long","short","correct"]:
			inspector.length_buttons[length].pressed.emit()
			verify(inspector.selected_length==length and inspector.selected_joint==kind,"length choice preserves type "+id+"/"+length)
			verify(inspector.comparison.selected_length==length and inspector.comparison.piece_id==id and inspector.comparison.pixel_scale>0,"shared ruler tracks piece and selection "+id+"/"+length)
			verify(length_events.back()==length,"length emits controller signal "+id+"/"+length)
			verify(is_equal_approx(float(inspector.animated_piece.get_meta("length_geometry").span),source.Lengths.span(id,length)),"measured candidate uses actual length geometry "+id+"/"+length)
			var candidate_meshes: Array=[]
			meshes(inspector.animated_piece,candidate_meshes)
			var shape:=""
			for visual in candidate_meshes: shape+=str(visual.mesh.get_faces())
			signatures.append(shape)
			var chosen_pose: Transform3D=inspector.animated_piece.transform
			inspector.replay_button.pressed.emit()
			verify(inspector.selected_length==length and inspector.selected_joint==kind and inspector.animated_piece.transform.is_equal_approx(chosen_pose),"replay preserves both choices and separated pose "+id+"/"+length)
		verify(signatures[0]!=signatures[1] and signatures[0]!=signatures[2] and signatures[1]!=signatures[2],"all three lengths have different actual meshes "+id)
		inspector.show_connection(id,"long",true,kind)
		await create_timer(3.0).timeout
		verify(inspector.animation_finished and inspector.animated_piece.transform.is_equal_approx(source.final_pose(id,"long")),"long piece animates to legal seated pose "+id)
		verify(inspector.animated_piece.basis.is_equal_approx(Basis.IDENTITY),"long seating retains unrotated joint axes "+id)
		verify(not inspector.candidate_panel.visible,"post-placement review hides choice controls "+id)
	inspector.close()
	var f=FileAccess.open("res://tests/level01_inspector_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"failed":failed,"method":"headless source mesh topology, source insertion offset and length-specific final pose; no rendered visual claim"},"\t"))
	print("INSPECTOR: %d passed, %d failed" % [passed,failed])
	inspector.free()
	source.free()
	quit(0 if failed==0 else 1)
