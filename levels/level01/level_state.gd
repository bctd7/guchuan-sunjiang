extends RefCounted
## Reusable semantic state. A presentation animates only changes accepted here.

const Rules = preload("res://levels/level01/connection_rules.gd")
signal changed
signal feedback(message: String)

var placed: Dictionary = Rules.initial_connections()
var selected: String = "rib_l1"
var completed: bool = false
var failed: bool = false
var _failure: Dictionary = {}
## Only player demonstrations enter undo history.
var placement_order: Array[String] = []
var pending_group: String = ""

func select_piece(id: String) -> Dictionary:
	if failed: return _failed()
	if id == "keel":
		return _report(Rules.result(false, "fixed_foundation", "龙骨已固定，请选择示范构件。"))
	if not pending_group.is_empty():
		return _assembling()
	if not Rules.SPECS.has(id):
		return _report(Rules.result(false, "unknown_piece", "请选择可用的木料。"))
	if not id in Rules.REPRESENTATIVE_IDS:
		return _report(Rules.result(false, "automatic_piece", "同类构件会在示范成功后自动装入。"))
	selected = id
	changed.emit()
	return Rules.result(true, "selected", str(Rules.SPECS[id].label))

func attempt_place(piece_id: String, socket_id: String, joint_type: String = "", length: String = "correct") -> Dictionary:
	if failed: return _failed()
	if not pending_group.is_empty():
		return _assembling()
	if Rules.BUILD_IDS.has(piece_id) and not Rules.REPRESENTATIVE_IDS.has(piece_id):
		return _report(Rules.result(false, "automatic_piece", "请先完成这一类榫型的代表件示范。"))
	var outcome: Dictionary = Rules.evaluate(piece_id, socket_id, joint_type, length, placed, completed)
	if outcome.ok:
		placed[piece_id] = {"socket":socket_id, "joint":Rules.expected_joint(piece_id) if joint_type.is_empty() else joint_type, "length":length, "automatic":false}
		placement_order.append(piece_id)
		pending_group = piece_id
		selected = piece_id
		changed.emit()
	return _report(outcome)

func place_automatic(id: String) -> Dictionary:
	if failed: return _failed()
	if pending_group.is_empty():
		return _report(Rules.result(false, "no_pending_group", "请先完成代表件的榫型示范。"))
	if not id in Rules.AUTO_GROUPS[pending_group]:
		return _report(Rules.result(false, "wrong_group", "这个构件不属于当前自动装配组。"))
	if not Rules.connection_attached(pending_group, placed):
		return _report(Rules.result(false, "invalid_demonstration", "代表件连接已失效，请撤回后重新示范。"))
	# Each member has its own insertion turn; earlier members must be seated.
	for batch in Rules.AUTO_BATCHES[pending_group]:
		if id in batch:
			break
		for earlier_id in batch:
			if not Rules.connection_attached(earlier_id, placed):
				return _report(Rules.result(false, "automatic_order", "请先装妥前一组同类构件。"))
	# Bypass only the interaction gate; geometry and support rules still apply.
	var length: String = str(placed[pending_group].length)
	var joint: String = str(placed[pending_group].joint)
	var outcome: Dictionary = Rules.evaluate(id, id, joint, length, placed, completed)
	if outcome.ok:
		placed[id] = {"socket":id, "joint":joint, "length":length, "automatic":true, "demonstrated_by":pending_group}
		outcome["piece_id"] = id
		outcome["demonstrated_by"] = pending_group
		changed.emit()
	return _report(outcome)

func finish_automatic() -> Dictionary:
	if failed: return _failed()
	if pending_group.is_empty():
		return _report(Rules.result(false, "no_pending_group", "当前没有等待完成的自动装配。"))
	if not Rules.connection_attached(pending_group, placed):
		return _report(Rules.result(false, "invalid_demonstration", "代表件连接已失效，请撤回后重新示范。"))
	for id in Rules.AUTO_GROUPS[pending_group]:
		if not Rules.connection_attached(id, placed) or not bool(placed[id].get("automatic", false)) or str(placed[id].get("demonstrated_by", "")) != pending_group:
			return _report(Rules.result(false, "incomplete_automatic", "同类构件尚未全部装妥。"))
	var representative := pending_group
	pending_group = ""
	changed.emit()
	var outcome: Dictionary = Rules.result(true, "automatic_complete", "同类构件已自动装妥，可以继续下一次示范。")
	outcome["piece_id"] = representative
	return _report(outcome)

