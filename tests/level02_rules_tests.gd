extends SceneTree
const Rules = preload("res://levels/level02/connection_rules.gd")
const State = preload("res://levels/level02/level_state.gd")
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error(label)
func _initialize() -> void:
	var flattened: Array=[]
	for group in Rules.GROUPS:flattened.append_array(group)
	check(Rules.GROUPS.size()==3 and flattened==Rules.IDS,"three assembly groups retain all ten ordered installation records")
	var s=State.new()
	check(s.group_target(0)=="plank_0a" and s.group_target(1).is_empty(),"display group navigation cannot skip unfinished groups")
	check(s.attempt("plank_0a").code=="observe","observation required")
	s.observe()
	s.choose_joint("cross_lap")
	s.choose_opening("B")
	check(s.can_attempt("plank_0a").ok and not s.failed,"wrong type remains explorable before commit")
	check(s.attempt("plank_0a").ok and not s.failed and s.placed.plank_0a.joint=="cross_lap","seatable wrong first-row plank remains installed without an early verdict")
	check(s.finish_installation("plank_0a").code=="assembly_mismatch" and s.failed and s.placed.size()==1,"final seating reports the wrong first joint without erasing its model")
	check(not s.place_repeat("plank_0a").ok,"rejected complete joint cannot repeat")
	s.reset()
	s.observe()
	s.choose_joint("tongue_groove")
	check(s.attempt("plank_0b").code=="socket","wrong slot refused")
	for id in Rules.IDS:
		s.select(id)
		s.observe()
		s.choose_joint(Rules.expected(id))
		s.choose_opening(s.Openings.target(id))
		if Rules.row_for(id)>0: s.choose_layout("A")
		check(s.attempt(id).ok,"place "+id)
		if id=="plank_0a":check(s.next_in_group().is_empty(),"automatic board never becomes an extra manual continuation")
		if id=="plank_2b":check(s.group_target(0)=="plank_2b","completed board group can be reviewed")
	check(s.bad_row()==1,"only end seams define alignment")
	check(s.validate().code=="leak" and s.failed and not s.completed,"aligned seams fail final inspection")
	var saved=s.placed.duplicate(true)
	s.undo()
	check(s.placed==saved and s.failed and s.attempt("bulkhead").code=="failed","failed run cannot be undone or continued")
	check(s.validate().code=="leak","failed verdict remains stable")
	s.reset()
	check(not s.failed and s.placed.is_empty() and not s.checked,"restart clears failed hull state")
	for id in Rules.IDS:
		s.select(id)
		s.observe()
		s.choose_joint(Rules.expected(id))
		s.choose_opening(s.Openings.target(id))
		if Rules.row_for(id)>0: s.choose_layout("B" if Rules.row_for(id)==1 else "A")
		check(s.attempt(id).ok,"retry "+id)
	check(s.validate().ok and s.completed,"staggered seams complete")
	s.undo()
	check(not s.completed and s.placed.size()==9,"undo completion")
	s.reset()
	check(s.placed.is_empty() and s.observed.is_empty(),"restart clears observations")
	# First-row wrong planks remain real choices; incompatible later stock stops locally.
	for target in Rules.IDS:
		for kind in Rules.JOINT_NAMES:
			if kind==Rules.expected(target):continue
			s.reset()
			for id in Rules.IDS:
				s.select(id);s.observe();s.choose_joint(kind if id==target else Rules.expected(id));s.choose_opening(s.Openings.target(id))
				if Rules.row_for(id)>0:s.choose_layout("B" if Rules.row_for(id)==1 else "A")
				if id==target:
					var prefix: Dictionary=s.placed.duplicate(true)
					check(s.can_attempt(id).ok,"wrong stock stays explorable")
					if Rules.row_for(id)==0:
						var result: Dictionary=s.attempt(id)
						if kind=="three_way_lap":
							check(result.code=="middle_seated" and not s.placed.has(id),"first middle stroke preserves an incomplete local joint")
							check(s.finish_installation(id).code=="unfinished" and not s.failed,"middle-only stage cannot trigger completed-joint failure")
							s.begin_starter_top(id);result=s.attempt(id)
						check(result.ok and not s.failed and s.placed[id].joint==kind,"complete first-row wrong joint retains its choice "+target+"/"+kind)
						check(s.finish_installation(id).code=="assembly_mismatch" and s.failed and not s.checked,"wrong first joint fails only on final seating completion")
					else:
						check(s.attempt(id).code=="assembly_blocked" and not s.failed and s.placed==prefix,"impossible stock is not installed "+target+"/"+kind)
						check(s.fail_installation(id,"contact finished").code=="assembly_failed" and s.failed and not s.checked,"contact completion automatically ends an impossible assembly")
					break
				check(s.attempt(id).ok,"correct prefix remains installable")
	# Same-row repeats copy errors, record provenance, and undo as one operation.
	s.reset();s.select("plank_0a");s.observe();s.choose_joint("tongue_groove");s.choose_opening("C");s.attempt("plank_0a")
	check(s.place_repeat("plank_0a").ok,"same-row repeat accepted after its representative")
	check(s.placed.plank_0b.joint=="tongue_groove" and s.placed.plank_0b.opening=="C" and s.placed.plank_0b.layout=="A" and s.placed.plank_0b.automatic and s.placed.plank_0b.demonstrated_by=="plank_0a","wrong choice copied exactly, never corrected")
	check(not s.failed and not s.checked and s.mismatched_openings()==["plank_0a","plank_0b"],"repeat retains both wrong records without early verdict")
	check(not s.place_repeat("plank_0a").ok,"repeat cannot duplicate occupied wood")
	s.undo();check(s.placed.is_empty() and s.selected=="plank_0a","undo removes full last repeated row")
	check(Rules.AUTO_GROUPS.plank_0a.size()==5 and Rules.AUTO_GROUPS.cross_upper==["bulkhead"] and Rules.MANUAL_IDS.size()==4 and not Rules.AUTO_GROUPS.has("three_middle"),"homologous cuts repeat; the side and top interlock strokes stay manual")
	var report={"passed":passed,"failed":failed}
	var f=FileAccess.open("res://tests/level02_rules_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("LEVEL02 RULES ",report)
	quit(0 if failed==0 else 1)
