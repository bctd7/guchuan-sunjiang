extends "res://tests/exhibition_visual.gd"
## UI-driven stage assertions and GPU evidence at the exhibition resolution.
func verify_guide(guide: Control, target: Control, expected: String) -> void:
	check(guide.target==target,"target matches "+expected)
	check(guide.mouse_filter==Control.MOUSE_FILTER_IGNORE,"highlight never intercepts input")
	if target!=null and not target is Button:
		var cards: Dictionary=target.buttons
		var expected_cards=cards.values().filter(func(card):return card.is_visible_in_tree() and not card.disabled)
		check(guide.highlighted_controls().size()==expected_cards.size(),"every eligible card highlighted equally")
		for card in guide.highlighted_controls():check(cards.values().has(card),"no auxiliary button highlighted")
		if target is BoxContainer and expected_cards.size() > 1:
			var gap := target.get_theme_constant("separation")
			check(2 * (guide.outline.shadow_size + guide.OUTSET) < gap, "adjacent selection glows leave a gap")

func verify_transparent_previews(gallery: Control) -> void:
	RenderingServer.force_draw(false)
	for preview in gallery.previews.values():
		var image: Image = preview.viewport.get_texture().get_image()
		check(image.get_pixel(2, 2).a < 0.01, "joint card renders without a filled preview background")
		var model_pixels := 0
		for y in range(0, image.get_height(), 6):
			for x in range(0, image.get_width(), 6):
				if image.get_pixel(x, y).a > 0.9:
					model_pixels += 1
		check(model_pixels > 5, "joint model still renders in the transparent preview")

func verify_level_two_spacing(ui: CanvasLayer) -> void:
	var measure = ui.opening_measure
	var font: Font = measure.get_theme_default_font()
	var note_top: float = measure.size.y - measure.TEXT_GAP - font.get_height(measure.CAPTION_FONT_SIZE)
	check(measure._diagram.end.y <= note_top - measure.TEXT_GAP + 0.1, "reference diagram leaves room above the note")
	check(not measure.target_rectangles.is_empty() and measure.target_rectangles[0].end.y < note_top,
		"the full board edge clears the note at the default zoom")
	for id in ui.gallery.buttons:
		var card: Rect2 = ui.gallery.buttons[id].get_global_rect()
		var magnify: Rect2 = ui.gallery.inspect_buttons[id].get_global_rect()
		check(card.encloses(magnify), "magnify stays inside its joint type card")
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await settle()
	for chapter in [1,2,3]:
		await click(campaign.chapter_buttons[chapter]);var level=campaign.instances[chapter]
		await click(level.learning.start_button)
		if chapter==1:
			await click(level.panel.inspect_button)
			var ui=level.inspector
			verify_guide(ui.step_guide,ui.joint_choices,"第一步")
			await capture("guide-1-type")
			verify_transparent_previews(ui.joint_choices)
			await click(ui.joint_buttons.dovetail)
			verify_guide(ui.step_guide,ui.length_gallery,"第二步")
			await capture("guide-1-material")
			await click(ui.length_buttons.long)
			verify_guide(ui.step_guide,null,"第三步")
			await capture("guide-1-drag")
			await click(ui.joint_buttons.blind_tenon)
			check(ui.selected_joint=="blind_tenon","changing type remains user controlled")
			await click(ui.length_gallery.inspect_buttons.values()[0])
			check(ui.step_guide.highlighted_controls().is_empty(),"magnifier suppresses source guide")
			await click(ui.magnifier.close_button)
			verify_guide(ui.step_guide,null,"第三步")
			await click(ui.close_button)
		elif chapter==2:
			await click(level.panel.observe_button);var ui=level.panel
			verify_guide(ui.step_guide,ui.gallery,"第一步")
			check(not ui.drag_guide.selection_ready,"unselected wood has no model guide")
			await capture("guide-2-type")
			verify_transparent_previews(ui.gallery)
			verify_level_two_spacing(ui)
			surface.size = Vector2i(960, 600)
			await settle()
			RenderingServer.force_draw(false)
			var compact := surface.get_texture().get_image()
			check(compact.get_size() == Vector2i(960, 600), "960x600 observation preview")
			check(compact.save_png(OUT + "guide-2-type-960.png") == OK, "save compact observation preview")
			images.append("guide-2-type-960.png")
			verify_level_two_spacing(ui)
			surface.size = Vector2i(1920, 1080)
			await settle()
			await click(ui.joint_buttons.tongue_groove)
			verify_guide(ui.step_guide,ui.opening_gallery,"第二步")
			await capture("guide-2-material")
			await click(ui.opening_buttons.values()[0])
			verify_guide(ui.step_guide,null,"第三步")
			check(ui.drag_guide.selection_ready,"chosen wood enables model guide")
			await capture("guide-2-drag")
			await click(ui.overview_button)
		else:
			var ui=level.panel
			await click(ui.inspect_button)
			verify_guide(ui.step_guide,ui.gallery,"第一步")
			check(ui.next_button.modulate.a==0 and ui.next_button.disabled and ui.next_button.mouse_filter==Control.MOUSE_FILTER_IGNORE,"absent continue cannot receive input")
			await capture("guide-3-candidate")
			verify_transparent_previews(ui.gallery)
			await click(ui.candidate_buttons.values()[0])
			verify_guide(ui.step_guide,null,"第二步")
			await capture("guide-3-socket")
			await click(ui.lesson_button);await click(level.learning.start_button)
			verify_guide(ui.step_guide,null,"第二步")
			await click(ui.overview_button)
		await click(level.panel.restart_button)
		await click(campaign.back_button)
	var report={"failures":failures,"images":images,"method":"1920x1080 and 960x600 GPU with Viewport pointer input"}
	FileAccess.open(OUT+"guide-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GUIDE ",JSON.stringify(report));campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
