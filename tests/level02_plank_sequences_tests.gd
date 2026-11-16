extends SceneTree
const State=preload("res://levels/level02/level_state.gd")
const View=preload("res://levels/level02/hull_view.gd")
var failures: Array[String]=[]
var passed:=0
func check(ok: bool,label: String) -> void:
 if ok:passed+=1
 else:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var view=View.new();root.add_child(view)
 var cases:=0;var records: Array=[]
 for first in ["A","B","C"]:
  for middle in ["A","B","C"]:
   for upper in ["A","B","C"]:
    for middle_layout in ["A","B"]:
     for upper_layout in ["A","B"]:
      var state=State.new();var choices: Array=[first,middle,upper];var layouts: Array=["A",middle_layout,upper_layout];var shifts: Array=[]
      for row in 3:
       var id: String="plank_%da"%row
       state.select(id);state.observe();state.choose_joint("tongue_groove");state.choose_opening(choices[row])
       if row>0:state.choose_layout(layouts[row])
       view.sync_state(state)
       check(view.installation_path_clear(id),"manual board path "+str(choices)+"/"+str(layouts)+"/"+id)
       check(state.attempt(id).ok,"same-type board remains trial-installable")
       state.prepare_repeat(id);view.sync_state(state)
       var other: String=State.Rules.REPEATS[id]
       check(view.installation_path_clear(other),"automatic board checks its own path "+other)
       check(state.place_repeat(id).ok,"automatic board accepted after its own path check")
       view.sync_state(state)
       check(state.placed[other].opening==choices[row] and state.placed[other].layout==layouts[row] and state.placed[other].demonstrated_by==id,"exact choices and repeat provenance retained")
       var local: Vector3=view.panel_transform().affine_inverse()*view.poses[id].origin
       var paired: Vector3=view.panel_transform().affine_inverse()*view.poses[other].origin
       check(absf(local.z-paired.z)<.0001,"two actual board halves meet at the same row depth")
       shifts.append(local.z)
      check(state.placed.size()==6 and not state.failed,"all six physical planks remain trial state")
      cases+=1;records.append({"openings":choices,"layouts":layouts,"shifts":shifts})
 view.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"sequences":records,"method":"108 opening/layout sequences through State and production View path checks for each manual and automatic board; geometric checks, not pointer input or structural engineering."}
 FileAccess.open("res://tests/level02_plank_sequences_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PLANK_SEQUENCES ",passed," failures=",failures," cases=",cases);quit(0 if failures.is_empty() else 1)
