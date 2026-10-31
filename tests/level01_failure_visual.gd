extends SceneTree
## GPU layout review uses a minimized NO_FOCUS host and an independent viewport.
const OUTPUT="res://tests/evidence/whole-level-failure-r8/visual/"
var surface: SubViewport
var campaign: Node
var level: Node
var images: Array[String]=[]
var failures: Array[String]=[]

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func capture(label: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	var pixels:=surface.get_texture().get_image()
	check(not pixels.is_empty(),"real GPU pixels "+label)
	check(pixels.save_png(OUTPUT+label+".png")==OK,"save "+label)
	images.append(OUTPUT+label+".png")

func insert(id: String, length: String) -> void:
	level.joint_type=level.Rules.expected_joint(id)
	level.tenon_length=length
	check(level._try_socket(id).ok,"accept insertion "+id)
	var deadline:=Time.get_ticks_msec()+5000
	while not level.state.failed and level.inspector.is_animating and Time.get_ticks_msec()<deadline:
		for motion in level.view.animations.values(): motion.set_speed_scale(16)
		if is_instance_valid(level.inspector._motion): level.inspector._motion.set_speed_scale(16)
		await process_frame

func run() -> void:
	check(DisplayServer.get_name()!="headless","GPU renderer required")
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.mode=Window.MODE_MINIMIZED
	check(root.get_flag(Window.FLAG_NO_FOCUS),"host must be NO_FOCUS")
	if not failures.is_empty(): quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	campaign.open_level(1)
	level=campaign.instances[1]
	level.learning.start_button.pressed.emit()
	await capture("01-ready")
	level.joint_type="blind_tenon"
	level.tenon_length="correct"
	level._inspect()
	await capture("02-drag-arrow-without-floating-text")
	level.inspector.close()
	for id in level.Rules.REPRESENTATIVE_IDS:
		await insert(id,"short" if id=="rib_l1" else "correct")
		level.inspector.close()
		while level.busy and not level.state.failed:
			for motion in level.view.animations.values(): motion.set_speed_scale(16)
			await process_frame
		if id!="beam1": check(not level.state.failed and not level.panel.failure_overlay.visible,"partial wrong assembly remains playable")
	check(level.state.failed and level.state.installed_count()==10 and level.panel.failure_overlay.visible,"complete wrong assembly automatically shows failure")
	await capture("03-failure-during-shake")
	while level.busy: await process_frame
	await capture("04-failure-after-shake")
	for action in [level.panel.failure_restart_button,level.panel.failure_return_button]:
		check(level.panel.failure_panel.get_global_rect().encloses(action.get_global_rect()),"both failure actions remain inside modal")
	surface.size=Vector2i(1100,800)
	await capture("05-failure-small-window")
	surface.size=Vector2i(1440,900)
	level.panel.failure_restart_button.pressed.emit()
	await capture("06-restarted")
	check(not level.state.failed and not level.panel.failure_overlay.visible,"restart restores normal view")
	for id in level.Rules.REPRESENTATIVE_IDS:
		await insert(id,"correct")
		level.inspector.close()
		while level.busy:
			for motion in level.view.animations.values(): motion.set_speed_scale(16)
			await process_frame
	level._check()
	check(level.state.completed and level.panel.success_panel.visible,"restarted run completes")
	await capture("07-success-after-restart")
	check(not root.has_focus(),"host never gained desktop focus")
	var report={"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus(),"method":"Actual GPU SubViewport captures; minimized NO_FOCUS host; scripted scene setup, no desktop input"}
	FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LEVEL01_FAILURE_VISUAL ",JSON.stringify(report))
	campaign.free()
	surface.free()
	quit(0 if failures.is_empty() else 1)
