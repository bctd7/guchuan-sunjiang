extends SceneTree
## Trial assembly accepts all nine known choices; inspection judges their fit.
const State = preload("res://levels/level01/level_state.gd")
const Rules = preload("res://levels/level01/connection_rules.gd")
var checks := 0
var failures: Array[String] = []
var mixed_combinations := 0

func _initialize() -> void:
	_test_target_matrix_and_correction()
	_test_all_mixed_combinations()
	_test_rejections_and_foundation()
	_test_partial_undo_and_reset()
	_test_legacy_empty_joint()
	var report := {"passed":checks - failures.size(), "failed":failures.size(), "failures":failures, "target_choices":27, "mixed_combinations":mixed_combinations}
	var file := FileAccess.open("res://tests/level01_trial_rules_report.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print("LEVEL01_TRIAL_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_target_matrix_and_correction() -> void:
	for target in Rules.REPRESENTATIVE_IDS:
		for joint in Rules.JOINT_TYPES:
			for length in Rules.LENGTHS:
				var state = State.new()
				var context: String = target + "/" + joint + "/" + length
				var choices: Array = []
				for representative in Rules.REPRESENTATIVE_IDS:
					var choice := {"joint":joint if representative == target else Rules.expected_joint(representative), "length":length if representative == target else "correct"}
					choices.append(choice)
					_assemble(state, representative, choice.joint, choice.length, context)
				_check_inspection(state, choices, context)
				var before: Dictionary = state.placed.duplicate(true)
				var duplicate: Dictionary = state.attempt_place(target, target, joint, length)
				check(duplicate.code == ("complete" if state.completed else "already_placed") and state.placed == before, context + " duplicate cannot overwrite trial choice")
				if target == "rib_l1":
					check(state.remove_piece(target).code == "dependents" and state.placed == before, context + " ribs retain dependent protection")
					check(state.undo().piece_id == "beam1" and state.undo().piece_id == "bow", context + " later groups undo in order")
				var removed: Dictionary = state.remove_piece(target)
				var expected_removed: Array = [target]
				expected_removed.append_array(Rules.AUTO_GROUPS[target])
				check(removed.ok and removed.removed_ids == expected_removed, context + " whole trial group can be taken back")
				check(not state.completed and not state.is_stable() and state.pending_group.is_empty(), context + " taking back reopens play")
				_assemble(state, target, Rules.expected_joint(target), "correct", context + " corrected")
				if target == "rib_l1":
					_assemble(state, "bow", Rules.expected_joint("bow"), "correct", context + " restore bow")
					_assemble(state, "beam1", Rules.expected_joint("beam1"), "correct", context + " restore beam")
				check(state.validate_structure().ok and state.completed and state.is_stable(), context + " corrected fit succeeds")
				check(state.progress_count() == 3 and state.automatic_count() == 7 and state.installed_count() == 10, context + " correction restores all counts")

func _test_all_mixed_combinations() -> void:
	var candidates: Array = []
	for joint in Rules.JOINT_TYPES:
		for length in Rules.LENGTHS: candidates.append({"joint":joint, "length":length})
	for rib in candidates:
		for bow in candidates:
			for beam in candidates:
				var state = State.new()
				var choices := [rib, bow, beam]
				var context := "mixed " + str(mixed_combinations)
				for i in range(Rules.REPRESENTATIVE_IDS.size()):
					var representative: String = Rules.REPRESENTATIVE_IDS[i]
					_assemble(state, representative, choices[i].joint, choices[i].length, context)
					if i == 0:
						check(state.stage() == "braces" and Rules.ribs_attached(state.placed), context + " trial ribs support later braces")
						check(Rules.ribs_correct(state.placed) == (rib.joint == "blind_tenon" and rib.length == "correct"), context + " rib attachment distinct from correctness")
				_check_inspection(state, choices, context)
				check(state.placement_order == Rules.REPRESENTATIVE_IDS and state.placed.size() == 11, context + " three manual history entries and eleven physical records")
				mixed_combinations += 1
	check(mixed_combinations == 729, "all nine choices across three representative groups visited")

func _check_inspection(state, choices: Array, context: String) -> void:
	var unstable_groups: Array[String] = []
	var unstable_pieces: Array[String] = []
	var unstable_reasons: Dictionary = {}
	var reasons: Array[String] = []
	for i in range(Rules.REPRESENTATIVE_IDS.size()):
		var representative: String = Rules.REPRESENTATIVE_IDS[i]
		var piece_reasons: Array[String] = []
		if choices[i].joint != Rules.expected_joint(representative): piece_reasons.append("wrong_joint")
		if choices[i].length != "correct": piece_reasons.append("wrong_length")
		if piece_reasons.is_empty(): continue
		unstable_groups.append(representative)
		var group: Array = [representative]
		group.append_array(Rules.AUTO_GROUPS[representative])
		for id in group:
			unstable_pieces.append(id)
			unstable_reasons[id] = piece_reasons
		for reason in piece_reasons:
			if not reason in reasons: reasons.append(reason)
	check(state.progress_count() == 3 and state.automatic_count() == 7 and state.installed_count() == 10, context + " every trial member counts as installed")
	var before: Dictionary = state.placed.duplicate(true)
	var outcome: Dictionary = state.validate_structure()
	check(state.placed == before, context + " inspection preserves trial records")
	if unstable_groups.is_empty():
		check(outcome.ok and outcome.code == "complete" and state.completed and state.is_stable(), context + " all correct passes")
		check(state.validate_structure().code == "already_complete", context + " success is idempotent")
	else:
		var expected_code := "unstable_fit" if "wrong_joint" in reasons else "unstable_length"
		check(not outcome.ok and outcome.code == expected_code and not state.completed and not state.is_stable(), context + " wrong fit fails final stability")
		check(outcome.get("unstable_groups", []) == unstable_groups and outcome.get("unstable_pieces", []) == unstable_pieces, context + " exact affected groups and members")
		check(outcome.get("unstable_reasons", {}) == unstable_reasons and outcome.get("reasons", []) == reasons, context + " exact wrong type and length reasons")
		check(state.validate_structure() == outcome and state.stage() == "braces", context + " failure remains repeatable and recoverable")
		check("取回" in str(outcome.message) and "松动" in str(outcome.message), context + " feedback explains looseness and taking back")

func _test_rejections_and_foundation() -> void:
	for joint in ["base", "bogus", "BLIND_TENON", " blind_tenon "]:
		var state = State.new()
		check(state.attempt_place("rib_l1", "rib_l1", joint, "correct").code == "unsupported_joint", "unknown teaching joint rejected " + joint)
		check(state.placed == Rules.initial_connections() and state.placement_order.is_empty(), "unsupported joint cannot mutate state")
	for joint in Rules.JOINT_TYPES:
		for length in Rules.LENGTHS:
			var state = State.new()
			check(state.attempt_place("bow", "bow", joint, length).code == "needs_ribs", "trial fit cannot bypass supports")
			check(state.attempt_place("rib_l1", "rib_r1", joint, length).code == "wrong_socket", "trial fit cannot bypass sockets")
			check(state.attempt_place("keel", "keel", joint, length).code == "fixed_foundation", "trial fit never changes keel")
	for field in ["socket", "joint", "length", "fixed"]:
		var state = State.new()
		state.placed.keel[field] = false if field == "fixed" else ("blind_tenon" if field == "joint" else "short")
		check(not Rules.connection_attached("keel", state.placed) and not Rules.connection_correct("keel", state.placed), "foundation attachment requires all exact metadata " + field)
		check(state.attempt_place("rib_l1", "rib_l1", "dovetail", "long").code == "invalid_connection" and state.validate_structure().code == "invalid_connection", "trial fit cannot relax foundation " + field)
	for field in ["socket", "joint", "length"]:
		var state = State.new()
		_assemble(state, "rib_l1", "dovetail", "correct", "corruption setup")
		state.placed.rib_r1[field] = "bogus"
		check(not Rules.connection_attached("rib_r1", state.placed) and state.validate_structure().code == "invalid_connection", "arbitrary metadata remains invalid " + field)

func _test_partial_undo_and_reset() -> void:
	for joint in ["dovetail", "through_tenon"]:
		for length in Rules.LENGTHS:
			var state = State.new()
			check(state.attempt_place("rib_l1", "rib_l1", joint, length).ok, "wrong type starts trial group")
			check(state.validate_structure().code == "assembling" and state.finish_automatic().code == "incomplete_automatic", "trial group retains pending gates")
			check(state.place_automatic("rib_l2").code == "automatic_order", "trial group retains auto sequence")
			check(state.place_automatic("rib_r1").ok and state.placed.rib_r1.joint == joint and state.placed.rib_r1.length == length, "partial auto inherits actual choice")
			var before: Dictionary = state.placed.duplicate(true)
			check(state.place_automatic("rib_r1").code == "already_placed" and state.placed == before, "duplicate auto preserves trial metadata")
			check(state.progress_count() == 1 and state.automatic_count() == 1 and state.installed_count() == 2, "partial wrong type counts attached pieces")
			check(state.undo().removed_ids == ["rib_l1", "rib_r1"] and state.placed == Rules.initial_connections(), "undo takes back partial trial group")
			check(state.place_automatic("rib_l2").code == "no_pending_group", "stale callback after trial undo rejected")
			_assemble(state, "rib_l1", joint, length, "reset full trial")
			check(state.validate_structure().code == "unstable_fit", "wrong type diagnosed before missing braces")
			state.reset()
			check(state.placed == Rules.initial_connections() and state.placement_order.is_empty() and state.pending_group.is_empty() and not state.completed, "reset clears trial metadata and history")
			check(state.progress_count() == 0 and state.automatic_count() == 0 and state.installed_count() == 0, "reset clears trial counters")
			state.attempt_place("rib_l1", "rib_l1", joint, length)
			state.place_automatic("rib_r1")
			state.reset()
			check(state.placed == Rules.initial_connections() and state.place_automatic("rib_l2").code == "no_pending_group", "reset cancels partial wrong type assembly")
			for representative in Rules.REPRESENTATIVE_IDS: _assemble(state, representative, Rules.expected_joint(representative), "correct", "reset correction")
			check(state.validate_structure().ok and state.is_stable(), "correct replay succeeds after reset")

func _test_legacy_empty_joint() -> void:
	for representative in Rules.REPRESENTATIVE_IDS:
		var state = State.new()
		if representative != "rib_l1": _assemble(state, "rib_l1", "blind_tenon", "correct", "legacy setup")
		check(Rules.evaluate(representative, representative, "", "correct", state.placed).ok, "legacy empty joint retains expected type semantics " + representative)
		check(state.attempt_place(representative, representative, "", "correct").ok and state.placed[representative].joint == Rules.expected_joint(representative), "legacy state path records expected type " + representative)

func _assemble(state, representative: String, joint: String, length: String, context: String) -> void:
	check(state.attempt_place(representative, representative, joint, length).ok, context + " accepts trial " + representative)
	check(state.pending_group == representative and state.placed[representative].joint == joint and state.placed[representative].length == length and not state.placed[representative].automatic, context + " manual records exact choice")
	var group: Array = [representative]
	group.append_array(Rules.AUTO_GROUPS[representative])
	for id in Rules.AUTO_GROUPS[representative]:
		check(state.place_automatic(id).ok, context + " auto accepts same trial " + id)
		check(state.placed[id].joint == joint and state.placed[id].length == length and state.placed[id].automatic and state.placed[id].demonstrated_by == representative, context + " auto inherits actual type length and provenance " + id)
	for id in group:
		check(Rules.connection_attached(id, state.placed) and Rules.connection_correct(id, state.placed) == (joint == Rules.expected_joint(id) and length == "correct"), context + " attached differs from correct " + id)
	check(state.finish_automatic().ok and state.pending_group.is_empty(), context + " finishes trial group")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
