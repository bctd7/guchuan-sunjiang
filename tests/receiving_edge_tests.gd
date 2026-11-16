extends SceneTree
var passed:=0
var failures: Array[String]=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if ok:passed+=1
 else:failures.append(label);push_error(label)
func choose(level,id: String,kind: String=""):
 level.state.select(id);level.state.observe();level.state.choose_joint(kind if not kind.is_empty() else level.Rules.expected(id));level.state.choose_opening(level.state.Openings.target(id))
 if level.Rules.row_for(id)>0:level.state.choose_layout("B" if level.Rules.row_for(id)==1 else "A")
func run():
 var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level)
 for id in level.Rules.IDS:
  choose(level,id)
  check(level.view.installation_receiver_present(id),"correct actual edge covers both staggered plank halves "+id)
  level.state.attempt(id)
 for kind in ["cross_lap","three_way_lap"]:
  level.state.reset()
  for id in ["plank_0a","plank_0b"]:
   choose(level,id,kind)
   if kind=="three_way_lap":level.state.choose_opening("C")
   level.state.attempt(id)
   if kind=="three_way_lap":level.state.begin_starter_top(id);level.state.attempt(id)
  choose(level,"plank_1a")
  check(not level.view.installation_receiver_present("plank_1a"),"thick wrong members provide no invented plank receiver "+kind)
 level.state.reset()
 for id in ["plank_0a","plank_0b"]:choose(level,id);level.state.attempt(id)
 choose(level,"plank_1a")
 var host: Node3D=level.view.pieces.plank_0a
 var edge: MeshInstance3D
 for child in host.get_children():
  if child.get_meta("receiving_edge",false):edge=child;break
 var state_before: Dictionary=level.state.placed.duplicate(true)
 host.remove_child(edge)
 check(not level.view.installation_receiver_present("plank_1a") and level.state.placed==state_before,"removing actual tongue rejects support even with all-correct answer records")
 host.add_child(edge)
 check(level.view.installation_receiver_present("plank_1a"),"restoring real tongue restores support without changing answers")
 var mesh: Mesh=edge.mesh
 var short_mesh:=BoxMesh.new();short_mesh.size=Vector3(.30,.06,.09);edge.mesh=short_mesh
 check(not level.view.installation_receiver_present("plank_1a"),"tag alone cannot certify a short disconnected receiving span")
 edge.mesh=mesh
 var original:=edge.position;edge.position.z+=.5
 check(not level.view.installation_receiver_present("plank_1a"),"a tongue outside the mating region cannot certify the next board")
 edge.position=original
 check(level.view.installation_receiver_present("plank_1a"),"restored actual edge remains usable")
 level.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"scope":"All actual correct receiver spans, both wrong first-row member families, unchanged answer records with removed/shortened/displaced real tongue controls. Numeric tolerance covers float32 board endpoints, not missing spans."}
 FileAccess.open("res://tests/receiving_edge_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RECEIVING_EDGE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
