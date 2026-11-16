extends SceneTree
const Contact=preload("res://levels/level02/trial_contact.gd")
const Probe=preload("res://tests/stock_clearance.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if ok:passed+=1
 else:failures.append(label);push_error(label)
func penetrates(stock: Node3D,pose: Transform3D,obstacles: Array,probe) -> bool:
 for first in Contact.meshes(stock,pose):
  var bounds: AABB=first.pose*first.mesh.get_aabb()
  for second in obstacles:
   var overlap: AABB=bounds.intersection(second.pose*second.mesh.get_aabb())
   if minf(overlap.size.x,minf(overlap.size.y,overlap.size.z))<=.00002:continue
   if probe.triangles_intersect(first,second):return true
 return false
func run():
 var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level)
 var probe:=Probe.new()
 var original:=Node3D.new();G.box(original,Vector3(8,.18,.32),Vector3(0,0,-.16),null);G.box(original,Vector3(8,.06,.09),Vector3(0,0,.045),null)
 var uncut:=Contact.meshes(original,level.view.panel_transform())
 var fixed: Array=[]
 for node in level.view.fixed.values():fixed.append_array(Contact.meshes(node,node.transform))
 var records: Array=[]
 for id in ["plank_0a","plank_0b"]:
  for kind in ["tongue_groove","cross_lap","three_way_lap"]:
   for opening in ["A","B","C"]:
    level.state.select(id);level.state.observe();level.state.choose_joint(kind);level.state.choose_opening(opening)
    var stock: Node3D=level.view.pieces[id]
    var pose: Transform3D=level.view.contact_poses[id]
    var offset: Vector3=level.view.preview_offset(id)
    var clear:=true
    for sample in 51:
     var step:=pose;step.origin+=level.view.preview_displacement(id,sample/50.0)
     if penetrates(stock,step,fixed,probe):clear=false;break
    check(clear,"independent full fixed-hull mesh sweep "+id+"/"+kind+"/"+opening)
    var occupies_cut:=penetrates(stock,pose,uncut,probe)
    if kind in ["cross_lap","three_way_lap"]:
     check(occupies_cut,"selected joint actually enters removed rail volume instead of resting on its top "+id+"/"+opening)
    if kind in ["cross_lap","three_way_lap"]:
     var bounds: AABB=Contact.bounds(Contact.meshes(stock,Transform3D.IDENTITY))
     check(not stock.get_child(0).has_node("PlankBody"),"no appended board or extra tongue "+kind)
     check(absf(bounds.size.y-(.28 if kind=="cross_lap" else .32))<.0001,"thickness is added to the original stock "+kind)
     check(absf(bounds.size.x-(.28 if kind=="cross_lap" else 2.0))<.0001,"stock keeps original width/length instead of attaching a broad slab "+kind)
     check(absf(bounds.position.y-(-.09 if kind=="cross_lap" else -.12))<.0001,"lower mating surfaces remain at their original coordinates "+kind)
    if kind=="cross_lap":
     check(absf(pose.basis.z.dot(Vector3.RIGHT))<.001,"cross stock is perpendicular to longitudinal receiver")
     var last: Vector3=level.view.preview_displacement(id,.9)
     check(last.y>0 and is_zero_approx(last.z) and is_zero_approx(level.view.preview_displacement(id,.3).z),"single thick cross member lowers vertically into the opposed notch")
    if kind=="tongue_groove" and opening=="B":
     check(occupies_cut,"integral correct board keys fill the housed rail")
     check(pose.is_equal_approx(level.view.panel_transform()),"correct first board keeps original complete-hull placement")
    records.append({"id":id,"kind":kind,"opening":opening,"position":[pose.origin.x,pose.origin.y,pose.origin.z],"occupies_real_housing":occupies_cut,"path_clear":clear})
 original.free();probe.free();level.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":records,"scope":"18 actual first-row stock variants, 51 positions each against every fixed hull mesh; independent narrow-phase intersections, original uncut rail counterfactual proving true housing entry, fixed correct board placement."}
 FileAccess.open("res://tests/starter_joint_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STARTER_JOINT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
