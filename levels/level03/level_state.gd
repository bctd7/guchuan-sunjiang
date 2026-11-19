extends RefCounted
const Rules = preload("res://levels/level03/connection_rules.gd")
signal changed
var placed: Array = []
var stage_idx := 0
var selected: String = Rules.ORDER[0]
var setting := -1
var candidate := ""
var completed := false
var rudder_angle := 0.0
var tested_left := false
var tested_right := false
var last_outcome: Dictionary = {}
func choose(joint: String) -> void:
	if joint in Rules.candidates(selected): candidate = joint
	changed.emit()
func attempt(socket: String) -> Dictionary:
	last_outcome = Rules.evaluate(selected,socket,candidate,placed,stage_idx)
	if last_outcome.ok and Rules.SETTINGS.has(selected):
		var task: Dictionary = Rules.SETTINGS[selected]
		if setting != task.correct:
			last_outcome = {"ok":false, "code":"alignment", "message":task.question if setting < 0 else task.retry}
	if last_outcome.ok:
		placed.append(selected)
	changed.emit()
	return last_outcome
func adjust(value: int) -> void:
	if placed.has(selected) or not Rules.SETTINGS.has(selected): return
	if value < 0 or value >= Rules.SETTINGS[selected].options.size(): return
	setting = value
	changed.emit()

func next_piece() -> void:
	for id in Rules.STAGES[stage_idx]:
		if not placed.has(id):
			selected = id
			setting = -1
			candidate = ""
			changed.emit()
			return
	changed.emit()
func stage_done() -> bool:
	for id in Rules.STAGES[stage_idx]:
		if not placed.has(id): return false
	return true
func next_workbench() -> bool:
	if not stage_done() or stage_idx >= 2: return false
	stage_idx += 1
	setting = -1
	selected = Rules.STAGES[stage_idx][0]
	candidate = ""
	changed.emit()
	return true
func turn_rudder(degrees: float) -> bool:
	if not placed.has("blade"): return false
	rudder_angle = clampf(degrees,-30.0,30.0)
	if rudder_angle <= -29.9: tested_left = true
	if rudder_angle >= 29.9: tested_right = true
	changed.emit()
	return true
func ready_to_launch() -> bool:
	return placed.size() == Rules.ORDER.size() and tested_left and tested_right and not completed

func finish_launch() -> void:
	if ready_to_launch():
		completed = true
		changed.emit()

func undo() -> void:
	if placed.is_empty(): return
	selected = placed.pop_back()
	setting = -1
	stage_idx = int(Rules.SPECS[selected].stage)
	candidate = ""
	completed = false
	tested_left = false
	tested_right = false
	rudder_angle = 0
	changed.emit()
func reset() -> void:
	placed.clear()
	stage_idx = 0
	selected = Rules.ORDER[0]
	setting = -1
	candidate = ""
	completed = false
	tested_left = false
	tested_right = false
	rudder_angle = 0
	changed.emit()
