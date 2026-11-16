extends RefCounted
## Candidate codes are stable; boat variants can differ in mouth width/depth too.
const OPTIONS=["A","B","C"]
static func target(id: String) -> String:
	if id.begins_with("plank"):return "B"
	return "A" if id=="three_upper" else "C"
static func offset(id: String,option: String) -> float:
	if not id.begins_with("plank"):return 0.0
	var distance:=.045
	return -distance if option=="A" else (distance if option=="C" else 0.0)
static func next_groove(_row: int) -> float:
	# A repeated plank is cut to the same centred profile at every height.
	return 0.0
static func matches(id: String,option: String) -> bool:
	return option==target(id)
