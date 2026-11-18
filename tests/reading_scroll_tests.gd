extends SceneTree
var failures: Array[String]=[]
var surface: SubViewport
var campaign
var results: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func settle() -> void:
	for i in 10: await process_frame
func touch(point: Vector2,pressed: bool,index:=0,canceled:=false) -> void:
	var e:=InputEventScreenTouch.new();e.position=point;e.pressed=pressed;e.index=index;e.canceled=canceled
	surface.push_input(e,true)
	await process_frame
func motion(point: Vector2,delta: Vector2,index:=0) -> void:
	var e:=InputEventScreenDrag.new();e.position=point;e.relative=delta;e.index=index
	surface.push_input(e,true)
	await process_frame
func swipe(scroll: ScrollContainer,point: Vector2) -> void:
	await touch(point,true)
	for i in 5:
		point.y-=24
		await motion(point,Vector2(0,-24))
	await touch(point,false,0,true)
	await settle()
func audit(scroll: ScrollContainer,label: String) -> void:
	await settle()
	var bar:=scroll.get_v_scroll_bar()
	var maximum:=maxf(0,bar.max_value-bar.page)
	scroll.scroll_vertical=0
	var rect:=scroll.get_global_rect()
	await swipe(scroll,rect.position+rect.size*Vector2(.5,.7))
	check(scroll.scroll_vertical>0 if maximum>1 else scroll.scroll_vertical==0,label+" body touch")
	await capture(label+"-touch")
	scroll.scroll_vertical=0
	var top_point:=rect.get_center()
	await touch(top_point,true);await motion(top_point+Vector2(0,80),Vector2(0,80));await touch(top_point+Vector2(0,80),false,0,true)
	check(scroll.scroll_vertical==0,label+" top clamp")
	for repeat in 3: await swipe(scroll,rect.position+rect.size*Vector2(.1,.7))
	var before:=scroll.scroll_vertical
	var p:=rect.position+rect.size*.5
	await touch(p,true)
	await touch(p,true,1)
	await motion(p-Vector2(0,150),Vector2(0,-150),1)
	check(scroll.scroll_vertical==before,label+" second finger ignored")
	await touch(p,false,1,true);await touch(p,false,0,true)
	scroll.scroll_vertical=int(maximum)
	await swipe(scroll,rect.position+rect.size*Vector2(.15,.65))
	check(scroll.scroll_vertical<=maximum+1,label+" bottom clamp")
	scroll.scroll_vertical=0
	await touch(rect.get_center(),true)
	scroll.hide();await settle();scroll.show();await settle()
	await motion(rect.get_center()-Vector2(0,80),Vector2(0,-80))
	check(scroll.scroll_vertical==0,label+" hide clears gesture")
	await touch(rect.get_center(),true)
	scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await motion(rect.get_center()-Vector2(0,80),Vector2(0,-80))
	check(scroll.scroll_vertical==0,label+" focus loss clears gesture")
	await touch(rect.get_center(),false,0,true)
	var wheel:=InputEventMouseButton.new();wheel.position=rect.get_center();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
	surface.push_input(wheel,true);await settle()
	check(scroll.scroll_vertical>0 if maximum>1 else scroll.scroll_vertical==0,label+" mouse wheel")
	results.append({"page":label,"range":maximum,"offset":scroll.scroll_vertical})
	await capture(label)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw(false)
	surface.get_texture().get_image().save_png("res://tests/evidence/reading-scroll/"+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/reading-scroll")
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle()
	for chapter in [1,2,3]:
		campaign.open_level(chapter);await settle()
		var level=campaign.instances[chapter]
		await audit(level.learning._scroll,"intro-"+str(chapter))
		var observe: Button=level.learning.lesson_buttons.values()[0]
		var point: Vector2=observe.get_global_rect().get_center()
		await touch(point,true)
		await motion(point-Vector2(0,60),Vector2(0,-60))
		await touch(point-Vector2(0,60),false)
		check(level.learning._scroll.is_visible_in_tree(),"intro swipe does not open lesson")
		await touch(point,true);await touch(point,false);await settle()
		check(not level.learning._scroll.is_visible_in_tree(),"intro touch tap opens lesson")
		if chapter==1:
			var presenter=preload("res://classroom/science/presenter.gd").new()
			surface.add_child(presenter)
			presenter.configure(level.learning.workshop.assembly)
			presenter.enabled=true
			var panel=presenter.create_panel()
			surface.add_child(panel);panel.position=Vector2(100,100);panel.size=Vector2(360,700)
			await settle()
			await audit(panel.find_children("*","ScrollContainer",true,false)[0],"structure-science")
			panel.free();presenter.free()
		level.learning.back_button.pressed.emit();await settle()
		level.learning.start_button.pressed.emit();await settle()
		if chapter==1:
			level.panel.lesson_button.pressed.emit();await settle()
			var scroll=level.story.root.find_children("*","ScrollContainer",true,false)[0]
			await audit(scroll,"shipwright-story")
			scroll.scroll_vertical=0;await settle()
			var picture=level.story.root.find_child("StoryIllustration",true,false)
			await swipe(scroll,picture.get_global_rect().get_center())
			check(scroll.scroll_vertical>0,"story illustration touch")
			level.story.close();level.panel.lesson_button.pressed.emit();await settle()
			await audit(scroll,"story-reentry")
			level.story.close()
		if chapter==2:
			level.panel.bulkhead_button.pressed.emit();await settle()
			await audit(level.bulkhead_lesson.root.scroll,"bulkhead")
			level.bulkhead_lesson.close()
		campaign._show_menu();await settle()
	FileAccess.open("res://tests/evidence/reading-scroll/report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"pages":results},"  "))
	print("READING_SCROLL ",JSON.stringify({"failures":failures,"pages":results}))
	campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
