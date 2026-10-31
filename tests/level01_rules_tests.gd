extends SceneTree

const State = preload("res://levels/level01/level_state.gd")
const Rules = preload("res://levels/level01/connection_rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_initial_and_rejections()
	_test_demonstrations()
	_test_interrupted_assembly()
	_test_complete_withdrawal()
	_test_reset_isolation()
	_test_foundation_recovery()
	_test_connection_integrity()
	_test_pending_group_withdrawal()
	var report := {"passed":checks - failures.size(), "failed":failures.size(), "failures":failures}
	var file := FileAccess.open("res://tests/level01_rules_report.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print("LEVEL01_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_initial_and_rejections() -> void:
	var state = State.new()
	check(Rules.IDS.size() == 11 and Rules.BUILD_IDS.size() == 10 and Rules.REPRESENTATIVE_IDS.size() == 3, "eleven entities, ten members, three demonstrations")
	check(state.stage() == "ribs" and state.selected == "rib_l1" and state.pending_group == "", "starts at first demonstration")
	check(state.placed == Rules.initial_connections() and state.placement_order.is_empty(), "fixed base outside undo history")
	check(state.progress_count() == 0 and state.installed_count() == 0 and state.automatic_count() == 0, "fixed base excluded from all counters")
	check(state.undo().code == "nothing_to_undo" and state.placed.has("keel"), "empty undo preserves foundation")
	check(state.select_piece("keel").code == "fixed_foundation", "foundation cannot be selected")
	check(state.remove_piece("keel").code == "fixed_foundation", "foundation cannot be removed")
	check(state.attempt_place("keel", "keel").code == "fixed_foundation", "foundation cannot be installed")
	check(state.attempt_place("missing", "rib_l1").code == "unknown_piece", "unknown piece rejected")
	check(state.attempt_place("rib_l1", "missing").code == "unknown_socket", "unknown socket rejected")
	check(state.attempt_place("rib_l1", "rib_r1").code == "wrong_socket", "left right mixup rejected")
	check(state.attempt_place("bow", "bow").code == "needs_ribs", "braces need all ribs")
	check(state.place_automatic("rib_r1").code == "no_pending_group", "automatic placement needs demonstration")
	check(state.finish_automatic().code == "no_pending_group", "no phantom group completion")
	for representative in Rules.REPRESENTATIVE_IDS:
		var flattened: Array=[]
		for batch in Rules.AUTO_BATCHES[representative]:
			check(batch.size()==1,"automatic batch contains one independently animated member "+representative)
			flattened.append_array(batch)
		check(flattened==Rules.AUTO_GROUPS[representative],"automatic batches preserve declared member order "+representative)
		var prepared = State.new()
		if representative != "rib_l1": _demonstrate(prepared, "rib_l1")
		var snapshot: Dictionary = prepared.placed.duplicate(true)
		for joint in ["base", "bogus"]:
			for retry in range(2):
				check(prepared.attempt_place(representative, representative, joint).code == "unsupported_joint", representative + " repeated unsupported joint " + joint + str(retry))
		for length in ["bogus", ""]:
			check(prepared.attempt_place(representative, representative, Rules.expected_joint(representative), length).code == "unsupported_length", representative + " unsupported length rejects " + length)
		check(prepared.placed == snapshot and prepared.pending_group.is_empty(), representative + " rejected attempts do not mutate")
	for representative in Rules.REPRESENTATIVE_IDS:
		for id in Rules.AUTO_GROUPS[representative]:
			check(state.attempt_place(id, id).code == "automatic_piece", id + " cannot be manually installed")
			check(state.select_piece(id).code == "automatic_piece", id + " cannot be manually selected")
	check(state.placed == Rules.initial_connections() and state.placement_order.is_empty(), "all rejection paths preserve initial state")

func _test_demonstrations() -> void:
	var state = State.new()
	for representative in Rules.REPRESENTATIVE_IDS:
		var installed_before: int = state.installed_count()
		check(state.select_piece(representative).ok, "select representative " + representative)
		check(state.attempt_place(representative, representative, Rules.expected_joint(representative)).ok, "manual demonstration " + representative)
		check(state.pending_group == representative and state.installed_count() == installed_before + 1, "only representative initially installed " + representative)
		check(not state.placed[representative].automatic and state.placement_order.back() == representative, "manual history " + representative)
		check(state.finish_automatic().code == "incomplete_automatic" and state.pending_group == representative, "missing automatic members cannot finish " + representative)
		var snapshot: Dictionary = state.placed.duplicate(true)
		check(state.attempt_place("bow", "bow").code == "assembling", "manual placement gated " + representative)
		check(state.select_piece("beam1").code == "assembling", "selection gated " + representative)
		check(state.validate_structure().code == "assembling" and not state.completed and not state.is_stable(), "inspection gated " + representative)
		check(state.place_automatic("keel").code == "wrong_group" and state.placed == snapshot, "wrong automatic group rejected " + representative)
		if representative == "rib_l1":
			check(state.place_automatic("rib_l2").code == "automatic_order", "later rib batch cannot precede partner")
		for id in Rules.AUTO_GROUPS[representative]:
			check(state.place_automatic(id).ok, "automatic placement " + id)
			check(state.placed[id].automatic and state.placed[id].demonstrated_by == representative, "automatic provenance " + id)
			check(state.remove_piece(id).code == "automatic_piece", "automatic member cannot be individually removed " + id)
			check(state.place_automatic(id).code == "already_placed", "duplicate automatic member rejected " + id)
		check(state.validate_structure().code == "assembling", "full group still awaits animation completion " + representative)
		check(state.finish_automatic().ok and state.pending_group.is_empty(), "finish group " + representative)
		check(state.attempt_place(representative, representative).code == "already_placed", "duplicate representative rejected " + representative)
	check(state.progress_count() == 3 and state.automatic_count() == 7 and state.installed_count() == 10 and state.placed.size() == 11, "three demonstrations plus seven automatic members preserve full physical structure")
	check(state.placement_order == Rules.REPRESENTATIVE_IDS, "only three representatives enter history")
	check(state.is_stable() and not state.completed, "explicit inspection still required")
	check(state.remove_piece("rib_l1").code == "dependents", "braces protect rib group")
	check(state.validate_structure().ok and state.completed and state.stage() == "complete", "inspection completes intact eleven entity structure")
	check(state.validate_structure().code == "already_complete", "repeat inspection idempotent")
	check(state.attempt_place("bow", "bow").code == "complete", "completed placement blocked")

func _test_interrupted_assembly() -> void:
	var state = State.new()
	check(state.attempt_place("rib_l1", "rib_l1").ok, "test default joint remains available to rules")
	check(state.place_automatic("rib_r1").ok, "partial automatic batch")
	var removed: Dictionary = state.undo()
	check(removed.ok and removed.removed_ids == ["rib_l1", "rib_r1"], "undo removes partial group together")
	check(state.placed == Rules.initial_connections() and state.pending_group.is_empty() and state.placement_order.is_empty(), "interrupted undo clears pending and history")
	check(state.place_automatic("rib_l2").code == "no_pending_group", "stale automatic placement refused after interruption")
	_demonstrate(state, "rib_l1")
	check(state.stage() == "braces" and state.installed_count() == 6, "interrupted group can be retried completely")
	check(state.attempt_place("bow", "bow").ok, "begin brace group")
	check(state.remove_piece("bow").ok and state.pending_group.is_empty() and state.installed_count() == 6, "remove also interrupts current group")
	_demonstrate(state, "bow")
	_demonstrate(state, "beam1")
	check(state.validate_structure().ok, "interrupted session can complete")

func _test_complete_withdrawal() -> void:
	var state = State.new()
	_full_build(state)
	state.validate_structure()
	var reversed := Rules.REPRESENTATIVE_IDS.duplicate()
	reversed.reverse()
	for representative in reversed:
		var result: Dictionary = state.undo()
		check(result.ok and result.piece_id == representative and not state.completed and not state.is_stable(), "reverse group withdrawal " + representative)
		for id in Rules.AUTO_GROUPS[representative]: check(not state.placed.has(id), "withdraw group automatic member " + id)
	check(state.stage() == "ribs" and state.progress_count() == 0 and state.installed_count() == 0 and state.automatic_count() == 0 and state.placed == Rules.initial_connections(), "full withdrawal returns to fixed base")
	check(state.undo().code == "nothing_to_undo", "fixed base never enters undo history")
	_full_build(state)
	check(state.validate_structure().ok, "full withdrawal can be rebuilt")

func _test_reset_isolation() -> void:
	var first = State.new()
	var second = State.new()
	_full_build(first)
	first.validate_structure()
	second.attempt_place("rib_l1", "rib_l1")
	second.place_automatic("rib_r1")
	first.reset()
	check(first.placed == Rules.initial_connections() and first.placement_order.is_empty() and first.selected == "rib_l1" and first.pending_group.is_empty() and not first.completed, "reset clears all installed members, history and completion")
	check(second.progress_count() == 1 and second.automatic_count() == 1 and second.pending_group == "rib_l1", "reset isolated from another instance")
	check(not first.undo().ok and not first.validate_structure().ok, "reset cannot resurrect stale history or victory")
	second.reset()
	check(second.placed == Rules.initial_connections() and second.pending_group.is_empty(), "reset clears partially assembled group")
	_full_build(first)
	check(first.validate_structure().ok, "reset replay succeeds")

func _test_foundation_recovery() -> void:
	var first = State.new()
	var second = State.new()
	first.placed.keel.fixed = false
	check(second.placed.keel.fixed, "foundation dictionaries isolated")
	check(first.attempt_place("rib_l1", "rib_l1").code == "invalid_connection", "damaged foundation cannot accept installation")
	check(first.validate_structure().code == "invalid_connection", "damaged foundation cannot pass inspection")
	first.reset()
	check(first.placed == Rules.initial_connections(), "reset repairs foundation metadata")
	first.placed.erase("keel")
	check(first.validate_structure().code == "needs_keel", "missing foundation fails validation")
	check(first.attempt_place("rib_l1", "rib_l1").code == "needs_keel", "missing foundation blocks demonstration")
	first.reset()
	check(first.placed == Rules.initial_connections() and first.attempt_place("rib_l1", "rib_l1").ok, "reset repairs missing foundation")

func _test_connection_integrity() -> void:
	for field in ["socket", "joint", "length"]:
		var state = State.new()
		_full_build(state)
		state.placed.rib_r1[field] = "bogus"
		check(not state.is_stable() and not state.validate_structure().ok, "all automatic rib connection fields validated " + field)
	var state = State.new()
	_full_build(state)
	state.placed.erase("bow")
	check(not state.validate_structure().ok, "all three representatives required")
	state.reset()
	state.attempt_place("rib_l1", "rib_l1")
	state.placed.erase("keel")
	check(state.place_automatic("rib_r1").code == "needs_keel", "automatic path retains support validation")
	var spec: Dictionary = Rules.piece_spec("keel")
	spec.label = "mutated"
	check(Rules.SPECS.keel.label != "mutated", "piece specification accessor isolated")

func _demonstrate(state, representative: String) -> void:
	check(state.attempt_place(representative, representative, Rules.expected_joint(representative)).ok, "build representative " + representative)
	for id in Rules.AUTO_GROUPS[representative]: check(state.place_automatic(id).ok, "build automatic " + id)
	check(state.finish_automatic().ok, "build finish " + representative)

func _full_build(state) -> void:
	for representative in Rules.REPRESENTATIVE_IDS: _demonstrate(state, representative)

func _test_pending_group_withdrawal() -> void:
	var state=State.new()
	_demonstrate(state,"rib_l1")
	_demonstrate(state,"bow")
	state.attempt_place("beam1","beam1","through_tenon")
	var before: Dictionary=state.placed.duplicate(true)
	check(state.remove_piece("bow").code=="assembling" and state.placed==before and state.pending_group=="beam1","removing an older group cannot strand current automatic work")
	check(state.undo().ok and state.pending_group.is_empty() and state.progress_count()==2,"current pending group can still be withdrawn safely")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
