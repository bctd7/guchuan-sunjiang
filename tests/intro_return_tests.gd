extends SceneTree
var surface: SubViewport
var campaign: Node
var passed := 0
var failed := 0
var gpu := false

func _initialize() -> void:
	gpu="--gpu" in OS.get_cmdline_user_args()
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error(label)

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(.08).timeout

func tap(button: Button, touch := false) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"button operable: "+button.text)
	var point=button.get_global_rect().get_center()
	for down in [true,false]:
		if touch:
			var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
			surface.push_input(event,true)
		else:
			var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
			surface.push_input(event,true)
		await process_frame
	await settle()

func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await settle()
	var shared_button=campaign.back_button.get_instance_id()
	for chapter in [1,2,3]:
		await tap(campaign.chapter_buttons[chapter])
		var level=campaign.current_chapter
		check(level.learning.opened,"chapter entry intro visible")
		check(not level.workbench_ready and level.view == null and level.panel == null,
			"introduction allocates no ship workbench")
		check(campaign.back_button.is_visible_in_tree(),"intro directory return visible")
		check(campaign.back_button.text=="返回主界面","intro button text")
		check(campaign.back_button.get_instance_id()==shared_button,"reuse existing operating-screen return instance")
		var rect: Rect2=campaign.back_button.get_global_rect()
		check(rect.position.x>surface.size.x*.7 and rect.end.y<150,"intro return at top right")
		for dimensions in [Vector2i(1920,1080),Vector2i(1440,900),Vector2i(2560,1440)]:
			surface.size=dimensions
			await settle()
			check(absf(campaign.back_button.get_global_rect().end.x-level.learning.start_button.get_global_rect().end.x)<.5,"intro return right edge matches start button at "+str(dimensions))
		surface.size=Vector2i(1920,1080)
		await settle()
		if gpu:
			await RenderingServer.frame_post_draw
			surface.get_texture().get_image().save_png("res://intro-chapter-%d.png"%chapter)
		await tap(campaign.back_button,true)
		check(campaign.active_level==0 and campaign.menu.visible,"touch returns to main directory")
		check(campaign.current_chapter == null and not is_instance_valid(level),"return frees current round")
		await tap(campaign.chapter_buttons[chapter])
		level=campaign.current_chapter
		await tap(level.learning.start_button)
		check(not level.learning.modal_open(),"start reaches workshop")
		check(campaign.back_button.get_instance_id()==shared_button and campaign.back_button.is_visible_in_tree(),"workshop retains same button")
		check(campaign.back_button.text=="返回关卡目录","workshop keeps original text")
		check(is_equal_approx(campaign.back_button.position.x,1244.0),"workshop return restores original horizontal position")
		level.learning.show_intro()
		await settle()
		check(campaign.back_button.is_visible_in_tree(),"revisited intro return visible")
		await tap(level.learning.lesson_buttons[level.learning.lesson_ids[0]])
		check(not campaign.navigation.visible,"directory navigation stays hidden in detailed classroom")
		await tap(level.learning.back_button)
		check(level.learning.opened and campaign.back_button.is_visible_in_tree(),"classroom returns to intro and restores main return")
		check(not campaign.next_button.is_visible_in_tree(),"intro never exposes next-chapter shortcut")
		await tap(campaign.back_button)
		check(campaign.menu.visible and campaign.active_level==0,"mouse returns to directory")
	# The introduction exception must not reveal navigation above other modals.
	await tap(campaign.chapter_buttons[1]);var level=campaign.current_chapter
	await tap(level.learning.start_button)
	level.panel.success_panel.show();await settle()
	check(not campaign.navigation.visible,"result modal still hides campaign navigation")
	level.panel.success_panel.hide();await settle()
	check(campaign.back_button.is_visible_in_tree(),"normal workshop navigation restored")
	await tap(campaign.back_button)
	print("INTRO_RETURN: %d passed, %d failed"%[passed,failed])
	campaign.free();surface.free()
	root.get_node("GameAudio").music.stop()
	await create_timer(.2).timeout
	quit(0 if failed==0 else 1)
