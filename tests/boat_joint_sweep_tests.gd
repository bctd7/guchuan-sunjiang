extends SceneTree
const Boat=preload("res://models/ship/hull/boat_joints.gd")
const Contact=preload("res://levels/level02/trial_contact.gd")
const Probe=preload("res://tests/stock_clearance.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize():run.call_deferred()
func check(value: bool,label: String):
 if value:passed+=1
 else:failures.append(label);push_error(label)
func penetrates(a: Node3D,pose: Transform3D,obstacles: Array,probe) -> bool:
 for first in Contact.meshes(a,pose):
  var bounds: AABB=first.pose*first.mesh.get_aabb()
  for second in obstacles:
   var overlap: AABB=bounds.intersection(second.pose*second.mesh.get_aabb())
   if minf(overlap.size.x,minf(overlap.size.y,overlap.size.z))<=.00002:continue
   if probe.triangles_intersect(first,second):return true
 return false
func sweep(a: Node3D,end: Transform3D,obstacles: Array,probe,label: String,direction:=Vector3.UP) -> void:
 var collided:=false
 var steps:=130 if direction==Vector3.RIGHT else 65
 for step in steps+1:
  var pose:=end;pose.origin+=direction*(steps-step)*.01
  if penetrates(a,pose,obstacles,probe):collided=true;break
 check(not collided,"independent actual mesh sweep "+label)
func run():
 var probe:=Probe.new();var records: Array=[]
 for option in ["A","B","C"]:
  var lower:=Node3D.new();var upper:=Node3D.new()
  Boat.cross_member(lower,false,null);Boat.cross_member(upper,true,null,option)
  var obstacles:=Contact.meshes(lower,Transform3D.IDENTITY);var solids: Array=[]
  for part in obstacles:solids.append(Contact.box(part))
  var result:=Contact.blocked(upper,Transform3D.IDENTITY,Vector3.UP,solids)
  sweep(upper,result.pose,obstacles,probe,"cross/"+option)
  var below: Transform3D=result.pose;below.origin.y-=.01
  check(penetrates(upper,below,obstacles,probe),"cross actually bears on wood, not a floating clearance pose "+option)
  if option=="B":
   var safe:=true
   for step in 51:
    var shifted: Transform3D=result.pose;shifted.origin.z=(step-25)*.001
    if penetrates(upper,shifted,obstacles,probe):safe=false
   check(safe,"wide lap has a real supported sliding range for the wave movement")
   for side in [-1,1]:
    var beyond: Transform3D=result.pose;beyond.origin.z=side*.10
    check(penetrates(upper,beyond,obstacles,probe),"wide lap's actual shoulders bound lateral travel "+str(side))
  lower.free();upper.free()
 # The automatically repeated panel uses the same cut but a shorter foot.
 # Check its own solids instead of assuming the representative's result.
 for option in ["A","B","C"]:
  var base:=Node3D.new();var foot:=Node3D.new()
  Boat.cross_member(base,false,null,"C",1.4);Boat.bulkhead_foot(foot,null,option)
  var obstacles:=Contact.meshes(base,Transform3D.IDENTITY);var solids: Array=[]
  for part in obstacles:solids.append(Contact.box(part))
  var result:=Contact.blocked(foot,Transform3D.IDENTITY,Vector3.UP,solids)
  sweep(foot,result.pose,obstacles,probe,"repeated panel foot/"+option)
  var below: Transform3D=result.pose;below.origin.y-=.01
  check(penetrates(foot,below,obstacles,probe),"repeated panel foot rests on actual base wood "+option)
  check((result.distance>.04)==(option=="A"),"panel and representative retain the same shallow/fully seated distinction "+option)
  base.free();foot.free()
 for middle_option in ["A","B","C"]:
  var lower:=Node3D.new();var middle:=Node3D.new()
  Boat.three_member(lower,0,null,"C");Boat.three_member(middle,1,null,middle_option)
  var lower_parts:=Contact.meshes(lower,Transform3D.IDENTITY)
  sweep(middle,Transform3D.IDENTITY,lower_parts,probe,"side-entering middle/"+middle_option,Vector3.RIGHT)
  var below:=Transform3D(Basis.IDENTITY,Vector3(0,-.01,0))
  check(penetrates(middle,below,lower_parts,probe),"provisional middle is supported by lower member "+middle_option)
  var lifted:=Transform3D(Basis.IDENTITY,Vector3(0,.02,0))
  check(penetrates(middle,lifted,lower_parts,probe),"lower retaining lips prevent the middle from entering or leaving vertically "+middle_option)
  for top_option in ["A","B","C"]:
   var top:=Node3D.new();Boat.three_member(top,2,null,top_option)
   var obstacles:=lower_parts.duplicate();obstacles.append_array(Contact.meshes(middle,Transform3D.IDENTITY))
   var solids: Array=[]
   for part in obstacles:solids.append(Contact.box(part))
   var result:=Contact.blocked(top,Transform3D.IDENTITY,Vector3.UP,solids)
   sweep(top,result.pose,obstacles,probe,"top/"+middle_option+"/"+top_option)
   var fits: bool=result.distance<.0001
   check(fits==(middle_option=="C" and top_option=="A"),"actual full mating agrees with three-piece combination "+middle_option+"/"+top_option)
   check(penetrates(top,Transform3D.IDENTITY,obstacles,probe)==not fits,"independent final solid collision identifies blocked combination")
   if fits:
    var withdrawal:=Transform3D(Basis.IDENTITY,Vector3(.03,0,0))
    check(not penetrates(middle,withdrawal,lower_parts,probe),"before the top, the middle can slide back out through its actual rebate")
    var locked:=lower_parts.duplicate();locked.append_array(Contact.meshes(top,Transform3D.IDENTITY))
    check(penetrates(middle,withdrawal,locked,probe),"the fitted top physically blocks the middle's exit, rather than merely adding a third visible stick")
   records.append({"middle":middle_option,"top":top_option,"full_fit":fits,"stop_height":result.distance})
   top.free()
  lower.free();middle.free()
 probe.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"three_piece_matrix":records,"scope":"Actual generated boat meshes. 66 samples per vertical approach and 131 per horizontal middle approach; independent triangle/containment and horizontal-cap polygon oracle, retaining-lip and top-lock controls, plus downward penetration controls proving real contact. Not engineering dynamics."}
 FileAccess.open("res://tests/boat_joint_sweep_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BOAT_SWEEPS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
