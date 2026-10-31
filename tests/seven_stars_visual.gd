extends "res://tests/resumed_level01_visual.gd"
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"hidden no-focus story rendering")
	if not failures.is_empty():quit(2);return
	var out: String="res://tests/evidence/seven-stars/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await settle(.2);await button(campaign.chapter_buttons[1]);level=campaign.instances[1];await button(level.learning.start_button)
	await button(level.panel.lesson_button)
	check(level.story.opened,"existing optional story entry opens new card")
	for dimensions in [Vector2i(1440,900),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.15)
		await RenderingServer.frame_post_draw
		var path:=out+"story-"+str(dimensions.x)+".png"
		check(surface.get_texture().get_image().save_png(path)==OK,"story pixels "+str(dimensions))
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(level.story.close_button.get_global_rect()),"close button fits "+str(dimensions))
		images.append(path)
		if dimensions.x==960:
			var scroll: ScrollContainer=level.story.root.find_children("*","ScrollContainer",true,false)[0]
			for step in 4:
				for down in [true,false]:
					var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=down;wheel.position=scroll.get_global_rect().get_center();wheel.global_position=wheel.position;surface.push_input(wheel,true);await process_frame
			await settle(.1);await RenderingServer.frame_post_draw
			check(scroll.scroll_vertical>0,"small display can scroll to full story text")
			var bottom:=out+"story-960-scrolled.png";check(surface.get_texture().get_image().save_png(bottom)==OK,"full story text after wheel scroll");images.append(bottom)
	await button(level.story.close_button)
	check(not level.story.opened and not level.state.completed,"card returns to unchanged assembly")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"method":"No-focus hidden GPU and Viewport GUI events; not native mouse."}
	FileAccess.open(out+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SEVEN_STARS_GPU ",passed," passed; ",failures.size()," failed")
	surface.free();quit(0 if failures.is_empty() else 1)
