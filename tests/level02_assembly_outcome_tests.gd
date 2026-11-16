extends SceneTree
const State=preload("res://levels/level02/level_state.gd")
var passed:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
 if ok:passed+=1
 else:failures.append(message);push_error(message)
func ready_state(target: String):
 var state=State.new()
 for id in State.Rules.IDS:
  if id==target:break
  var row: int=State.Rules.row_for(id)
  state.placed[id]={"joint":State.Rules.expected(id),"opening":State.Openings.target(id),"layout":"B" if row==1 else "A"}
 state.select(target);state.observe()
 if State.Rules.row_for(target)>0:state.choose_layout("B" if State.Rules.row_for(target)==1 else "A")
 return state
func _initialize() -> void:
 for target in State.Rules.MANUAL_IDS:
  for joint in State.Rules.JOINT_NAMES:
   for opening in State.Openings.OPTIONS:
    var state=ready_state(target);state.choose_joint(joint);state.choose_opening(opening)
    var original: Dictionary=state.placed.duplicate(true)
    var expected_ok: bool=target=="plank_0a" or joint==State.Rules.expected(target)
    check(state.can_attempt(target).ok and not state.failed,"Exploration remains neutral: "+target)
    var assessed: Dictionary=state.installation_result(target)
    check(not state.failed and state.placed==original,"Assessment has no installation side effects")
    check((assessed.mode!="blocked")==expected_ok,"Submitted choice classification: "+target+"/"+joint+"/"+opening)
    var result: Dictionary=state.attempt(target)
    check(result.ok==expected_ok,"Commit follows the installation decision")
    if target=="plank_0a" and joint=="three_way_lap":
     check(result.code=="middle_seated" and state.placed==original,"middle stroke alone cannot complete a three-part joint")
     check(not state.place_repeat(target).ok,"automatic companion cannot skip the uninstalled top")
     state.begin_starter_top(target)
     check(state.attempt(target).ok and state.starter_completed(target),"after external geometry approval the top completes the local joint")
    if not expected_ok:
     check(not state.failed and state.placed==original and not state.checked,"assessment refuses incompatible stock without a premature verdict before contact")
     state.attempt(target)
     check(not state.failed and state.placed==original,"Repeated blocked push never consumes the whole build")
     check(state.fail_installation(target,"contact finished").code=="assembly_failed" and state.failed,"Contact completion automatically ends the impossible build")
     check(not state.place_repeat("plank_0a").ok,"Failure blocks automatic companions")
     var before: Dictionary=state.failure_result()
     state.fail_installation(target,"late callback")
     check(state.failure_result()==before and not state.attempt(target).ok,"Failure and stale attempts are idempotent")
     state.reset();check(not state.failed and state.placed.is_empty(),"Restart clears installation failure")
    elif target=="plank_0a" and joint!=State.Rules.expected(target):
     check(not state.failed,"accepted geometry waits for final animation completion")
     check(state.finish_installation(target).code=="assembly_mismatch" and state.failed,"completed first-row wrong family fails locally")
     check(not state.place_repeat(target).ok and state.placed.size()==1,"failed local joint cannot duplicate or advance")
    elif target.begins_with("plank"):
     check(state.finish_installation(target).ok and not state.failed,"correct family completes seating without an early opening verdict")
     check(state.place_repeat(target).ok,"Accepted board permits its automatic companion")
     var child: Dictionary=state.placed[State.Rules.REPEATS[target]]
     check(child.joint==joint and child.opening==opening and child.demonstrated_by==target,"Automatic companion retains the exact accepted choice")
 var stale=ready_state("three_upper");stale.placed.three_middle.opening="A";stale.choose_joint("three_way_lap");stale.choose_opening("A")
 check(stale.installation_result("three_upper").ok and not stale.failed and not stale.placed.has("three_upper"),"state assessment defers middle/top closure to actual geometry; it cannot certify the fit")
 var correct=State.new()
 for id in State.Rules.MANUAL_IDS:
  correct.select(id);correct.observe();correct.choose_joint(State.Rules.expected(id));correct.choose_opening(State.Openings.target(id))
  if State.Rules.row_for(id)>0:correct.choose_layout("B" if State.Rules.row_for(id)==1 else "A")
  check(correct.attempt(id).ok,"Correct manual sequence: "+id)
  while not correct.next_automatic(id).is_empty():
   check(correct.prepare_automatic(id).ok and correct.place_automatic(id).ok,"Correct repeat sequence")
 check(correct.validate().ok and correct.completed,"All-correct ten-part hull still completes")
 print("ASSEMBLY_OUTCOME ",JSON.stringify({"passed":passed,"failures":failures}));quit(0 if failures.is_empty() else 1)
