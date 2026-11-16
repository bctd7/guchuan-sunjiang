extends RefCounted
## Two assembly outcomes: continue with the chosen stock, or stop after contact.
## Correctness is retained separately for the final wave trial.
const Rules = preload("res://levels/level02/connection_rules.gd")
const CONTINUE := "continue"
const BLOCKED := "blocked"

static func assess(id: String, joint: String, _opening: String) -> Dictionary:
	if joint != Rules.expected(id):
		if Rules.row_for(id)==0:
			return outcome(CONTINUE,"继续完成这处接头。")
		return outcome(BLOCKED, "这件木料的榫型与接收位置不匹配，无法继续压入。")
	# Width/depth errors do not create a third interaction state. Actual solid
	# contact and the retained predecessor determine whether this can continue.
	return outcome(CONTINUE, "木料已试装，装齐后再试浪。")

static func outcome(mode: String, message: String) -> Dictionary:
	return {"mode": mode, "message": message}
