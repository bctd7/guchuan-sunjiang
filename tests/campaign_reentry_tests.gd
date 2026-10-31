extends "res://tests/level01_failure_tests.gd"
## Directory lifecycle regression: actual pointer intents, retained gameplay state.
var surface: SubViewport
var before_fix:=false
var gpu:=false
var records: Array=[]
var shots: Array[String]=[]
const OUT="res://tests/evidence/campaign-reentry/"
func _initialize() -> void:
	before_fix="--before-fix" in OS.get_cmdline_user_args()
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	run.call_deferred()
func click(point: Vector2) -> void:
	var movement=InputEventMouseMotion.new();movement.position=point;movement.global_position=point;surface.push_input(movement,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		surface.push_input(event,true);await process_frame
	await process_frame
func raw_enter(number: int) -> void:
	await button(campaign.chapter_buttons[number]);level=campaign.instances[number];await settle(.1)
	check(campaign.active_level==number and level.is_inside_tree(),"actual directory enters chapter "+str(number))
func inspect_entry(label: String,expected_intro: bool) -> void:
	await physics_frame
	await settle(.12)
	if gpu: RenderingServer.force_draw(false)
	var previews: Array=[]
	for id in level.learning.lesson_ids:
		var p=level.learning.previews[id]
		var paths: Array=[]
		for part in p.definition.parts: paths.append(str(part.mesh))
		var opaque:=0
		if gpu and expected_intro:
			var pixels=p.viewport.get_texture().get_image()
			for y in range(0,pixels.get_height(),4):
				for x in range(0,pixels.get_width(),4):
					if pixels.get_pixel(x,y).a>.1:opaque+=1
			check(opaque>10,"actual original model pixels visible "+label+"/"+id)
		previews.append({"joint":id,"preview_instance":p.get_instance_id(),"viewport_instance":p.viewport.get_instance_id(),"camera_current":p.camera.current,"mesh_count":p.mesh_nodes.size(),"resource_paths":paths,"sample_visible_pixels":opaque})
	records.append({"label":label,"chapter":campaign.active_level,"level_instance":level.get_instance_id(),"scene_path":level.scene_file_path,"intro_open":level.learning.opened,"intro_visible":level.learning._intro.visible,"started":level.learning._started,"source_visible":level.view.visible,"source_panel_visible":level.panel.visible,"completed":level.state.completed,"failed":level.state.failed if "failed" in level.state else false,"previews":previews})
	print("ENTRY_ROUTE ",JSON.stringify({"label":label,"scene":level.scene_file_path,"instance":level.get_instance_id(),"intro_open":level.learning.opened,"started":level.learning._started,"completed":level.state.completed}))
	check(level.learning.opened==expected_intro and level.learning._intro.visible==expected_intro,"expected introduction on "+label)
	if expected_intro:
		check(not level.view.visible and not level.panel.visible,"introduction suspends current ship presentation "+label)
	if gpu:
		check(not root.has_focus(),"regression host stays unfocused")
		var path=OUT+("before-" if before_fix else "after-")+label+".png"
		check(surface.get_texture().get_image().save_png(path)==OK,"save actual entry screenshot "+label);shots.append(path)
func leave_intro() -> void:
	if level.learning.modal_open():await button(level.learning.start_button)
	await process_frame
func revisit(label: String,saved,instance: Node) -> void:
	await raw_enter(1)
	check(level==instance,"directory reuses exact chapter instance "+label)
	await inspect_entry(label,not before_fix)
	check(level.state.placed==saved,"intro does not reset retained placements "+label)
	await leave_intro()
	check(level.state.placed==saved and level.view.visible and level.panel.visible,"continuing restores retained ship view "+label)
func run() -> void:
	gpu=DisplayServer.get_name()!="headless"
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu and root.has_focus():push_error("unfocused GPU host required");quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await settle(.25)
	await raw_enter(1);await inspect_entry("01-first-entry",true);await leave_intro()
	await good_group("rib_l1")
	var first=level;var partial=level.state.placed.duplicate(true)
	await back();await revisit("02-partial-reentry",partial,first)
	await good_group("bow");await good_group("beam1")
	check(level.state.completed and campaign.completed.get(1,false),"normal inputs complete first level")
	var complete=level.state.placed.duplicate(true)
	await back();await revisit("03-completed-reentry",complete,first)
	check(level.state.completed and campaign.completed.get(1,false),"completed state and badge survive intro revisit")
	await button(level.panel.restart_button)
	await choose_trial("rib_l1","dovetail","short",true);await good_group("bow");await good_group("beam1")
	check(level.state.failed,"normal wrong complete assembly reaches failure")
	var bad=level.state.placed.duplicate(true)
	await button(level.panel.failure_return_button);await revisit("04-failed-reentry",bad,first)
	check(level.state.failed and level.panel.failure_overlay.visible and not level.interaction.is_processing_input(),"failed state, failure modal and input lock restored after introduction")
	await restart_failure()
	var reset=level.state.placed.duplicate(true)
	await back();await revisit("05-restarted-reentry",reset,first)
	check(not level.state.failed and not level.state.completed and level.state.placed==level.Rules.initial_connections(),"restart remains clean after directory revisit")
	await back()
	for chapter in [2,3]:
		await raw_enter(chapter);await inspect_entry("06-chapter-"+str(chapter)+"-first",true);await leave_intro()
		var other=level;var saved=level.state.placed.duplicate(true)
		await back();await raw_enter(chapter)
		await inspect_entry("07-chapter-"+str(chapter)+"-reentry",not before_fix)
		check(level==other and level.state.placed==saved,"other chapter state is retained on directory return")
		await leave_intro();await back()
	var report={"before_fix":before_fix,"passed":passed,"failed":failed,"failures":failures,"records":records,"images":shots,"renderer":DisplayServer.get_name(),"host_focus":root.has_focus(),"method":"Real Viewport clicks through campaign menu, complete/wrong assemblies, failure directory action and restart; real Tween playback accelerated; no gameplay state overwrite"}
	FileAccess.open(OUT+("before" if before_fix else "after")+("-gpu" if gpu else "-headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CAMPAIGN_REENTRY ",JSON.stringify({"before_fix":before_fix,"passed":passed,"failed":failed,"failures":failures,"records":records.size(),"renderer":DisplayServer.get_name()}))
	campaign.free();surface.free();quit(0 if failed==0 else 1)
