extends SceneTree
var failures: Array[String]=[]
var passed:=0
func check(value: bool,label: String):
 if value:passed+=1
 else:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var l=load("res://levels/level02/level02.tscn").instantiate();root.add_child(l)
 var records: Array=[]
 for target in ["cross_upper","three_middle","three_upper","bulkhead"]:
  for option in ["A","B","C"]:
   l.state.reset()
   for id in l.Rules.IDS:
    l.state.select(id);l.state.observe();l.state.choose_joint(l.Rules.expected(id));l.state.choose_opening(option if id==target else l.state.Openings.target(id))
    if l.Rules.row_for(id)>0:l.state.choose_layout("B" if l.Rules.row_for(id)==1 else "A")
    if id==target:break
    l.state.attempt(id)
   check(l.view.installation_path_clear(target),"actual approach clear "+target+"/"+option)
   records.append({"id":target,"option":option,"y":l.view.poses[target].origin.y,"mode":l.state.installation_result(target).mode})
   if target=="three_middle":
    check(absf(l.view.poses[target].origin.y-1.45)<.00001,"all middle lower mouths seat on lower stock "+option)
    check(l.state.attempt(target).ok,"middle candidate can be provisionally fitted")
    l.state.select("three_upper");l.state.observe();l.state.choose_joint("three_way_lap");l.state.choose_opening("A")
    var stopped: bool=l.view.poses.three_upper.origin.y>1.46
    check(stopped==(option!="C"),"top physically blocked only by wrong upper receiving channel "+option)
    check(l.view.installation_path_clear("three_upper"),"top can reach first real contact without penetration")
    records.append({"middle":option,"top_contact_y":l.view.poses.three_upper.origin.y})
   if target=="cross_upper":
    check(l.view.poses[target].basis.is_equal_approx(Basis.IDENTITY),"cross stock retains aligned mouth, no support-bay tipping")
    check(absf(l.view.poses[target].origin.y-(1.31118 if option=="A" else 1.25))<.002,"cross shallow contact/wide or correct full seat "+option)
 l.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"records":records}
 FileAccess.open("res://tests/boat_joint_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BOAT_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
