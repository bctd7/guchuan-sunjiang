extends "res://tests/exhibition_visual.gd"
const DEST="res://tests/evidence/shared-chapter-ui/"
func shot(label: String) -> void:
	await settle();stage=label;audit(campaign)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		check(surface.get_texture().get_image().save_png(DEST+label+".png")==OK,"save "+label)
	images.append(label+".png")
func tap(point: Vector2) -> void:
	for down in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
		surface.push_input(event,true);await process_frame
	await settle()
	# Alternate physical input types after the touch-to-mouse deduplication window.
	await create_timer(.5).timeout
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle()
	for n in [1,2,3]:
		await click(campaign.chapter_buttons[n]);var level=campaign.instances[n]
		await click(level.learning.start_button)
		await shot(str(n)+"-main")
		var story=level.bulkhead_lesson if n==2 else level.story
		var before=level.state.placed.duplicate(true)
		var selected: String=level.state.selected
		var camera_before: Transform3D=level.view.camera.transform
		await click(level.panel.lesson_button if n==1 else (level.panel.bulkhead_button if n==2 else level.panel.story_button))
		check(story.opened and story.root.get_script()==preload("res://levels/shared/story_panel.gd"),"shared story "+str(n))
		await shot(str(n)+"-story")
		var scroll=story.root.scroll
		var p: Vector2=scroll.get_global_rect().get_center()
		var press=InputEventScreenTouch.new();press.position=p;press.index=0;press.pressed=true;surface.push_input(press,true);await process_frame
		for i in 6:
			var drag=InputEventScreenDrag.new();drag.position=p-Vector2(0,25*(i+1));drag.relative=Vector2(0,-25);drag.index=0;surface.push_input(drag,true);await process_frame
		var release=InputEventScreenTouch.new();release.position=p-Vector2(0,150);release.index=0;release.pressed=false;release.canceled=true;surface.push_input(release,true);await settle()
		check(scroll.scroll_vertical>0 or scroll.get_v_scroll_bar().max_value<=scroll.get_v_scroll_bar().page,"body touch scroll or short content "+str(n))
		scroll.scroll_vertical=10000;await shot(str(n)+"-story-bottom")
		await click(story.close_button)
		check(not story.opened and level.state.placed==before and level.state.selected==selected and level.view.camera.transform==camera_before,"story preserves state/camera "+str(n))
		await click(level.panel.lesson_button if n==1 else (level.panel.bulkhead_button if n==2 else level.panel.story_button))
		var esc=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true;surface.push_input(esc,true);await settle()
		check(not story.opened,"Esc closes story "+str(n))
		await click(level.panel.observe_button if n==2 else level.panel.inspect_button)
		await shot(str(n)+"-observe")
		if n<3:
			var ui=level.inspector if n==1 else level.panel
			await click(ui.joint_buttons.blind_tenon if n==1 else ui.joint_buttons.tongue_groove)
			var gallery=ui.joint_choices if n==1 else ui.gallery
			await click(gallery.inspect_buttons.values()[0]);await click(ui.magnifier.close_button)
			await click(ui.close_button if n==1 else ui.overview_button)
		else:
			var ui=level.panel
			var camera_size: float=level.view.camera.size
			await click(ui.zoom_bar.zoom_in)
			check(level.view.camera.size<camera_size,"third observer zoom")
			await click(ui.zoom_bar.reset_button)
			check(is_equal_approx(level.view.camera.size,camera_size),"third observer reset view")
			await click(ui.gallery.inspect_buttons.values()[0]);await shot("3-magnifier");await click(ui.magnifier.close_button)
			await click(ui.lesson_button);await click(level.learning.start_button)
			check(ui.inspected,"lesson returns to observer")
			await click(ui.candidate_buttons.clamp_head)
			await tap(level.view.socket_screen_position("zrail"))
			check(not level.state.placed.has("zrail"),"wrong type rejected")
			for id in ["zrail","leg","mast","apron","top","lbrace","rudder","blade"]:
				await click(ui.candidate_buttons[level.state.Rules.SPECS[id].joint])
				await tap(level.view.socket_screen_position(id))
				await create_timer(1.8).timeout
				check(level.state.placed.has(id),"touch installs "+id)
				if id in ["zrail","mast","top","blade"]:await shot("3-installed-"+id)
				if id!="blade":await click(ui.next_button)
			await click(ui.overview_button);await shot("3-helm")
			await click(ui.left_button);await click(ui.right_button)
			check(level.state.completed,"third chapter completes")
			await shot("3-success")
			await click(ui.success_panel.restart_button)
			await click(campaign.chapter_buttons[3])
			var fresh=campaign.instances[3]
			await click(fresh.learning.start_button)
			check(fresh.state.placed.is_empty() and not fresh.panel.inspected,"directory reentry resets")
		campaign._show_menu();await settle()
	FileAccess.open(DEST+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"images":images,"small_targets":small,"method":"1920x1080 GPU; viewport mouse/touch; complete chapter 3, story scroll/close and observer checks in chapters 1/2. Not hardware."},"  "))
	print("SHARED_CHAPTER_UI ",failures);campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
