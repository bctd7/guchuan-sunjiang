extends "res://tests/resumed_level01_visual.gd"
## Chapter-two story UI, exercised through actual Viewport pointer events.
var gpu := false
const OUT := "res://tests/evidence/bulkhead-story/"
func snapshot(name: String) -> void:
	if not gpu: return
	RenderingServer.force_draw(false)
	var path := OUT + name + ".png"
	check(surface.get_texture().get_image().save_png(path) == OK, "GPU image " + name)
	images.append(path)
func run() -> void:
	gpu = DisplayServer.get_name() != "headless"
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	if gpu:
		root.mode = Window.MODE_MINIMIZED
		for attempt in 20:
			await settle(.05)
			if root.mode == Window.MODE_MINIMIZED: break
			root.mode = Window.MODE_MINIMIZED
		check(root.mode == Window.MODE_MINIMIZED, "minimized no-focus GPU host")
		if root.mode != Window.MODE_MINIMIZED:
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	surface = SubViewport.new()
	surface.size = Vector2i(1440, 900)
	surface.own_world_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign = load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.2)
	await button(campaign.chapter_buttons[2])
	level = campaign.current_chapter
	await button(level.learning.start_button)
	var before: Dictionary = level.state.placed.duplicate(true)
	var selected: String = level.state.selected
	var camera_before: Transform3D = level.view.camera.transform
	await button(level.panel.bulkhead_button)
	var story: CanvasLayer = level.bulkhead_lesson
	check(story.opened and not level.interaction.is_processing_input(), "story entry suspends assembly input")
	check(story.close_button.text == "关闭", "existing return action retained")
	check(story.root.find_children("*", "Button", true, false).size() == 1, "one return action")
	var illustration: Control = story.root.find_child("StoryIllustration", true, false)
	var scroll: ScrollContainer = story.root.find_child("StoryScroll", true, false)
	var last: Label = story.root.find_child("StoryParagraph4", true, false)
	check(illustration.ART.get_width() >= 1600, "full-resolution chapter-two story art")
	var paragraphs: Array = story.root.find_children("StoryParagraph*", "Label", true, false)
	check(paragraphs.size() == story.STORY_PARAGRAPHS.size(), "all four original paragraphs")
	for i in paragraphs.size():
		check(paragraphs[i].text == story.STORY_PARAGRAPHS[i], "unchanged paragraph " + str(i))
	for dimensions in [Vector2i(1920, 1080), Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1100, 700), Vector2i(960, 600), Vector2i(768, 900)]:
		surface.size = dimensions
		scroll.scroll_vertical = 0
		await settle(.15)
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(viewport.encloses(story.close_button.get_global_rect()), "return button fits " + str(dimensions))
		check(viewport.encloses(scroll.get_global_rect()), "reading viewport fits " + str(dimensions))
		check(illustration.get_global_rect().size.x<=scroll.size.x, "image width fits reading area " + str(dimensions))
		check(scroll.is_ancestor_of(illustration), "image shares reading scroll " + str(dimensions))
		check(absf(illustration.size.y - illustration.size.x * float(illustration.ART.get_height()) / illustration.ART.get_width()) <= 1, "uncropped image ratio " + str(dimensions))
		check(story.root.get_script()==preload("res://components/ui/story_panel.gd"), "shared first-chapter layout")
		await snapshot("story-" + str(dimensions.x))
		var bar := scroll.get_v_scroll_bar()
		for step in 80:
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
		check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "whole final paragraph readable " + str(dimensions))
		await snapshot("story-" + str(dimensions.x) + "-bottom")
	await button(story.close_button)
	check(not story.opened and level.interaction.is_processing_input(), "return restores assembly input")
	check(before == level.state.placed and selected == level.state.selected and not level.state.completed, "story leaves assembly state unchanged")
	check(level.view.camera.transform == camera_before, "story leaves camera unchanged")
	surface.size = Vector2i(1440, 900)
	await settle()
	await button(level.panel.bulkhead_button)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	surface.push_input(escape, true)
	await process_frame
	check(not story.opened and level.interaction.is_processing_input(), "Escape restores ship input")
	var report := {"passed": passed, "failed": failures.size(), "failures": failures, "images": images, "renderer": DisplayServer.get_name(), "host_minimized": root.mode == Window.MODE_MINIMIZED, "no_focus_flag": root.get_flag(Window.FLAG_NO_FOCUS)}
	FileAccess.open(OUT + ("gpu-report.json" if gpu else "headless-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("BULKHEAD_STORY ", passed, " passed; ", failures.size(), " failed")
	surface.free()
	quit(0 if failures.is_empty() else 1)
