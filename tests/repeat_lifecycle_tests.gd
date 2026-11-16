extends "res://tests/observation_repeat_tests.gd"
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
	await prepare("plank_0a");await settle(.5);await Pointer.drag(surface,level.view,1.0)
	var deadline:=Time.get_ticks_msec()+2500
	while not level.view.animations.has("plank_0b") and Time.get_ticks_msec()<deadline:await process_frame
	check(level.busy and level.state.placed.size()==2 and level.view.animations.has("plank_0b"),"automatic board has its own real cancellable motion")
	await capture("second-automatic-board-mid-motion");await button(level.panel.restart_button);await settle(.9)
	check(level.state.placed.is_empty() and not level.busy and level.view.animations.is_empty() and not level.state.checked,"restart during automatic repeat rejects old callbacks")
	await second_trial("plank_0a","correct");await capture("second-one-operation-two-boards-final")
	check(not level._can_drag("plank_0b").ok,"repeated companion cannot be manually dragged through a stale request")
	var saved: Dictionary=level.state.placed.duplicate(true);var instance=level
	await settle(.06) # Campaign navigation updates on the next process frame.
	await button(campaign.back_button);await button(campaign.chapter_buttons[2]);await button(level.learning.start_button)
	check(level==instance and level.state.placed==saved and level.state.next_id()=="cross_upper","directory round-trip retains exact automatic provenance and next manual task")
	await second_trial("cross_upper","correct");await button(level.panel.undo_button)
	check(level.state.placed==saved and level.state.selected=="cross_upper" and not level.state.checked,"withdrawing a later completed group preserves prior correct board group")
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Actual Viewport GUI: restart during automatic board tween, exact provenance across directory, undo later completed group, no gameplay state writes"}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/observation-repeat");FileAccess.open("res://tests/evidence/observation-repeat/"+("lifecycle-gpu" if gpu else "lifecycle-headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("REPEAT_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
