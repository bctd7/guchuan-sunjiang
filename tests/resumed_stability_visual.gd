extends "res://tests/resumed_level01_visual.gd"
## Focused presentation fixture; assembly input is covered by the full GPU suite.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"real no-focus GPU surface")
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	campaign.open_level(1)
	level=campaign.current_chapter
	level.learning.start_button.pressed.emit()
	for id in level.Rules.REPRESENTATIVE_IDS:
		level.state.attempt_place(id,id,level.Rules.expected_joint(id),"long")
		for mate in level.Rules.AUTO_GROUPS[id]: level.state.place_automatic(mate)
		level.state.finish_automatic()
	level._check()
	check(level.checking_stability and level.panel.stage_label.text.contains("检查"),"inspection is not labelled as automatic assembly")
	await settle(.25)
	await capture("10-stability-check-status")
	await wait_motion()
	check(not level.checking_stability and not level.state.completed,"inspection returns to an uncompleted editable state")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"method":"Actual GPU focused presentation fixture with scripted assembly setup. Full real-pointer workflow reported separately.","no_focus":true,"host_had_focus":root.has_focus()}
	FileAccess.open(OUTPUT+"stability-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STABILITY_VISUAL ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
