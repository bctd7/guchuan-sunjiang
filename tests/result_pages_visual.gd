extends "res://tests/exhibition_visual.gd"
const DEST="res://tests/evidence/results/"
func shot(label: String, result) -> void:
	await settle()
	check(result.is_visible_in_tree(),label+" visible")
	check(result.preview.model_root.get_child_count()==1,label+" snapshot")
	check(result.preview.model_root.get_child(0).get_child_count()>0,label+" real meshes")
	check(campaign.instances[campaign.active_level].navigation_status().modal_open,label+" modal navigation")
	for b in [result.restart_button,result.return_button]:
		if b.is_visible_in_tree():check(Rect2(0,0,1920,1080).encloses(b.get_global_rect()),label+" button on screen")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false);surface.get_texture().get_image().save_png(DEST+label+".png")
func fill(level, n: int, wrong: bool=false) -> void:
	if n==1:
		for id in level.Rules.BUILD_IDS:level.state.placed[id]={"socket":id,"joint":level.Rules.expected_joint(id),"length":"short" if wrong and id=="rib_l1" else "correct","automatic":false}
		level._refresh();level._check()
	elif n==2:
		for id in level.Rules.IDS:
			var row=level.Rules.row_for(id)
			level.state.placed[id]={"joint":level.Rules.expected(id),"opening":"A" if wrong and id.begins_with("plank") else level.state.Openings.target(id),"layout":"B" if row==1 else "A"}
			level.state.layouts[row]="B" if row==1 else "A"
		level._refresh();level._check()
		if is_instance_valid(level.view.trial.motion):level.view.trial.motion.set_speed_scale(30)
	else:
		for group in level.state.Rules.STAGES:level.state.placed.append_array(group)
		level.state.stage_idx=2;level.state.selected="blade";level.state.changed.emit()
		level._turn(-30);level._turn(30)
	await create_timer(1).timeout
	await settle()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle()
	await click(campaign.chapter_buttons[1])
	for n in [1,2,3]:
		check(campaign.active_level==n,"next chapter route "+str(n))
		var level=campaign.instances[n]
		await click(level.learning.start_button)
		if n<3:
			await fill(level,n,true);await shot(str(n)+"-failure",level.panel.failure_overlay)
			# Let first chapter's instability animation complete before restart.
			await create_timer(2).timeout
			await click(level.panel.failure_restart_button)
			check(not level.state.failed and not level.panel.failure_overlay.visible,"restart clears failure "+str(n))
		await fill(level,n);await shot(str(n)+"-success",level.panel.success_panel)
		check(level.state.completed,"real validation completed "+str(n))
		await click(level.panel.success_panel.restart_button)
	check(campaign.active_level==0 and campaign.menu.visible,"third result returns to directory")
	await click(campaign.chapter_buttons[3]);check(not campaign.instances[3].state.completed,"directory reentry fresh")
	campaign._show_menu()
	FileAccess.open(DEST+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"method":"Seeded actual assembly records; real verdict/sea-trial/rudder callbacks; viewport mouse clicks for restart/next/directory. Not full manual assembly or physical touchscreen."},"  "))
	print("RESULT_PAGES ",JSON.stringify(failures));campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
