extends "res://tests/starter_joint_tests.gd"
func connected_stock(top: Node3D) -> bool:
 var cells: Array=[]
 for part in Contact.meshes(top,Transform3D.IDENTITY):cells.append(Contact.box(part))
 if cells.is_empty():return false
 var reached: Array[int]=[0];var cursor:=0
 while cursor<reached.size():
  var cell: Dictionary=cells[reached[cursor]];cursor+=1
  for i in cells.size():
   if not reached.has(i) and Contact.intersects(cell,cells[i],.00001):reached.append(i)
 return reached.size()==cells.size()
func run():
 var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
 var probe:=Probe.new();var records: Array=[]
 var fixed: Array=[]
 for node in level.view.fixed.values():fixed.append_array(Contact.meshes(node,node.transform))
 for id in ["plank_0a","plank_0b"]:
  level.state.select(id);level.state.observe();level.state.choose_joint("three_way_lap");level.state.choose_opening("C")
  var seat: Transform3D=level.view.lock_seats[id]
  var middle: Node3D=level.view.pieces[id]
  for option in ["A","B","C"]:
   level.state.choose_opening(option)
   var top: Node3D=level.view.lock_templates[id].instantiate()
   check(connected_stock(top),"paired top remains one connected piece of wood "+id+"/"+option)
   var obstacles:=fixed.duplicate();obstacles.append_array(Contact.meshes(middle,seat))
   var cells: Array=[]
   for part in obstacles:cells.append(Contact.box(part))
   var result:=Contact.blocked(top,seat,Vector3.UP,cells,level.view.StarterLock.PARK_HEIGHT)
   check(result.clear and result.distance<.002,"each matched top fully seats in its own middle "+id+"/"+option)
   var clear:=true
   for step in 31:
    var pose: Transform3D=result.pose;pose.origin.y+=(level.view.StarterLock.PARK_HEIGHT-result.distance)*(1.0-step/30.0)
    if penetrates(top,pose,obstacles,probe):clear=false;break
   check(clear,"independent full top descent stays clear until actual contact "+id+"/"+option)
   var mouth_fill:=Node3D.new()
   G.box(mouth_fill,Vector3(.025,.08,.025),Vector3(.30 if option=="B" else 0.0,.10,0),null)
   check(penetrates(top,seat,Contact.meshes(mouth_fill,seat),probe),"paired key actually occupies the visible upper mouth "+id+"/"+option)
   mouth_fill.free()
   records.append({"id":id,"option":option,"stop_height":result.distance,"path_clear":clear})
   var shifted:=seat;shifted.origin+=Vector3.BACK*.06
   var locked:=fixed.duplicate();locked.append_array(Contact.meshes(top,seat))
   check(not penetrates(middle,shifted,fixed,probe),"middle can withdraw before its paired top is fitted "+id+"/"+option)
   check(penetrates(middle,shifted,locked,probe),"paired top physically blocks middle withdrawal "+id+"/"+option)
   check(penetrates(top,shifted,fixed,probe),"paired top engages the fixed rail "+id+"/"+option)
   check(not penetrates(top,seat,fixed,probe),"completed paired top does not penetrate the receiver "+id+"/"+option)
   var wrong:=seat;wrong.origin.y-=.01
   check(penetrates(top,wrong,fixed,probe) or penetrates(top,wrong,Contact.meshes(middle,seat),probe),"paired top bears on actual joint wood "+id+"/"+option)
   top.free()
  var template: PackedScene=level.view.lock_templates[id]
  var c_top: Node3D=template.instantiate()
  for option in ["A","B"]:
   level.state.choose_opening(option)
   var obstacles:=fixed.duplicate();obstacles.append_array(Contact.meshes(middle,seat));var cells: Array=[]
   for part in obstacles:cells.append(Contact.box(part))
   var unmatched:=Contact.blocked(c_top,seat,Vector3.UP,cells,level.view.StarterLock.PARK_HEIGHT)
   check(unmatched.distance>.05,"unmatched C top remains blocked: fitting needs real paired geometry "+id+"/"+option)
  level.state.choose_opening("C")
  check(level.view.lock_templates[id]==template,"reselecting a pair reuses its immutable top "+id)
  c_top.free()
 probe.free();level.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":records,"scope":"Independent triangle/containment oracle: all six paired ABC assemblies fully seat against the fixed hull, retain connected wood, lock the middle and engage the rail. Unmatched C tops remain blocked by A/B as counterfactual controls."}
 FileAccess.open("res://tests/starter_lock_geometry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STARTER_LOCK_GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
