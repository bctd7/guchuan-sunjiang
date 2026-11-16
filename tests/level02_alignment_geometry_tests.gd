extends SceneTree
## Independent model-axis and pocket-position checks; never calls assembly_alignment.
const Probe=preload("res://tests/stock_clearance.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
var passed:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func feature(id: String,opening: String,layout: String,detail: bool,openings,rules) -> Vector3:
	var shift: float=openings.offset(id,opening)
	if id.begins_with("plank"):
		var row: int=0 if detail else rules.row_for(id)
		var seam: float=rules.seam(layout)
		return Vector3(0 if detail else ((-4+seam)*.5 if id.ends_with("a") else (seam+4)*.5),shift,row*.78+.05)
	if id.begins_with("three"):
		if id=="three_middle":return Vector3.ZERO
		var angle: float=0.0 if id=="three_middle" else -PI/3
		return Vector3(cos(angle)*shift,-.08 if id=="three_middle" else -.04,sin(angle)*shift)
	return Vector3(0,-.06,shift)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
	var cases:=0;var openings=level.state.Openings;var rules=level.Rules
	for target in rules.IDS:
		level.state.reset()
		for previous in rules.IDS:
			if previous==target:break
			level.state.select(previous);level.state.observe();level.state.choose_joint(rules.expected(previous));level.state.choose_opening(openings.target(previous))
			if rules.row_for(previous)>0:level.state.choose_layout("B" if rules.row_for(previous)==1 else "A")
			level.state.attempt(previous)
		level.state.select(target);level.state.observe()
		if rules.row_for(target)>0:level.state.choose_layout("B" if rules.row_for(target)==1 else "A")
		var layout: String=level.state.layout if not level.state.layout.is_empty() else "A"
		var canonical: String=openings.target(target)
		var entry: Vector3=level.view.panel_transform().basis.z if rules.row_for(target)>=0 else (Vector3.RIGHT if target=="three_middle" else Vector3.UP)
		var axis:=Vector3.RIGHT if rules.row_for(target)>=0 else Vector3(0,0,1)
		var nominal: Transform3D=level.view.panel_transform() if rules.row_for(target)>=0 else Transform3D(Basis.IDENTITY,Vector3(-2.8,1.25,0) if target=="cross_upper" else Vector3(0,.285,0))
		if target.begins_with("three"):
			var angle: float=0.0 if target=="three_middle" else -PI/3
			axis=Vector3(cos(angle),0,sin(angle));nominal.origin=Vector3(2.5,1.45,0)-axis*openings.offset(target,canonical)
			if target=="three_middle":axis=Vector3.FORWARD
		if rules.row_for(target)>=0:axis=level.view.panel_transform().basis.x
		var socket: Vector3=nominal*feature(target,canonical,layout,false,openings,rules)
		var camera_before: Transform3D=level.view.camera.transform
		for kind in rules.JOINT_NAMES:
			level.state.choose_joint(kind)
			for option in openings.OPTIONS:
				level.state.choose_opening(option)
				var geometry: String=level.view.opening_geometry_id(target)
				var model: Node3D=level.view.pieces[target] if geometry==target else level.view.pieces[target].get_child(0)
				var own_axis:=Vector3.RIGHT if geometry.begins_with("plank") else Vector3(0,0,1)
				var mouth:=Vector3(0,0,-1) if geometry.begins_with("plank") else Vector3.DOWN
				if geometry.begins_with("three"):
					var angle: float=0.0 if geometry=="three_middle" else -PI/3
					own_axis=Vector3(cos(angle),0,sin(angle))
					if geometry=="three_middle":own_axis=Vector3.FORWARD;mouth=Vector3.LEFT
				if rules.row_for(target)==0 and geometry!=target:
					# The displayed stock is still separated. Validate its seated geometry
					# using the actual contact transform, and check separation independently.
					var seated: Transform3D=level.view.global_transform*level.view.contact_poses[target]*model.transform
					check((model.global_position-seated.origin).is_equal_approx(level.view.global_basis*level.view.preview_offset(target)),"uninstalled stock remains separated along its actual entry direction")
					var x: float=-1.55 if target.ends_with("a") else 1.05
					check(absf(model.global_position.x-x)<.0001,"first-row stock targets the fixed housing, not an arbitrary board midpoint")
					if kind=="cross_lap":
						check((model.global_basis*Vector3.BACK).dot(Vector3.BACK)>.9999,"cross member is perpendicular to the longitudinal rail")
						check((model.global_basis*Vector3.DOWN).dot(Vector3.DOWN)>.9999 and seated.origin.y>.25 and seated.origin.y<.33,"half-depth cross cut descends into the real horizontal seat")
					else:
						check((model.global_basis*Vector3.RIGHT).dot(Vector3.BACK)>.9999,"three-member slider enters lengthwise instead of dropping")
						check(absf(seated.origin.y-.303)<.0001 and seated.origin.z>.36 and seated.origin.z<.8,"slider enters the housing and meets its actual shoulder")
					check(level.state.can_attempt(target).ok and not level.state.checked,"all direct choices stay trial-installable")
					check(level.view.camera.transform==camera_before,"first-row orientation is physical, not a camera trick")
					cases+=1
					continue
				check((model.global_basis*own_axis).normalized().dot(axis)>.9999,"real mating transverse axis matches target "+target+"/"+kind)
				check((model.global_basis*mouth).normalized().dot(entry)<-.9999,"real pocket mouth opposes receiver entry "+target+"/"+kind)
				var center: Vector3=model.global_transform*feature(geometry,option,layout,geometry!=target,openings,rules)
				var approach:=Vector3.RIGHT if target=="three_middle" else entry
				var delta: Vector3=center-socket;var lateral: float=(delta-approach*delta.dot(approach)).length()
				var outside_trial: bool=geometry!=target and rules.row_for(target)>=0
				if outside_trial:
					var normal: Vector3=level.view.panel_transform().basis.y
					var along_stock: float=absf(delta.dot(axis))
					check(along_stock<.0002 if option==canonical or not geometry.begins_with("plank") else along_stock>.02,"wrong stock preserves the chosen along-stock pocket offset "+target+"/"+kind+"/"+option)
					check(delta.dot(normal)>=-.101 and delta.dot(normal)<.0002,"thicker wrong shoulder rests just outside the planking, without an upward escape")
				else:check(lateral<.0002 if option==canonical or not geometry.begins_with("plank") else lateral>.02,"boat frame mouths share alignment; plank opening positions retain their offsets "+target+"/"+kind+"/"+option)
				check(level.state.can_attempt(target).ok and not level.state.checked,"every choice remains trial-installable without an early verdict")
				check(level.view.camera.transform==camera_before,"alignment comes from actual stock, not a camera turn")
				cases+=1
	var previews=level.panel.gallery.previews
	var cross: Node3D=previews.cross_lap.model_root.get_child(0);var three: Node3D=previews.three_way_lap.model_root.get_child(0)
	check(cross.has_node("LowerStock") and cross.has_node("UpperStock") and not cross.has_node("MiddleStock"),"cross-lap preview contains two actual members")
	check(three.has_node("LowerStock") and three.has_node("MiddleStock") and three.has_node("UpperStock") and three.get_node("MiddleStock").position.x>0 and is_zero_approx(three.get_node("MiddleStock").position.y) and three.get_node("UpperStock").position.y>0,"three-way preview exposes the side-entry middle and descending locking member")
	# Sweep a mismatched layered pocket through the complete approach, including
	# its outer ledges; endpoints alone miss grazing intermediate frames.
	level.state.reset()
	for id in rules.IDS:
		level.state.select(id);level.state.observe();level.state.choose_joint(rules.expected(id));level.state.choose_opening("B" if id=="three_middle" else openings.target(id))
		if rules.row_for(id)>0:level.state.choose_layout("B" if rules.row_for(id)==1 else "A")
		if id=="three_middle":break
		level.state.attempt(id)
	level.view.inspect_selected();var probe=Probe.new()
	for step in 1001:
		level.view.set_preview_progress(float(step)/1000);probe.sample(level)
	check(probe.violations.is_empty(),"layered wrong opening has no triangle interference through 1001 approach positions")
	probe.free();level.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"method":"90 real model/type/opening cases: independent stock axes, mouth normals, canonical and mismatched pocket positions; camera unchanged. Pure State setup, GUI covered separately."}
	FileAccess.open("res://tests/alignment_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("ALIGNMENT_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
