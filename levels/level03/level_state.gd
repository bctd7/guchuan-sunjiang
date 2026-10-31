extends RefCounted
const Rules = preload("res://levels/level03/connection_rules.gd")
signal changed
var placed: Array = []
var stage_idx := 0
var selected := "zrail"
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
	if last_outcome.ok: placed.append(selected)
	changed.emit()
	return last_outcome
func next_piece() -> void:
	for id in Rules.STAGES[stage_idx]:
		if not placed.has(id):
			selected = id
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
	selected = Rules.STAGES[stage_idx][0]
	candidate = ""
	changed.emit()
	return true
func turn_rudder(degrees: float) -> bool:
	if not placed.has("blade"): return false
	rudder_angle = clampf(degrees,-30.0,30.0)
	if rudder_angle <= -29.9: tested_left = true
	if rudder_angle >= 29.9: tested_right = true
	completed = tested_left and tested_right
	changed.emit()
	return true
func undo() -> void:
	if placed.is_empty(): return
	selected = placed.pop_back()
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
	selected = "zrail"
	candidate = ""
	completed = false
	tested_left = false
	tested_right = false
	rudder_angle = 0
	changed.emit()
