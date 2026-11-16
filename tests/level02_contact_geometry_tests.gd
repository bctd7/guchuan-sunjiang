extends SceneTree
const Contact=preload("res://levels/level02/trial_contact.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
var passed:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	if value:passed+=1
	else:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var fixture:=Node3D.new();var stock:=Node3D.new()
	G.prism(fixture,PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(.4,1),Vector2(.4,-.4),Vector2(-.4,-.4),Vector2(-.4,1),Vector2(-1,1)]),-.2,.2,null)
	G.box(stock,Vector3(.2,.2,.2),Vector3.ZERO,null)
	for rotation in [Basis.IDENTITY,Basis.from_euler(Vector3(.4,.7,-.3))]:
		var frame:=Transform3D(rotation,Vector3(3,2,1))
		var obstacles: Array=[]
		for part in Contact.meshes(fixture,frame):obstacles.append(Contact.box(part))
		check(Contact.clear(Contact.meshes(stock,frame),obstacles),"open concave pocket stays empty after parent rotation")
		var collision:=frame;collision.origin=frame*Vector3(.7,0,0)
		check(not Contact.clear(Contact.meshes(stock,collision),obstacles),"solid shoulder still blocks stock")
		# Nominal centre is empty, but an approach through the rear wall must stop.
		var stop:=Contact.blocked(stock,frame,rotation*Vector3(0,0,-1),obstacles)
		check(stop.clear and stop.distance>1.09 and stop.distance<1.11,"first wall blocks access to empty pocket behind it")
	fixture.free();stock.free()
	var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
	var heights: Dictionary={}
	for target in level.Rules.MANUAL_IDS:
		for option in ["A","B","C"]:
			level.state.reset()
			for id in level.Rules.IDS:
				level.state.select(id);level.state.observe();level.state.choose_joint(level.Rules.expected(id));level.state.choose_opening(option if id==target else level.state.Openings.target(id))
				if level.Rules.row_for(id)>0:level.state.choose_layout("B" if level.Rules.row_for(id)==1 else "A")
				if id==target:break
				level.state.attempt(id)
			check(level.view.installation_path_clear(target),"clear actual approach "+target+"/"+option)
			check(level.view.contact_failures.is_empty(),"contact and settle are clear "+target+"/"+option)
			if target=="cross_upper":
				check(level.view.poses[target].is_equal_approx(level.view.contact_poses[target]),"cross stays on its mating contact without secondary tipping "+option)
				check(absf(level.view.poses[target].origin.y-(1.31118 if option=="A" else 1.25))<.002 and level.view.poses[target].basis.is_equal_approx(Basis.IDENTITY),"shallow cross seats partially, wide/correct cross reaches the common notch floor "+option)
			if target in ["three_middle","three_upper","bulkhead"]:
				var height: float=level.view.contact_poses[target].origin.y
				heights[target+"/"+option]=height
				if option!=level.state.Openings.target(target):
					var expected: float=1.45 if target=="three_middle" else (1.6112 if target=="three_upper" else (.3462 if option=="B" else .4062))
					check(absf(height-expected)<.002,"wrong stock reaches real wall without convex-hull floating "+target+"/"+option)
	level.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"contact_heights":heights}
	FileAccess.open("res://tests/level02_contact_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CONTACT_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
