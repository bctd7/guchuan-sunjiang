extends "res://tests/rib_repair_visual.gd"
const TRIAL_OUT="res://tests/evidence/trial-flow/"
var loose_samples: Array[Dictionary]=[]
func capture(label: String) -> void:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=TRIAL_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual pixels "+label)
	images.append(path)
func choose_trial(kind: String,length: String) -> void:
	var card: Button=level.inspector.joint_buttons[kind]
	await click(card.get_global_rect().position+Vector2(card.size.x*.5,55))
	await button(level.inspector.length_buttons[length])
	check(level.joint_type==kind and level.tenon_length==length,"whole model card explicitly chooses trial "+kind+length)
	check(level.inspector.orbit.assembly_enabled and is_equal_approx(level.inspector.orbit.preview_limit,1.0),"known candidates can all be dragged to trial")
func wait_review(wrong: bool,label: String) -> void:
	var start:=Time.get_ticks_msec()
	var near_seated:=false
	var loosened:=false
	var final: Transform3D=level.view.trial_pose(level.inspector.animated_piece_id,level.inspector.selected_length,level.inspector.selected_joint)
	while level.inspector.is_animating and Time.get_ticks_msec()-start<6000:
		var distance: float=level.inspector.animated_piece.position.distance_to(final.origin)
		if distance<.02:near_seated=true
		if near_seated and distance>.026:loosened=true
		# Inspect every rendered frame, rather than aliasing the 0.1 s pulses
		# with a timer that can skip the short contact/outward samples.
		await process_frame
	check(level.inspector.animation_finished and not level.inspector.retry_button.disabled,"trial animation finishes and exposes take-back")
	check(level.inspector.animated_piece.transform.is_equal_approx(final),"actual chosen geometry reaches its safe trial contact "+label)
	if wrong:
		check(loosened,"visible trial loosens after approaching contact "+label)
		check(not level.state.is_stable(),"trial is attached without being declared stable")
	loose_samples.append({"trial":label,"approached_contact":near_seated,"loosened":loosened,"wrong":wrong})
func attempt(kind: String,length: String,label: String,touch:=false) -> void:
	var id: String=level.state.selected
	await choose_trial(kind,length)
	await capture(label+"-before")
	await drag_body(touch,label)
	check(level.state.placed.has(id) and level.state.placed[id].joint==kind and level.state.placed[id].length==length,"drag accepts actual type and length "+label)
	if not level.state.placed.has(id):return
	await wait_review(not level.Rules.connection_correct(id,level.state.placed),label)
	await capture(label+"-after")
func take_back(id: String) -> void:
	await button(level.inspector.retry_button)
	check(not level.state.placed.has(id) and level.state.selected==id and level.inspector.observation_mode and not level.busy,"take-back returns to same candidate task "+id)
	check(level.joint_type.is_empty() and level.tenon_length.is_empty(),"take-back clears previous explicit choices")
func finish_group(kind: String) -> void:
	var id: String=level.state.selected
	await button(level.inspector.close_button)
	await super.wait_motion()
	for repeated in level.Rules.AUTO_GROUPS[id]:
		check(level.state.placed[repeated].joint==kind,"automatic wood retains chosen type "+repeated)
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"actual hidden no-focus GPU")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRIAL_OUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.25)
	await button(campaign.chapter_buttons[1])
	level=campaign.current_chapter
	await button(level.learning.start_button)
	record_autos=false
	for id in level.Rules.REPRESENTATIVE_IDS:
		await button(level.panel.inspect_button)
		var expected: String=level.Rules.expected_joint(id)
		var wrong_types: Array[String]=[]
		for kind in ["blind_tenon","dovetail","through_tenon"]:
			if kind!=expected:wrong_types.append(kind)
		for index in 2:
			await attempt(wrong_types[index],"correct" if index==0 else "long",id+"-"+wrong_types[index])
			await take_back(id)
		await attempt(expected,"short",id+"-short")
		await take_back(id)
		await attempt(expected,"correct",id+"-correct",id=="bow")
		await finish_group(expected)
	await button(level.panel.check_button)
	check(level.state.completed,"correct type and length complete after retries")
	level.panel.success_panel.hide()
	await capture("corrected-stable-section")
	await button(level.panel.restart_button)
	for id in level.Rules.REPRESENTATIVE_IDS:
		await button(level.panel.inspect_button)
		var wrong: String="through_tenon" if id=="bow" else "dovetail"
		await attempt(wrong,"correct",id+"-full-wrong-group")
		await finish_group(wrong)
	check(level.state.installed_count()==10 and level.state.automatic_count()==7,"wrong types can finish all trial placements")
	await button(level.panel.check_button)
	check(not level.state.completed and level.state.validate_structure().code=="unstable_fit","wrong types fail visible stability check instead of insertion")
	await capture("wrong-type-stability-check")
	await super.wait_motion()
	await button(level.panel.inspect_button)
	check(not level.inspector.observation_mode and level.inspector.retry_button.visible,"installed last connection can reopen for correction")
	await button(level.inspector.retry_button)
	check(level.state.progress_count()==2 and level.inspector.observation_mode,"post-check take-back removes actual last group")
	await button(level.inspector.close_button)
	for count in 2:await button(level.panel.undo_button)
	check(level.state.placed.size()==1 and not level.busy and level.view.animations.is_empty(),"all unstable trials can be withdrawn without losing foundation")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"loose_samples":loose_samples,"method":"Actual GPU frames and Viewport-dispatched mouse/touch path: whole-card choice, full-wood drag, wrong types/lengths animated and loose, take-back/retry, correct completion and full wrong-type stability failure. Hidden NO_FOCUS; not native Windows or physical touchscreen testing."}
	FileAccess.open(TRIAL_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIAL_FLOW_GPU ",passed," passed, ",failures.size()," failed; captures=",images.size())
	surface.free()
	quit(0 if failures.is_empty() else 1)
