extends SceneTree
const Presentation=preload("res://levels/level02/trial_presentation.gd")
const SeaTrial=preload("res://levels/level02/sea_trial.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var part:=Node3D.new();scene.add_child(part)
	var rest:=Transform3D(Basis.IDENTITY,Vector3(2,1,3));part.transform=rest
	var plan=Presentation.new();plan.seam_rows.assign([0]);plan.seam_poses.assign([Transform3D(Basis.IDENTITY,Vector3(1,2,3))]);plan.connection_points.assign([Vector3(4,5,6)]);plan.loose_parts.assign([Presentation.LoosePart.new("wrong",part,rest)])
	var effects=SeaTrial.new();scene.add_child(effects);effects.setup()
	var tween: Tween=effects.play(plan);tween.set_speed_scale(8)
	plan.seam_rows.clear();plan.seam_poses.clear();plan.connection_points.clear();plan.loose_parts[0].rest=Transform3D.IDENTITY
	check(effects.leak_rows==[0] and effects.opening_points==[Vector3(4,5,6)] and effects.loose_ids==["wrong"],"trial snapshots input without a HullView or State")
	var ids: Array=effects.loose_ids;ids.clear()
	check(effects.loose_ids==["wrong"],"diagnostic queries cannot mutate presentation")
	var deadline:=Time.get_ticks_msec()+2000;var moved:=false
	while tween.is_running() and Time.get_ticks_msec()<deadline:
		if effects.phase=="impact" and not part.transform.is_equal_approx(rest):moved=true
		await process_frame
	check(moved and part.transform.is_equal_approx(rest),"independent effect moves and restores the supplied part pose")
	check(effects.cracks.get_child_count()==2 and effects.drops.get_child_count()==10,"snapshot creates seam and connection effects after caller changes its plan")
	tween=effects.play(Presentation.new());tween.set_speed_scale(8);await tween.finished
	check(effects.phase=="passed" and effects.drops.get_child_count()==0,"empty presentation is a dry trial")
	plan=Presentation.new();plan.loose_parts.assign([Presentation.LoosePart.new("wrong",part,rest)]);effects.play(plan).set_speed_scale(8)
	deadline=Time.get_ticks_msec()+1500
	while effects.phase!="impact" and Time.get_ticks_msec()<deadline:await process_frame
	effects.cancel();await create_timer(.4).timeout
	check(effects.phase=="idle" and effects.loose_ids.is_empty() and effects.drops.get_child_count()==0 and part.transform.is_equal_approx(rest),"cancel restores poses and old callbacks cannot restart effects")
	part.free();effects.cancel();scene.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://tests/sea_trial_presentation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("TRIAL_PRESENTATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
