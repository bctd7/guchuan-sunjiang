extends "res://tests/campaign_tests.gd"
## Viewport pointer regression for whole-level verdicts, modal actions and replay.
## Tween playback is accelerated; gameplay state is only read, never overwritten.
var cases := 0

func speed_up() -> void:
	for motion in level.view.animations.values(): motion.set_speed_scale(32)
	if "inspector" in level and is_instance_valid(level.inspector._motion): level.inspector._motion.set_speed_scale(32)

func finish_motion() -> void:
	var deadline := Time.get_ticks_msec()+5000
	while level.busy and Time.get_ticks_msec()<deadline:
		speed_up()
		if "inspector" in level and level.inspector.opened and not level.inspector.is_animating:
			await button(level.inspector.close_button)
		await process_frame
	await process_frame
	await process_frame
	check(not level.busy and level.view.animations.is_empty(),"all real insertion/inspection motion finishes")

func choose_trial(id: String, joint: String, length: String, early_close := false) -> void:
	check(level.state.selected==id,"flow selects representative "+id)
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons[joint])
	await button(level.inspector.length_buttons[length])
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position(id))
	check(level.state.placed.has(id) and level.busy,"trial starts actual insertion "+id)
	# Last representative and even last automatic member must finish animating.
	level.panel.check_requested.emit()
	check(not level.state.failed and not level.state.completed,"checking during insertion never ends the level")
	if early_close: await button(level.inspector.close_button)
	await finish_motion()

func good_group(id: String) -> void:
	await choose_trial(id,level.Rules.expected_joint(id),"correct")

func restart_failure() -> void:
	await button(level.panel.failure_restart_button)
	check(not level.state.failed and not level.state.completed and not level.panel.failure_overlay.visible,"restart clears verdict and modal")
	check(level.state.placed==level.Rules.initial_connections() and level.state.placement_order.is_empty(),"restart keeps only fixed keel")
	check(level.joint_type.is_empty() and level.tenon_length.is_empty() and level.state.selected=="rib_l1","restart clears selections and returns first task")
	check(level.interaction.is_processing_input() and level.interaction.is_processing_unhandled_input(),"restart restores world input")

func failure_is_locked() -> void:
	var before=level.state.placed.duplicate(true)
	level.panel.undo_requested.emit()
	level.panel.check_requested.emit()
	level.panel.lesson_requested.emit()
	if "inspector" in level:
		level.panel.inspect_requested.emit()
		level.inspector.install_requested.emit()
	else:
		level.panel.group_selected.emit(0)
	level.interaction.socket_requested.emit(level.state.selected)
	var escape=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	root.push_input(escape,true)
	await process_frame
	check(level.state.placed==before and level.state.failed and level.panel.failure_overlay.visible,"stale controls and Escape cannot alter failed run")
	check(not level.state.completed and not campaign.completed.get(campaign.active_level,false),"failed run cannot mark chapter complete")
	check(level.panel.failure_return_button.text=="回到关卡目录" and level.panel.failure_restart_button.text=="重新开始","failure presents both requested actions")

func run() -> void:
	root.size=Vector2i(1440,900)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	root.add_child(campaign)
	await settle(.1)
	await enter(1)
	for target in level.Rules.REPRESENTATIVE_IDS:
		for joint in level.Rules.JOINT_TYPES:
			for length in level.Rules.LENGTHS:
				var incorrect: bool=joint!=level.Rules.expected_joint(target) or length!="correct"
				for id in level.Rules.REPRESENTATIVE_IDS:
					await choose_trial(id,joint if id==target else level.Rules.expected_joint(id),length if id==target else "correct",cases%2==0)
					if id!="beam1":
						check(not level.state.failed and not level.state.completed and not level.panel.failure_overlay.visible,"partial level never shows fit verdict "+target+"/"+joint+"/"+length)
						check(not level.panel.count_label.text.contains("有误"),"partial progress does not reveal correctness")
						level.panel.check_requested.emit()
						check(not level.state.failed,"premature inspection cannot fail an incomplete level")
				check(level.state.installed_count()==10 and level.state.automatic_count()==7,"all ten members seat before verdict, including wrong choices")
				if incorrect:
					check(level.state.failed and level.panel.failure_overlay.visible and not level.inspector.opened,"complete wrong assembly automatically shows failure")
					await failure_is_locked()
					await restart_failure()
				else:
					check(level.state.completed and level.panel.success_panel.visible and campaign.completed.get(1,false),"complete correct assembly automatically passes")
					await button(level.panel.restart_button)
				cases+=1
	check(cases==27,"all 27 choices at three connection stages exercised through actual pointer events")
	await cancellation_and_directory()
	await second_chapter()
	var report={"passed":passed,"failed":failed,"failures":failures,"first_chapter_choices":cases,"method":"Godot Viewport pointer events; real Tween playback accelerated; gameplay state read only; no human hardware validation","chapter_three":"unchanged: invalid candidates rejected before attachment; steering completion retained"}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/whole-level-failure-r8")
	FileAccess.open("res://tests/evidence/whole-level-failure-r8/input-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WHOLE_LEVEL_FAILURE ",JSON.stringify(report))
	campaign.free()
	quit(0 if failed==0 else 1)

