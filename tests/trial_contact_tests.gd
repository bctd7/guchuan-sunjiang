extends SceneTree
## Geometry combinations using pure State setup; GUI motion is covered separately.
const Probe=preload("res://tests/stock_clearance.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func run() -> void:
	var level=load("res://levels/level02/level02.tscn").instantiate();root.add_child(level);level.learning.start_button.pressed.emit()
	var probe=Probe.new();var cases:=0
	for target in level.Rules.IDS:
		var choices: Array=[]
		for joint in level.Rules.JOINT_NAMES:
			if joint!=level.Rules.expected(target):choices.append([joint,level.state.Openings.target(target)])
		for opening in level.state.Openings.OPTIONS:
			if opening!=level.state.Openings.target(target):choices.append([level.Rules.expected(target),opening])
		for choice in choices:
			level.state.reset();probe.violations.clear()
			for id in level.Rules.IDS:
				level.state.select(id);level.state.observe();level.state.choose_joint(choice[0] if id==target else level.Rules.expected(id));level.state.choose_opening(choice[1] if id==target else level.state.Openings.target(id))
				if level.Rules.row_for(id)>0:level.state.choose_layout("B" if level.Rules.row_for(id)==1 else "A")
				if id==target:
					level.view.inspect_selected();level.view.set_preview_progress(1.0);probe.sample(level)
				var decision: Dictionary=level._physical_decision(id,level.state.installation_result(id))
				if decision.mode==level.state.Assembly.BLOCKED:
					level.state.fail_installation(id,decision.message);break
				var installed: Dictionary=level.state.attempt(id)
				if installed.code=="middle_seated":
					level.state.begin_starter_top(id);level.state.attempt(id)
				level.state.finish_installation(id)
				probe.sample(level)
				if level.state.failed:break
			check(level.view.contact_failures.is_empty(),"supported pose exists "+target+"/"+str(choice)+": "+str(level.view.contact_failures))
			check(probe.violations.is_empty(),"mixed hull has no intersecting loose trial wood "+target+"/"+str(choice)+": "+str(probe.violations.keys()))
			var blocked: bool=choice[0]!=level.Rules.expected(target) or target in ["three_upper","three_middle"]
			check(not level.state.checked and (level.state.failed if blocked else not level.state.failed and level.state.placed.size()==10),"only continued or failed outcomes after real contact")
			cases+=1
	probe.free();level.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"combinations":cases,"method":"40 mixed State/geometry combinations; independent triangle/containment checks, not GUI or engineering physics"};FileAccess.open("res://tests/trial_contact_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("TRIAL_CONTACT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
