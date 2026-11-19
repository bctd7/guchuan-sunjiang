extends SceneTree
## Actual renderer capture. Input/acceptance regression is tested separately.
const OUTPUT="res://tests/evidence/layout-current/"
var surface: SubViewport
var campaign: Node
var images: Array[String]=[]
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(label: String) -> void:
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels:=surface.get_texture().get_image()
	check(not pixels.is_empty(),"real pixels "+label)
	var path:=OUTPUT+label+".png"
	check(pixels.save_png(path)==OK,"save "+label)
	images.append(path)
func run() -> void:
	check(DisplayServer.get_name()!="headless","GPU renderer required")
	check(root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"no desktop focus")
	if not failures.is_empty(): quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	campaign.open_level(1)
	var level=campaign.current_chapter
	await capture("01-chapter-one-three-lessons")
	level.learning.start_button.pressed.emit()
	await capture("02-keel-workshop-layout")
	for rep in level.Rules.REPRESENTATIVE_IDS:
		level.joint_type=level.Rules.expected_joint(rep)
		level.state.select_piece(rep)
		var outcome: Dictionary=level._try_socket(rep)
		check(outcome.ok,"representative accepts "+rep)
		await create_timer(2.3).timeout
		if rep=="rib_l1": await capture("03-half-tenon-local-view")
		level.inspector.close()
		if rep=="rib_l1":
			await create_timer(.30).timeout
			await capture("04-labelled-automatic-insertion")
		while level.busy: await process_frame
	check(level.view.animations.is_empty() and not level.panel.check_button.disabled,"stability unlocked after real movement")
	await capture("05a-complete-model-before-check")
	level._check()
	level.panel.success_panel.hide()
	await capture("05-completed-ship-section-plan")
	for chapter in [2,3]:
		campaign.open_level(chapter)
		var next=campaign.current_chapter
		await capture("06-chapter-%d-three-lessons"%chapter)
		next.learning.start_button.pressed.emit()
		await capture("07-chapter-%d-original-background"%chapter)
	check(not root.has_focus(),"host never holds focus")
	var report={"failed":failures.size(),"failures":failures,"images":images,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"host_had_focus":root.has_focus(),"method":"Actual GPU SubViewport captures; hidden NO_FOCUS host; scripted setup, no desktop interaction."}
	FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LAYOUT_VISUAL ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
