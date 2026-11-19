extends "res://tests/zong_geometry_tests.gd"
func run() -> void:
	var guard = Guard.new()
	for id in ["xrail","zrail","leg"]:
		meshes[id] = load("res://models/joinery/assets/zong_corner_"+id+".obj")
		guard.register_mesh(id,meshes[id])
		check_topology(id)
	check(contains_point("leg",Vector3(.6,.9,.2)),"long vertical tenon reaches .92")
	check(contains_point("leg",Vector3(.2,.72,.6)),"short vertical tenon reaches .76 above old opening")
	check(not contains_point("leg",Vector3(.2,.8,.6)),"short tenon stays shorter than long")
	check(not contains_point("xrail",Vector3(.2,.88,.6)),"auxiliary horizontal rail tongue removed")
	check(contains_point("zrail",Vector3(.2,.88,.6)),"auxiliary matching slot filled with actual stock")
	check(contains_point("zrail",Vector3(.2,.70,.37)),"short-mortise FRONT wall is real solid")
	check(contains_point("zrail",Vector3(.2,.70,.87)),"short-mortise rear wall is real solid")
	check(contains_point("zrail",Vector3(.09,.70,.6)),"short-mortise left wall is real solid")
	check(contains_point("zrail",Vector3(.31,.70,.6)),"short-mortise right wall is real solid")
	check(not contains_point("zrail",Vector3(.2,.70,.6)),"short-mortise actual void preserved")
	var assembled := {"xrail":Transform3D.IDENTITY,"zrail":Transform3D.IDENTITY,"leg":Transform3D.IDENTITY}
	for pair in [["xrail","zrail"],["xrail","leg"],["zrail","leg"]]:
		var overlap: float = await intersection_volume(pair[0],Transform3D.IDENTITY,pair[1],Transform3D.IDENTITY)
		check(overlap<.000001,"full assembly independent CSG clear "+str(pair))
		intersections.append({"assembled_pair":pair,"volume":overlap})
	var positive: float = await intersection_volume("leg",Transform3D.IDENTITY,"leg",Transform3D.IDENTITY)
	check(positive>2.0,"CSG nonzero positive control")
	var parked := Transform3D(Basis.IDENTITY,Vector3(0,-1.6,0))
	check(guard.motion_is_safe("zrail",Transform3D(Basis.IDENTITY,Vector3(0,0,1.6)),Transform3D.IDENTITY,{"xrail":Transform3D.IDENTITY,"leg":parked}),"full continuous rail insertion while leg below")
	check(guard.motion_is_safe("leg",parked,Transform3D.IDENTITY,{"xrail":Transform3D.IDENTITY,"zrail":Transform3D.IDENTITY}),"full continuous vertical leg insertion into both bounded mortises")
	# Few independent CSG checkpoints supplement continuous tests; no global suite.
	for t in [.0,.5,1.0]:
		for stage in ["zrail","leg"]:
			var pose := Transform3D(Basis.IDENTITY,Vector3(0,0,1.6*(1-t)) if stage == "zrail" else Vector3(0,-1.6*(1-t),0))
			for fixed in ["xrail","leg"] if stage == "zrail" else ["xrail","zrail"]:
				var fp := parked if stage == "zrail" and fixed == "leg" else Transform3D.IDENTITY
				var volume: float = await intersection_volume(stage,pose,fixed,fp)
				check(volume<.000001,"assembly CSG checkpoint "+stage+" "+str(t)+" vs "+fixed)
	for entry in [["xrail",Vector3.RIGHT],["zrail",Vector3.BACK]]:
		var id: String = entry[0]
		var direction: Vector3 = entry[1]
		var end := Transform3D(Basis.IDENTITY,direction*.01998)
		check(guard.motion_is_safe(id,Transform3D.IDENTITY,end,assembled),id+" finite outward clearance safe")
		check(guard.motion_is_safe(id,end,Transform3D.IDENTITY,assembled),id+" rebound return range safe")
		check(not guard.motion_is_safe(id,Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,direction*.023),assembled),id+" real vertical-tenon wall blocks axial extraction")
		var collision: float = await intersection_volume(id,Transform3D(Basis.IDENTITY,direction*.023),"leg",Transform3D.IDENTITY)
		check(collision>.00001,id+" independent CSG confirms new axial stop")
		intersections.append({"outward":id,"beyond_stop_volume":collision,"safe_max":.01998})
	check(guard.motion_is_safe("leg",Transform3D.IDENTITY,parked,assembled),"vertical straight tenons still withdraw -Y before game locking")
	# Check actual assembly capture/guide/locking state without changing shared code.
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/zong_corner_definition.json"))
	var assembly = load("res://components/teaching/assembly/assembly.gd").new()
	root.add_child(assembly)
	assembly.load_definition(definition)
	check(assembly.candidate("leg").reason == "dependency","leg waits for joined horizontal frame")
	for id in ["zrail","leg"]:
		check(assembly.begin_manual(id),"start real guided capture "+id)
		check(assembly.is_guided(id),"guided state "+id)
		var first: float = assembly.path_length(id)*.45
		check(assembly.advance_insertion(id,first),"partial guided insertion "+id)
		check(assembly.states[id] == "guided","partial insertion does not auto lock "+id)
		check(assembly.advance_insertion(id,-first),"partial guided withdrawal "+id)
		check(assembly.states[id] == "free","full guided withdrawal returns free state "+id)
		check(assembly.begin_manual(id),"recapture withdrawn member "+id)
		check(assembly.advance_insertion(id,assembly.path_length(id)),"complete safe guide "+id)
		check(assembly.states[id] == "locked" and assembly.parts[id].transform.is_equal_approx(Transform3D.IDENTITY),"final lock at actual assembled pose "+id)
		check(not assembly.remove_part(id),"permanent game lock retained separately from physical straight-tenon exit "+id)
	assembly.free()
	var result := {"passed":passed,"failed":failed,"intersections":intersections}
	FileAccess.open("res://.zong-extra-tongue-removal-20261023/model-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("REFERENCE ZONG MODEL: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)
