extends SceneTree
## Actual GPU pixels at target resolution; scripted navigation and pointer events.
const OUT="res://tests/evidence/joint-return/"
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
	await RenderingServer.frame_post_draw
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
			var workshop=level.learning.workshop
			var part=workshop.assembly.selected
			if not part.is_empty():workshop.assembly.progress[part]=0.25
			var progress=workshop.assembly.progress.duplicate(true)
			var states=workshop.assembly.states.duplicate(true)
			var presenter=workshop.dynamic_science if id=="dovetail" else workshop.force_gallery
			for visit in 2:
				await click(workshop.science_entry)
				check(presenter.opened,"opened "+id)
				check(presenter.close_button.text=="返回","return label "+id)
				await capture("%d-science-%s-%d"%[chapter,id,visit])
				await click(presenter.close_button)
				check(not presenter.opened,"closed "+id)
				check(workshop.assembly.progress==progress and workshop.assembly.states==states,"progress retained "+id)
			await click(workshop.science_entry)
			var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
			surface.push_input(escape,true);await settle()
			check(not presenter.opened,"Escape retained "+id)
			await click(level.learning.back_button)
		campaign._show_menu();await settle()
	var report={"failed":failures.size(),"failures":failures,"images":images,"small_targets":small,"buttons":measured,"renderer":DisplayServer.get_name(),"startup_window_mode":startup_mode,"host_had_focus":root.has_focus(),"method":"Actual GPU 1920x1080 SubViewport, minimized host; mouse events through Viewport. No physical touch or target-device verification."}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXHIBITION ",JSON.stringify({"failed":failures.size(),"failures":failures,"small":small,"images":images.size()}))
	campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
