extends "res://tests/resumed_level01_visual.gd"

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	await process_frame
	await process_frame
	for attempt in 20:
		if root.mode == Window.MODE_MINIMIZED: break
		await settle(.05)
	check(DisplayServer.get_name() != "headless" and root.mode == Window.MODE_MINIMIZED, "minimized GPU story rendering")
	if not failures.is_empty():
		quit(2)
		return
	var out := "res://tests/evidence/seven-stars/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	surface = SubViewport.new()
	surface.size = Vector2i(1440, 900)
	surface.own_world_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign = load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.2)
	await button(campaign.chapter_buttons[1])
	level = campaign.current_chapter
	await button(level.learning.start_button)
	await button(level.panel.lesson_button)
	check(level.story.opened, "existing optional story entry opens story")
	check(level.story.close_button.text == "关闭", "concise close action")
	check(level.story.root.find_children("*", "Button", true, false).size() == 1, "single close button")
	var scroll: ScrollContainer = level.story.root.find_children("*", "ScrollContainer", true, false)[0]
	var last_paragraph: Label = level.story.root.find_child("StoryParagraph%d" % level.story.STORY_PARAGRAPHS.size(), true, false)
	for dimensions in [Vector2i(1440, 900), Vector2i(1100, 700), Vector2i(960, 600)]:
		surface.size = dimensions
		scroll.scroll_vertical = 0
		await settle(.15)
		RenderingServer.force_draw(false)
		var path := out + "story-" + str(dimensions.x) + ".png"
		check(surface.get_texture().get_image().save_png(path) == OK, "story beginning pixels " + str(dimensions))
		images.append(path)
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(level.story.close_button.get_global_rect()), "fixed close button fits " + str(dimensions))
		var illustration: Control = level.story.root.find_child("StoryIllustration", true, false)
		check(absf(illustration.size.y - illustration.size.x * 821.0 / 1916.0) <= 1, "full uncropped illustration ratio " + str(dimensions))
		check(scroll.get_child(0).size.y > scroll.size.y, "expanded story supports scrolling " + str(dimensions))
		for step in 80:
			var bar := scroll.get_v_scroll_bar()
			if scroll.scroll_vertical >= bar.max_value - bar.page - 1: break
			for down in [true, false]:
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = down
				wheel.position = scroll.get_global_rect().get_center()
				wheel.global_position = wheel.position
				surface.push_input(wheel, true)
				await process_frame
		await settle(.1)
		RenderingServer.force_draw(false)
		check(scroll.scroll_vertical > 0 and scroll.get_global_rect().grow(1).encloses(last_paragraph.get_global_rect()), "complete final paragraph is readable after wheel scrolling " + str(dimensions))
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(level.story.close_button.get_global_rect()), "close remains visible after scrolling " + str(dimensions))
		var bottom := out + "story-" + str(dimensions.x) + "-bottom.png"
		check(surface.get_texture().get_image().save_png(bottom) == OK, "full story ending pixels " + str(dimensions))
		images.append(bottom)
	await button(level.story.close_button)
	check(not level.story.opened and not level.state.completed, "button closes scrolled story without changing assembly")
	await button(level.panel.lesson_button)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	surface.push_input(escape, true)
	await process_frame
	check(not level.story.opened, "Escape closes story after reopening")
	var report := {"renderer": DisplayServer.get_name(), "passed": passed, "failed": failures.size(), "failures": failures, "images": images, "host_minimized": root.mode == Window.MODE_MINIMIZED, "host_focus_reported": root.has_focus(), "no_focus_flag": root.get_flag(Window.FLAG_NO_FOCUS), "method": "Minimized GPU and Viewport GUI events; not native mouse."}
	FileAccess.open(out + "report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SEVEN_STARS_GPU ", passed, " passed; ", failures.size(), " failed")
	surface.free()
	quit(0 if failures.is_empty() else 1)
