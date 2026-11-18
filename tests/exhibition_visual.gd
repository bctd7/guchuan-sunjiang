extends SceneTree
## Actual GPU pixels at target resolution; scripted navigation and pointer events.
const OUT="res://tests/evidence/exhibition-1080/"
var surface: SubViewport
var campaign
var failures: Array[String]=[]
var images: Array[String]=[]
var small: Array=[]
var measured: Array=[]
var stage: String
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func settle() -> void:
	for i in 12:await process_frame
func click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"operable "+button.text)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=button.get_global_rect().get_center();event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		surface.push_input(event,true)
		await process_frame
	await settle()
func audit(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and node is Button:
		var rect: Rect2=node.get_global_rect()
		check(Rect2(0,0,1920,1080).grow(1).encloses(rect),stage+" outside "+node.text+str(rect))
		measured.append({"stage":stage,"text":node.text,"rect":str(rect)})
		if minf(rect.size.x,rect.size.y)<59.9:small.append({"stage":stage,"text":node.text,"rect":str(rect)})
	for child in node.get_children():audit(child)
func capture(label: String) -> void:
	await settle();stage=label;audit(campaign)
	RenderingServer.force_draw(false)
	var pixels:=surface.get_texture().get_image()
	check(pixels.get_size()==Vector2i(1920,1080),"1920x1080 pixels "+label)
	check(pixels.save_png(OUT+label+".png")==OK,"save "+label)
	images.append(label+".png")
func run() -> void:
	check(DisplayServer.get_name()!="headless","GPU required")
	var startup_mode:=root.mode
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await capture("00-menu")
	for chapter in [1,2,3]:
		await click(campaign.chapter_buttons[chapter])
		var level=campaign.instances[chapter]
		await capture("%d-intro"%chapter)
		for id in level.learning.lesson_ids:
			await click(level.learning.lesson_buttons[id])
			await capture("%d-joint-%s"%[chapter,id])
			await click(level.learning.workshop.science_entry)
			await capture("%d-science-%s"%[chapter,id])
			var workshop=level.learning.workshop
			await click(workshop.dynamic_science.close_button if id=="dovetail" else workshop.force_gallery.close_button)
			await click(level.learning.back_button)
		await click(level.learning.start_button)
		await capture("%d-workshop"%chapter)
		if chapter==1:
			await click(level.panel.lesson_button);await capture("1-story");await click(level.story.close_button)
			await click(level.panel.inspect_button);await capture("1-inspector")
			await click(level.inspector.joint_choices.inspect_buttons.values()[0]);await capture("1-magnifier")
			await click(level.inspector.magnifier.close_button);level.inspector.close()
		elif chapter==2:
			await click(level.panel.bulkhead_button);await capture("2-bulkhead");await click(level.bulkhead_lesson.close_button)
			await click(level.panel.observe_button)
			await click(level.panel.joint_buttons.tongue_groove);await capture("2-inspector")
			await click(level.panel.opening_gallery.inspect_buttons.values()[0]);await capture("2-magnifier")
			await click(level.panel.magnifier.close_button);level.panel.overview_requested.emit()
		else:
			await click(level.panel.inspect_button)
			for id in ["zrail","leg","mast","apron","top","lbrace","rudder","blade"]:
				await click(level.panel.candidate_buttons[level.state.Rules.SPECS[id].joint])
				var point: Vector2=level.view.socket_screen_position(id)
				check(level.panel.main_viewport.get_parent().get_global_rect().has_point(point),"projected socket in model area "+id)
				for down in [true,false]:
					var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
					surface.push_input(event,true);await process_frame
				await create_timer(1.8).timeout
				check(level.state.placed.has(id),"1920 touch installs "+id)
				if id in ["mast","top","blade"]:
					await capture("3-stage-"+id)
					if id=="blade":
						await click(level.panel.overview_button)
						check(level.panel.left_button.get_global_rect().end.y<=level.panel.restart_button.get_parent().get_parent().get_global_rect().position.y-8,"helm remains above footer actions")
				if id!="blade":await click(level.panel.next_button)
			await click(level.panel.left_button);await click(level.panel.right_button)
			check(level.state.completed,"1920 third chapter completes")
			await capture("3-success")
		await settle();campaign._show_menu();await settle()
	check(small.is_empty(),"all captured touch targets at least 60px")
	var report={"failed":failures.size(),"failures":failures,"images":images,"small_targets":small,"buttons":measured,"renderer":DisplayServer.get_name(),"startup_window_mode":startup_mode,"host_had_focus":root.has_focus(),"method":"Actual GPU 1920x1080 SubViewport, minimized host; mouse events through Viewport. No physical touch or target-device verification."}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXHIBITION ",JSON.stringify({"failed":failures.size(),"failures":failures,"small":small,"images":images.size()}))
	campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