func cancellation_and_directory() -> void:
	# Cancel a real insertion and deliver its old callbacks into a new run.
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons.dovetail)
	await button(level.inspector.length_buttons.long)
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	var old_generation: int=level._motion_generation
	await button(level.inspector.close_button)
	await button(level.panel.restart_button)
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons.blind_tenon)
	await button(level.inspector.length_buttons.correct)
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	level._demonstration_finished("rib_l1",old_generation)
	level._next_automatic("rib_l1",old_generation)
	check(not level.state.failed and level.state.automatic_count()==0,"old insertion callbacks cannot enter the new run")
	await finish_motion()
	check(level.state.automatic_count()==5 and not level.state.failed,"replacement run finishes its own group")
	await button(level.panel.restart_button)
	await choose_trial("rib_l1","dovetail","long",true)
	var saved=level.state.placed.duplicate(true)
	await back()
	await enter(2)
	await place_l2("plank_0a")
	var second=level
	var second_saved=second.state.placed.duplicate(true)
	await back()
	await enter(1)
	check(level.state.placed==saved and not level.state.failed,"directory preserves unfinished wrong choices without a verdict")
	await good_group("bow")
	await good_group("beam1")
	check(level.state.failed,"finishing the retained wrong run triggers final failure")
	var first=level
	await button(level.panel.failure_return_button)
	check(campaign.active_level==0 and campaign.menu.visible,"failure directory action actually returns to chapter list")
	await enter(1)
	check(level==first and level.state.failed and level.panel.failure_overlay.visible,"failed run and modal persist across directory round trip")
	await restart_failure()
	check(second.state.placed==second_saved,"first chapter retry preserves second chapter progress")
	for id in level.Rules.REPRESENTATIVE_IDS: await good_group(id)
	check(level.state.completed and campaign.completed.get(1,false),"correct replay after failure passes normally")
	await button(level.panel.restart_button)
	# Restart during final failure shake invalidates all later callbacks.
	await choose_trial("rib_l1","blind_tenon","short",true)
	await good_group("bow")
	await button(level.panel.inspect_button)
	await button(level.inspector.joint_buttons.through_tenon)
	await button(level.inspector.length_buttons.correct)
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("beam1"))
	var deadline=Time.get_ticks_msec()+5000
	while not level.state.failed and Time.get_ticks_msec()<deadline:
		speed_up()
		if level.inspector.opened and not level.inspector.is_animating: await button(level.inspector.close_button)
		await process_frame
	check(level.state.failed and level.busy and level.view.animations.has("inspection"),"final failure modal is actionable during shake")
	if level.view.animations.has("inspection"): level.view.animations.inspection.set_speed_scale(1)
	await restart_failure()
	await settle(.25)
	check(not level.busy and level.view.animations.is_empty() and not level.panel.failure_overlay.visible,"restart during shake cancels old failure callbacks")

func hull_piece(id: String, aligned: bool) -> void:
	if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):return
	await HullNavigation.open_local(root,level,id)
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	await button(level.panel.opening_buttons[level.state.Openings.target(id)])
	var row: int=level.Rules.row_for(id)
	if row>0 and id.ends_with("a"):
		await button(level.panel.layout_buttons["A" if aligned or row==2 else "B"])
	await settle(.5)
	await HullPointer.drag(root,level.view,1.0)
	check(level.busy and not level.state.failed and not level.state.completed,"hull does not judge before real insertion finishes "+id)
	await finish_motion()
	if level.view.inspected:await button(level.panel.overview_button)
	if id!="bulkhead":
		check(not level.state.failed and not level.state.checked and not level.panel.failure_overlay.visible,"unfinished hull defers leak verdict "+id)

func second_chapter() -> void:
	await back()
	await enter(2)
	await button(level.panel.restart_button)
	for id in level.Rules.IDS: await hull_piece(id,true)
	check(level.state.failed and not level.state.completed and level.panel.failure_overlay.visible,"complete aligned hull automatically fails")
	await failure_is_locked()
	var second=level
	await button(level.panel.failure_return_button)
	check(campaign.menu.visible and campaign.active_level==0,"hull failure action returns to directory")
	await enter(2)
	check(level==second and level.state.failed and level.panel.failure_overlay.visible,"hull failed state persists on reentry")
	await button(level.panel.failure_restart_button)
	check(not level.state.failed and level.state.placed.is_empty() and level.state.observed.is_empty(),"hull restart clears whole failed run")
	for id in level.Rules.IDS: await hull_piece(id,false)
	check(level.state.completed and campaign.completed.get(2,false) and level.panel.success_panel.visible,"correct staggered hull passes after restart")
	await button(level.panel.restart_button)
	check(not campaign.completed.get(2,false),"hull restart clears only its chapter completion badge")
