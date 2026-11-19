extends SceneTree
## Real Viewport pointers validate chapter-specific actions inside the shared card.
var surface: SubViewport
var campaign
var passed:=0
var failures: Array[String]=[]
var gpu:=false
var images: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if ok:passed+=1
	else:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for i in 3:await process_frame
func button(control: Button) -> void:
	check(control.is_visible_in_tree() and not control.disabled,"operable "+control.text)
	var point:=control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		surface.push_input(event,true)
		await process_frame
	await settle()
func capture(name: String) -> void:
	if not gpu:return
	await settle()
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/chapter-tools/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/chapter-tools"))
	check(surface.get_texture().get_image().save_png(path)==OK,"screenshot "+name)
	images.append(path)
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu")
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle()
	for chapter in [1,2]:
		surface.size=Vector2i(1440,900)
		await settle()
		await button(campaign.chapter_buttons[chapter])
		var level=campaign.current_chapter
		await button(level.learning.start_button)
		var actions: Array=[level.panel.lesson_button] if chapter==1 else [level.panel.bulkhead_button]
		for dimensions in [Vector2i(1440,900),Vector2i(1100,800),Vector2i(960,600)]:
			surface.size=dimensions
			await settle()
			check(surface.get_visible_rect().encloses(level.panel.return_button.get_global_rect()),"chapter return remains in viewport "+str(chapter)+str(dimensions))
			var card: Rect2=level.panel.main_sidebar.get_global_rect()
			check(surface.get_visible_rect().encloses(card),"auxiliary card fits "+str(chapter)+str(dimensions))
			check(not card.intersects(level.panel.main_footer.get_global_rect()),"card clear of task and footer "+str(chapter)+str(dimensions))
			for action in actions:
				check(card.encloses(action.get_global_rect()),"action remains inside shared card "+action.text+str(dimensions))
			await capture("chapter-%d-%d"%[chapter,dimensions.x])
			if chapter==1:
				await button(level.panel.lesson_button)
				check(level.story.opened and not level.interaction.is_processing_input(),"story action retains input suspension "+str(dimensions))
				await button(level.story.close_button)
				check(not level.story.opened and level.interaction.is_processing_input(),"story returns to first chapter "+str(dimensions))
			else:
				await button(level.panel.inventory_button)
				check(level.panel.inventory_open and level.panel.group_buttons.size()==3 and level.Rules.GROUPS.size()==3 and level.Rules.IDS.size()==10,"inventory action exposes three groups for ten members "+str(dimensions))
				await button(level.panel.inventory_close_button)
				await button(level.panel.bulkhead_button)
				check(level.bulkhead_lesson.opened and not level.interaction.is_processing_input(),"compartment action suspends ship input "+str(dimensions))
				await button(level.bulkhead_lesson.close_button)
				check(not level.bulkhead_lesson.opened and level.interaction.is_processing_input(),"compartment action restores input "+str(dimensions))
		surface.size=Vector2i(1440,900)
		await settle()
		var state_before: Dictionary=level.state.placed.duplicate(true)
		if chapter==1:
			await button(level.panel.inspect_button)
			await button(level.inspector.lesson_button)
		else:
			await button(level.panel.observe_button)
			await button(level.panel.joint_buttons.tongue_groove)
			await button(level.panel.lesson_button)
		check(level.learning.opened and level.learning.start_button.text=="返回本关搭建","accurate shared assembly return label "+str(chapter))
		var lesson_id: String=level.learning.lesson_ids[0]
		await button(level.learning.lesson_buttons[lesson_id])
		check(is_instance_valid(level.learning.workshop) and level.learning.workshop.assembly.definition.id==lesson_id,"model opens correct original classroom "+str(chapter))
		await button(level.learning.back_button)
		check(level.learning.opened and level.learning.workshop==null,"classroom returns to chapter introduction "+str(chapter))
		await button(level.learning.start_button)
		check(not level.learning.modal_open() and level.view.visible and level.panel.visible and level.interaction.is_processing_input(),"assembly return restores actual chapter view and input "+str(chapter))
		check(level.state.placed==state_before,"classroom path retains assembly state "+str(chapter))
		if chapter==1:
			check(not level.inspector.opened,"first chapter returns to its current overview")
		else:
			check(level.view.inspected and level.state.joint=="tongue_groove","second chapter returns to local operation with choice")
			await button(level.panel.overview_button)
		await settle()
		await button(campaign.back_button)
	# Resize while both chapters are cached, then reattach without another resize.
	for chapter in [1,2]:
		surface.size=Vector2i(960,600)
		await settle()
		await button(campaign.chapter_buttons[chapter])
		var level=campaign.current_chapter
		await button(level.learning.start_button)
		check(surface.get_visible_rect().encloses(level.panel.main_sidebar.get_global_rect()),"cached chapter refreshes layout on reentry "+str(chapter))
		check(level.panel.main_sidebar.get_global_rect().size.is_equal_approx(Vector2(310,405)*2.0/3.0),"cached card matches design scale "+str(chapter))
		await button(level.panel.return_button)
		check(campaign.active_level==0 and campaign.menu.visible,"scaled chapter return reaches directory "+str(chapter))
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free()
	surface.free()
	var report={"revision":"chapter-tools-20261101","passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus(),"method":"Actual Viewport mouse events; not human hardware validation"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/chapter-tools"))
	FileAccess.open("res://tests/evidence/chapter-tools/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AUXILIARY_UI ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
