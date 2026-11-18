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
			await click(ui.candidate_buttons.values()[0])
			verify_guide(ui.step_guide,null,"第二步")
			await capture("guide-3-socket")
			await click(ui.lesson_button);await click(level.learning.start_button)
			verify_guide(ui.step_guide,null,"第二步")
			await click(ui.overview_button)
		await click(level.panel.restart_button)
		await click(campaign.back_button)
	var report={"failures":failures,"images":images,"method":"1920x1080 GPU with Viewport pointer input"}
	FileAccess.open(OUT+"guide-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GUIDE ",JSON.stringify(report));campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
