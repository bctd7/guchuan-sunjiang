extends "res://tests/trial_flow_visual.gd"
const FINAL_OUT="res://tests/evidence/trial-fit-final/"
func capture(label: String) -> void:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=FINAL_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual final pixels "+label)
	images.append(path)
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"hidden no-focus GPU")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FINAL_OUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.25)
	await button(campaign.chapter_buttons[1])
	level=campaign.instances[1]
	await button(level.learning.start_button)
	record_autos=false
	for id in level.Rules.REPRESENTATIVE_IDS:
		await button(level.panel.inspect_button)
		var kind: String="through_tenon" if id=="bow" else "dovetail"
		await attempt(kind,"correct",id+"-trial",id=="bow")
		if id=="rib_l1":
			await take_back(id)
			await attempt(kind,"correct",id+"-retry")
		await finish_group(kind)
		check(level.panel.count_label.text.contains("待调整"),"installed wrong group is identified as needing adjustment")
	check(level.state.installed_count()==10 and level.state.automatic_count()==7,"all trial members animated and attached")
	await button(level.panel.check_button)
	check(not level.state.completed and level.state.validate_structure().code=="unstable_fit","stability check rejects wrong fit after trial")
	await super.wait_motion()
	await capture("unstable-frame-after-check")
	await button(level.panel.inspect_button)
	await button(level.inspector.retry_button)
	check(not level.state.placed.has("beam1") and level.inspector.observation_mode,"installed loose group can be reopened and removed")
	await button(level.inspector.close_button)
	await button(level.panel.restart_button)
	check(level.state.placed.size()==1 and level.joint_type.is_empty() and level.tenon_length.is_empty(),"reset leaves fixed foundation and no default choice")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"loose_samples":loose_samples,"method":"Final actual GPU frames; Viewport GUI mouse and touch dispatch, complete unstable groups, stability feedback, take-back and reset. Hidden NO_FOCUS. No native mouse or physical touchscreen."}
	FileAccess.open(FINAL_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIAL_FIT_FINAL_GPU ",passed," passed, ",failures.size()," failed; captures=",images.size())
	surface.free()
	quit(0 if failures.is_empty() else 1)
