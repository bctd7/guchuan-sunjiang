extends "res://tests/inspection_workspace_tests.gd"
func capture(name: String) -> void:
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/level02-late-fit/merged-story-"+name+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"story GPU screenshot "+name);images.append(path)
func run() -> void:
	gpu=true;root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
	for dimensions in [Vector2i(1440,900),Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2);await button(level.panel.bulkhead_button)
		check(level.bulkhead_lesson.opened and not level.interaction.is_processing_input(),"merged story blocks ship input "+str(dimensions))
		check(surface.get_visible_rect().encloses(level.bulkhead_lesson.close_button.get_global_rect()) and surface.get_visible_rect().encloses(level.bulkhead_lesson._frame.get_global_rect()),"merged story card and close fit viewport "+str(dimensions))
		await capture(str(dimensions.x));await button(level.bulkhead_lesson.close_button)
		check(not level.bulkhead_lesson.opened and level.interaction.is_processing_input() and level.state.placed.is_empty(),"merged story returns to unchanged assembly "+str(dimensions))
	await button(level.panel.observe_button);await button(level.panel.joint_buttons.cross_lap);await button(level.panel.opening_buttons.B)
	await settle(.5);await Pointer.drag(surface,level.view,1.0,true);await wait_motion()
	check(level.state.placed.has("plank_0a") and level.state.placed.plank_0a.joint=="cross_lap" and not level.state.failed,"merged lesson keeps touch wrong-type trial working")
	check(not root.has_focus(),"merged GPU remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"host_had_focus":root.has_focus(),"renderer":DisplayServer.get_name(),"scope":"Concurrent bulkhead lesson/story merge: GPU three viewport sizes, enter/close/input restore, wrong-type touch installation"}
	FileAccess.open("res://tests/evidence/level02-late-fit/merged-story-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("MERGED_STORY_GPU ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
