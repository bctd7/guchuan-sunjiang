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
	var s=State.new()
	check(s.attempt("plank_0a").code=="observe","observation required")
	s.observe()
	s.choose_joint("cross_lap")
	check(s.attempt("plank_0a").code=="joint","wrong joint refused")
	s.choose_joint("tongue_groove")
	check(s.attempt("plank_0b").code=="socket","wrong slot refused")
	for id in Rules.IDS:
		s.select(id)
		s.observe()
		s.choose_joint(Rules.expected(id))
		if Rules.row_for(id)>0: s.choose_layout("A")
		check(s.attempt(id).ok,"place "+id)
	check(s.bad_row()==1,"only end seams define alignment")
	check(s.validate().code=="leak" and not s.completed,"aligned seams fail inspection")
	s.repair()
	check(s.placed.size()==2 and s.next_id()=="plank_1a","repair rewinds to first bad row")
	for id in Rules.IDS.slice(2):
		s.select(id)
		s.observe()
		s.choose_joint(Rules.expected(id))
		if Rules.row_for(id)>0: s.choose_layout("B" if Rules.row_for(id)==1 else "A")
		check(s.attempt(id).ok,"retry "+id)
	check(s.validate().ok and s.completed,"staggered seams complete")
	s.undo()
	check(not s.completed and s.placed.size()==9,"undo completion")
	s.reset()
	check(s.placed.is_empty() and s.observed.is_empty(),"restart clears observations")
	var report={"passed":passed,"failed":failed}
	var f=FileAccess.open("res://tests/level02_rules_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("LEVEL02 RULES ",report)
	quit(0 if failed==0 else 1)