func undo() -> Dictionary:
	if failed: return _failed()
	if placement_order.is_empty():
		return _report(Rules.result(false, "nothing_to_undo", "还没有完成示范；固定龙骨会一直保留。"))
	return remove_piece(placement_order.back())

func remove_piece(id: String) -> Dictionary:
	if failed: return _failed()
	if id == "keel":
		return _report(Rules.result(false, "fixed_foundation", "龙骨是固定基础，撤回只取回后装构件。"))
	if Rules.BUILD_IDS.has(id) and not Rules.REPRESENTATIVE_IDS.has(id):
		return _report(Rules.result(false, "automatic_piece", "请撤回代表件，以一起取回同类自动构件。"))
	if not pending_group.is_empty() and id != pending_group:
		return _assembling()
	if not placed.has(id):
		return _report(Rules.result(false, "not_placed", "这块木料尚未装入。"))
	if Rules.stage_for(id) == "ribs":
		for brace_id in Rules.BRACE_IDS:
			if placed.has(brace_id):
				return _report(Rules.result(false, "dependents", "请先撤回加固件，再调整船肋。"))
	return _remove(id)

func reset() -> void:
	placed = Rules.initial_connections()
	placement_order.clear()
	pending_group = ""
	selected = "rib_l1"
	completed = false
	failed = false
	_failure.clear()
	changed.emit()
	feedback.emit("龙骨已就位。")

func stage() -> String:
	if failed:
		return "failed"
	if completed:
		return "complete"
	if not Rules.ribs_attached(placed):
		return "ribs"
	return "braces"

func progress_count() -> int:
	return _count_present(Rules.REPRESENTATIVE_IDS)

func installed_count() -> int:
	return _count_present(Rules.BUILD_IDS)

func automatic_count() -> int:
	var count := 0
	for representative in Rules.REPRESENTATIVE_IDS:
		count += _count_present(Rules.AUTO_GROUPS[representative])
	return count

func _count_present(ids: Array) -> int:
	var count := 0
	for id in ids:
		if Rules.connection_attached(id, placed):
			count += 1
	return count

func is_stable() -> bool:
	return not failed and pending_group.is_empty() and progress_count() == Rules.REPRESENTATIVE_IDS.size() and bool(Rules.validate(placed).ok)

## Fit is judged for the whole level only, after every automatic group seats.
func assess_fit() -> Dictionary:
	if failed: return _failure.duplicate(true)
	if not pending_group.is_empty():
		return Rules.result(false, "assembling", "同类构件尚未全部装妥，完成整关后再检查。")
	var outcome: Dictionary = Rules.validate(placed)
	if outcome.code in ["unstable_length", "unstable_fit"]:
		failed = true
		completed = false
		pending_group = ""
		_failure = outcome.duplicate(true)
		changed.emit()
	return outcome

func validate_structure() -> Dictionary:
	if failed: return _report(_failure.duplicate(true))
	if not pending_group.is_empty():
		return _assembling()
	var outcome: Dictionary = assess_fit()
	if outcome.ok:
		if completed:
			return _report(Rules.result(true, "already_complete", "骨架已经验收通过，可以撤回一组练习或重新挑战。"))
		completed = true
		changed.emit()
	return _report(outcome)

func _remove(id: String) -> Dictionary:
	var removed_ids: Array[String] = [id]
	placed.erase(id)
	for automatic_id in Rules.AUTO_GROUPS.get(id, []):
		if placed.has(automatic_id):
			removed_ids.append(automatic_id)
		placed.erase(automatic_id)
	placement_order.erase(id)
	pending_group = ""
	selected = id
	completed = false
	changed.emit()
	var outcome: Dictionary = Rules.result(true, "removed", "已取回这一组构件，可以重新观察榫型并示范。")
	outcome["piece_id"] = id
	outcome["removed_ids"] = removed_ids
	return _report(outcome)

func _assembling() -> Dictionary:
	return _report(Rules.result(false, "assembling", "同类构件正在自动装配，请稍候，或撤回本次示范。"))

func _failed() -> Dictionary:
	return _report(Rules.result(false, "failed", "本关未通过，请重新开始。"))

func _report(outcome: Dictionary) -> Dictionary:
	feedback.emit(str(outcome.message))
	return outcome
