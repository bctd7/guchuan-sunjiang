extends SceneTree
const State=preload("res://levels/level02/level_state.gd")
const View=preload("res://levels/level02/hull_view.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var view=View.new();root.add_child(view);var records: Array=[]
 for mode in ["correct","frame","plank","both"]:
  var state=State.new()
  for id in State.Rules.IDS:
   var row: int=State.Rules.row_for(id)
   var opening: String=State.Openings.target(id)
   if mode in ["frame","both"] and id=="cross_upper":opening="A"
   if mode in ["plank","both"] and id in ["plank_1a","plank_1b"]:opening="B"
   state.placed[id]={"joint":State.Rules.expected(id),"opening":opening,"layout":"B" if row==1 else "A"};state.layouts[row]="B" if row==1 else "A"
  view.sync_state(state)
  var data=view.trial_presentation(state.leaking_rows(),state.connection_issues(),state.mismatched_joints())
  var hull_ids: Array=state.connection_issues().filter(func(id):return id.begins_with("plank"))
  for i in hull_ids.size():
   var id: String=hull_ids[i]
   var local_point: Vector3=view.poses[id].affine_inverse()*data.connection_points[i]
   var bounds: AABB=view.TrialContact.bounds(view.TrialContact.meshes(view.pieces[id],Transform3D.IDENTITY))
   if absf(local_point.z-bounds.position.z)>.005 or local_point.y>=bounds.position.y:failures.append("water not at actual external mouth: "+id)
  var motion: Tween=view.trial.play(data);motion.set_speed_scale(8);await motion.finished
  var drops: int=view.trial.drops.get_child_count()
  if (drops>0)!=(mode in ["plank","both"]):failures.append(mode+": wrong water source")
  if (not data.structural_ids.is_empty())!=(mode in ["frame","both"]):failures.append(mode+": wrong structural source")
  if mode=="frame" and view.trial.phase!="loose":failures.append("frame-only incorrectly considered passed")
  var verdict: Dictionary=state.validate()
  if verdict.ok!=(mode=="correct"):failures.append(mode+": wrong final verdict")
  if mode=="frame" and (verdict.code!="structure" or verdict.message.contains("漏水")):failures.append("frame-only wording claims a leak")
  records.append({"mode":mode,"water_points":data.connection_points.size(),"structural_ids":data.structural_ids,"drops":drops,"phase":view.trial.phase})
  view.trial.cancel();if view.trial.phase!="idle":failures.append("cancel did not reset")
 FileAccess.open("res://tests/level02_wave_outcome_report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":records,"failures":failures,"scope":"Actual sea_trial tween and effects with controlled complete states. Verifies source categories, droplets, terminal phase and cancel; checks points at actual plank front edge and exterior face; not hydrodynamics."},"  "))
 print("WAVE_OUTCOMES ",records," failures=",failures);view.free();quit(0 if failures.is_empty() else 1)
