extends SceneTree
## Installation accepts all three teaching lengths; inspection decides stability.
const State = preload("res://levels/level01/level_state.gd")
const Rules = preload("res://levels/level01/connection_rules.gd")
const LENGTHS := ["short", "correct", "long"]
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_all_length_combinations()
	_test_withdraw_and_correct_each_group()
	_test_wrong_joint_and_invalid_lengths()
	_test_pending_order_and_interruption()
	_test_corrupt_connections()
	_test_foundation_and_reset()
	var report := {"passed":checks - failures.size(), "failed":failures.size(), "failures":failures, "length_combinations":27}
	var file := FileAccess.open("res://tests/level01_length_rules_report.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print("LEVEL01_LENGTH_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_all_length_combinations() -> void:
	for rib_length in LENGTHS:
		for bow_length in LENGTHS:
			for beam_length in LENGTHS:
				var state = State.new()
				var lengths := [rib_length, bow_length, beam_length]
				var context := "/".join(lengths)
				var unstable_groups: Array[String] = []
				var unstable_pieces: Array[String] = []
				for i in range(3):
					var representative: String = Rules.REPRESENTATIVE_IDS[i]
					_assemble(state, representative, lengths[i], context)
					if lengths[i] != "correct":
						unstable_groups.append(representative)
						unstable_pieces.append(representative)
						unstable_pieces.append_array(Rules.AUTO_GROUPS[representative])
					if i == 0:
						check(state.stage() == "braces" and Rules.ribs_attached(state.placed), context + " all attached ribs unlock braces even at wrong length")
						check(Rules.ribs_correct(state.placed) == (rib_length == "correct"), context + " rib correctness is distinct from attachment")
				check(state.progress_count() == 3 and state.automatic_count() == 7 and state.installed_count() == 10, context + " counts all attached members")
				check(state.placement_order == Rules.REPRESENTATIVE_IDS and state.placed.size() == 11, context + " fixed keel plus three manual and seven auto")
				var before: Dictionary = state.placed.duplicate(true)
				var outcome: Dictionary = state.validate_structure()
				check(state.placed == before, context + " inspection preserves installed geometry records")
				if unstable_groups.is_empty():
					check(outcome.ok and outcome.code == "complete" and state.completed and state.is_stable(), context + " all correct passes explicit inspection")
					check(state.validate_structure().code == "already_complete", context + " completion is idempotent")
				else:
					check(not outcome.ok and outcome.code == "unstable_length" and not state.completed and not state.is_stable(), context + " attached wrong lengths fail final inspection")
					check(outcome.get("unstable_groups", []) == unstable_groups, context + " exact affected representative groups")
					check(outcome.get("unstable_pieces", []) == unstable_pieces, context + " exact affected manual and auto members")
					check(state.stage() == "failed" and state.failed and state.validate_structure() == outcome, context + " failed inspection ends the run until restart")

func _test_withdraw_and_correct_each_group() -> void:
	for wrong_group in Rules.REPRESENTATIVE_IDS:
		for length in ["short", "long"]:
			var state = State.new()
			for representative in Rules.REPRESENTATIVE_IDS:
				_assemble(state, representative, length if representative == wrong_group else "correct", "correction")
			var outcome: Dictionary = state.validate_structure()
			check(outcome.code == "unstable_length" and outcome.unstable_groups == [wrong_group], wrong_group + "/" + length + " isolated wrong group diagnosed")
			check(state.failed and state.undo().code == "failed" and state.remove_piece(wrong_group).code == "failed", "wrong length cannot be corrected within a failed run")
			state.reset()
			for representative in Rules.REPRESENTATIVE_IDS:
				_assemble(state, representative, "correct", "restart")
			check(state.validate_structure().ok and state.completed and not state.failed, "restart after wrong length can complete")
			# Successful runs still support taking a group back for practice.
			if wrong_group == "rib_l1":
				var before: Dictionary = state.placed.duplicate(true)
				check(state.remove_piece(wrong_group).code == "dependents" and state.placed == before, "wrong ribs cannot bypass installed brace dependencies")
				check(state.undo().piece_id == "beam1" and state.undo().piece_id == "bow", "undo removes later braces in reverse placement order")
			var removed: Dictionary = state.remove_piece(wrong_group)
			var expected_removed: Array = [wrong_group]
			expected_removed.append_array(Rules.AUTO_GROUPS[wrong_group])
			check(removed.ok and removed.removed_ids == expected_removed, wrong_group + " withdrawal removes complete affected group")
			check(state.pending_group.is_empty() and not state.completed and not state.is_stable(), wrong_group + " withdrawal reopens assembly")
			for id in expected_removed:
				check(not state.placed.has(id), wrong_group + " withdrawn member absent " + id)
			_assemble(state, wrong_group, "correct", "corrected")
			if wrong_group == "rib_l1":
				_assemble(state, "bow", "correct", "rebuild dependents")
				_assemble(state, "beam1", "correct", "rebuild dependents")
			check(state.progress_count() == 3 and state.automatic_count() == 7 and state.installed_count() == 10, wrong_group + " correction restores counts")
			check(state.validate_structure().ok and state.completed, wrong_group + "/" + length + " correction passes inspection")
			check(state.placed.keel == Rules.initial_connections().keel, "correction preserves immutable foundation")

func _test_wrong_joint_and_invalid_lengths() -> void:
	for representative in Rules.REPRESENTATIVE_IDS:
		var state = State.new()
		if representative != "rib_l1": _assemble(state, "rib_l1", "short", "wrong-joint setup")
		var before: Dictionary = state.placed.duplicate(true)
		for length in LENGTHS:
			for joint in ["base", "bogus"]:
				check(state.attempt_place(representative, representative, joint, length).code == "unsupported_joint", representative + "/" + length + " unsupported type rejected " + joint)
		for length in ["", "bogus", "SHORT", "medium", " correct "]:
			check(state.attempt_place(representative, representative, Rules.expected_joint(representative), length).code == "unsupported_length", representative + " invalid length rejected " + length)
		check(state.placed == before and state.pending_group.is_empty() and not state.placement_order.has(representative), representative + " all invalid attempts preserve state")
		_assemble(state, representative, "long", "valid after rejections")
		for length in LENGTHS:
			check(state.attempt_place(representative, representative, Rules.expected_joint(representative), length).code == "already_placed", representative + " duplicate cannot overwrite chosen length")
		check(state.placed[representative].length == "long", representative + " duplicate preserves original attached length")
	var state = State.new()
	for length in LENGTHS:
		check(state.attempt_place("bow", "bow", "dovetail", length).code == "needs_ribs", "length does not bypass rib prerequisite " + length)
		check(state.attempt_place("beam1", "beam1", "through_tenon", length).code == "needs_ribs", "length does not bypass beam prerequisite " + length)
		check(state.attempt_place("rib_l1", "rib_r1", "blind_tenon", length).code == "wrong_socket", "length does not bypass socket match " + length)
	check(state.attempt_place("unknown", "rib_l1", "", "short").code == "unknown_piece", "unknown piece remains rejected")
	check(state.attempt_place("rib_l1", "unknown", "", "long").code == "unknown_socket", "unknown socket remains rejected")

func _test_pending_order_and_interruption() -> void:
	for length in ["short", "long"]:
		var state = State.new()
		check(state.attempt_place("rib_l1", "rib_l1", "blind_tenon", length).ok, "wrong length starts pending rib group")
		check(state.validate_structure().code == "assembling" and state.select_piece("bow").code == "assembling", "wrong length keeps assembly interaction gate")
		check(state.finish_automatic().code == "incomplete_automatic", "wrong length still requires every auto member")
		check(state.place_automatic("rib_l2").code == "automatic_order", "wrong length still respects automatic seating order")
		check(state.place_automatic("stern").code == "wrong_group", "wrong length does not allow another auto group")
		check(state.place_automatic("rib_r1").ok and state.placed.rib_r1.length == length, "partial auto inherits wrong length")
		check(state.place_automatic("rib_r1").code == "already_placed", "partial auto duplicate rejected")
		check(state.remove_piece("rib_r1").code == "automatic_piece", "partial auto cannot be independently withdrawn")
		check(state.progress_count() == 1 and state.automatic_count() == 1 and state.installed_count() == 2, "partial counts use attached wrong lengths")
		var removed: Dictionary = state.undo()
		check(removed.removed_ids == ["rib_l1", "rib_r1"] and state.placed == Rules.initial_connections(), "partial wrong group undo removes both members")
		check(state.place_automatic("rib_l2").code == "no_pending_group", "stale auto callback cannot reinstall withdrawn wrong group")
		_assemble(state, "rib_l1", length, "replay")
		check(state.validate_structure().code == "incomplete" and not state.failed, "wrong length waits for the remaining braces")
		check(state.undo().ok, "unfinished wrong-length assembly can still be withdrawn")
		state.reset()
		_assemble(state, "rib_l1", length, "dependency setup before verdict")
		_assemble(state, "bow", "long", "dependency")
		check(state.attempt_place("beam1", "beam1", "through_tenon", "short").ok, "begin third wrong group")
		check(state.remove_piece("bow").code == "assembling", "older withdrawal cannot strand pending third group")
		check(state.undo().piece_id == "beam1" and state.pending_group.is_empty(), "pending third group can be withdrawn")
		check(state.remove_piece("rib_l1").code == "dependents", "remaining bow still protects ribs")
		check(state.undo().piece_id == "bow" and state.undo().piece_id == "rib_l1", "remaining undo follows actual dependency order")
		check(state.placed == Rules.initial_connections(), "full wrong assembly withdrawal preserves fixed keel")

func _test_corrupt_connections() -> void:
	for field in ["socket", "joint", "length"]:
		for id in ["rib_l1", "rib_r1", "bow", "stern", "beam1", "beam3"]:
			var state = State.new()
			for representative in Rules.REPRESENTATIVE_IDS: _assemble(state, representative, "correct", "integrity setup")
			state.placed[id][field] = "bogus"
			check(not Rules.connection_attached(id, state.placed) and not Rules.connection_correct(id, state.placed), "corruption breaks attachment " + id + "/" + field)
			check(state.validate_structure().code == "invalid_connection" and not state.completed and not state.is_stable(), "corruption fails inspection " + id + "/" + field)
	for length in ["short", "long"]:
		var state = State.new()
		state.attempt_place("rib_l1", "rib_l1", "blind_tenon", length)
		state.placed.rib_l1.length = "bogus"
		check(state.place_automatic("rib_r1").code == "invalid_demonstration" and state.finish_automatic().code == "invalid_demonstration", "invalid representative cannot generate auto members")
		check(state.undo().ok and state.placed == Rules.initial_connections(), "invalid pending demonstration remains recoverable by undo")

func _test_foundation_and_reset() -> void:
	var state = State.new()
	var other = State.new()
	for length in LENGTHS:
		check(state.attempt_place("keel", "keel", "base", length).code == "fixed_foundation", "keel never accepts manual length " + length)
	check(state.remove_piece("keel").code == "fixed_foundation" and state.undo().code == "nothing_to_undo", "foundation cannot be withdrawn")
	_assemble(other, "rib_l1", "long", "isolation")
	for representative in Rules.REPRESENTATIVE_IDS: _assemble(state, representative, "short", "reset setup")
	check(state.validate_structure().code == "unstable_length", "reset begins with installed unstable structure")
	state.reset()
	check(state.placed == Rules.initial_connections() and state.placement_order.is_empty() and state.pending_group.is_empty() and state.selected == "rib_l1" and not state.completed, "reset clears wrong lengths, history, selection and completion")
	check(state.progress_count() == 0 and state.automatic_count() == 0 and state.installed_count() == 0 and state.stage() == "ribs", "reset clears counters and restores first stage")
	check(other.installed_count() == 6 and other.placed.rib_l1.length == "long", "reset cannot mutate another state")
	state.attempt_place("rib_l1", "rib_l1", "blind_tenon", "long")
	state.place_automatic("rib_r1")
	state.reset()
	check(state.placed == Rules.initial_connections() and state.place_automatic("rib_l2").code == "no_pending_group", "reset cancels partially installed wrong group")
	for representative in Rules.REPRESENTATIVE_IDS: _assemble(state, representative, "correct", "post-reset replay")
	check(state.validate_structure().ok, "fresh correct replay succeeds after wrong lengths and reset")
	state.reset()
	state.placed.keel.length = "short"
	check(state.attempt_place("rib_l1", "rib_l1", "blind_tenon", "long").code == "invalid_connection" and state.validate_structure().code == "invalid_connection", "foundation requires correct length despite build member freedom")
	state.reset()
	state.placed.erase("keel")
	check(state.attempt_place("rib_l1", "rib_l1", "blind_tenon", "short").code == "needs_keel", "wrong length cannot bypass missing foundation")
	state.reset()
	check(state.placed == Rules.initial_connections(), "reset repairs foundation")

func _assemble(state, representative: String, length: String, context: String) -> void:
	check(state.attempt_place(representative, representative, Rules.expected_joint(representative), length).ok, context + " attaches " + representative + "/" + length)
	check(state.pending_group == representative and state.placed[representative].length == length and not state.placed[representative].automatic, context + " records manual choice " + representative)
	check(Rules.connection_attached(representative, state.placed) and Rules.connection_correct(representative, state.placed) == (length == "correct"), context + " distinguishes attachment from fit " + representative)
	for id in Rules.AUTO_GROUPS[representative]:
		check(state.place_automatic(id).ok, context + " automatically attaches " + id)
		check(state.placed[id].length == length and state.placed[id].automatic and state.placed[id].demonstrated_by == representative, context + " automatic inherits length and provenance " + id)
	check(state.finish_automatic().ok and state.pending_group.is_empty(), context + " finishes attached group " + representative)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
