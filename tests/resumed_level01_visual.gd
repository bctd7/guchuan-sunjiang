extends SceneTree
## Dedicated GPU surface; real UI events, no desktop interaction.
const OUTPUT="res://tests/evidence/resumed-level01/"
var surface: SubViewport
var campaign: Node
var level: Node3D
var passed:=0
var failures: Array[String]=[]
var images: Array[String]=[]
var previews_only:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if ok: passed+=1
	else: failures.append(message);push_error(message)
func settle(seconds:=.08) -> void:
	await create_timer(seconds).timeout
	await process_frame
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	surface.push_input(motion,true)
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
func button(control: Button) -> void:
	if control==null: check(false,"requested button exists");quit(1);return
	check(control.is_visible_in_tree() and not control.disabled,"operable "+control.text)
	await click(control.get_global_rect().get_center())
func capture(label: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels:=surface.get_texture().get_image()
	var path:=OUTPUT+label+".png"
	check(not pixels.is_empty() and pixels.save_png(path)==OK,"actual pixels "+label)
	images.append(path)
func wait_motion() -> void:
	var elapsed:=0.0
	while level.busy and elapsed<15:
		await settle(.04)
		elapsed+=.04
	check(not level.busy and level.view.animations.is_empty(),"all actual movements finish")
func choose(id: String,length: String,shot: String="") -> void:
	check(level.state.selected==id,"current connection "+id)
	await button(level.panel.inspect_button)
	check(level.inspector.opened,"independent observer opens")
	if not length.is_empty():
		await button(level.inspector.joint_buttons[level.Rules.expected_joint(id)])
		await button(level.inspector.length_buttons[length])
		check(level.tenon_length==length and level.inspector.selected_length==length,"explicit measured length chosen "+length)
	if not shot.is_empty(): await capture(shot)
	await button(level.inspector.close_button)
func install(id: String) -> void:
	await click(level.view.socket_screen_position(id))
	check(level.state.placed.has(id) and level.inspector.opened and level.busy,"actual target installs selected length "+id)
	await settle(2.25)
	await button(level.inspector.close_button)
	await wait_motion()
func finish() -> void:
	check(not root.has_focus(),"render host ends without desktop focus")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"host_had_focus":root.has_focus(),"method":"Real GUI pointer events and actual GPU SubViewport pixels; hidden NO_FOCUS host. No direct business state mutation or desktop input. Not human/physical touch testing."}
	FileAccess.open(OUTPUT+("intro-report.json" if previews_only else "report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RESUMED_LEVEL01 ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"actual no-focus GPU renderer")
	if not failures.is_empty(): quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.3)
	for number in [1,2,3]:
		await button(campaign.chapter_buttons[number])
		level=campaign.current_chapter
		await capture("01-chapter-%d-original-models"%number)
		check(level.learning.previews.size()==3,"chapter contains its three real-model previews")
		await button(level.learning.start_button)
		await button(campaign.back_button)
	if previews_only:
		finish()
		return
	await button(campaign.chapter_buttons[1])
	level=campaign.current_chapter
	await capture("02-compact-task-and-workshop")
	await button(level.panel.lesson_button)
	check(level.story.opened and not campaign.navigation.visible,"optional story owns its view")
	await capture("03-optional-shipwright-story")
	await button(level.story.close_button)
	check(level.state.placed.size()==1,"story preserves fixed foundation and progress")
	await button(level.panel.inspect_button)
	check(level.inspector.selected_length.is_empty() and level.inspector.selected_joint.is_empty(),"no default answer in observer")
	await capture("04-neutral-length-and-type-comparison")
	await button(level.inspector.joint_buttons.dovetail)
	await button(level.inspector.length_buttons.correct)
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	check(level.state.placed.size()==1,"wrong joint rejected independently of legal length")
	await choose("rib_l1","short","05-short-half-tenon-before-install")
	await install("rib_l1")
	check(level.state.automatic_count()==5,"existing five automatic rib mates retained")
	await choose("bow","long","06-long-dovetail-before-install")
	await install("bow")
	await choose("beam1","long","07-long-through-beam-before-install")
	await install("beam1")
	check(level.state.installed_count()==10 and not level.panel.check_button.disabled,"all lengths can be installed before checking")
	await button(level.panel.check_button)
	check(not level.state.completed and not level.panel.success_panel.visible,"wrong lengths fail stability without blocking assembly")
	await capture("08-installed-but-unstable")
	await wait_motion()
	for i in 3: await button(level.panel.undo_button)
	check(level.state.placed.size()==1 and level.tenon_length.is_empty(),"undo all groups clears choices, preserves keel")
	for id in level.Rules.REPRESENTATIVE_IDS:
		await choose(id,"correct")
		await install(id)
	await button(level.panel.check_button)
	check(level.state.completed and campaign.completed.get(1,false),"corrected full skeleton completes")
	level.panel.success_panel.hide()
	await capture("09-corrected-plan-completion")
	finish()
