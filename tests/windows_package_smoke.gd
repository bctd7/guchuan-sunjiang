extends SceneTree
## Run against the exported embedded pack with --main-pack, from outside res://.
var failures: Array[String]=[]
var passed:=0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool,label: String) -> void:
	if value:passed+=1
	else:failures.append(label);push_error(label)
func settle() -> void:
	for index in 12:await process_frame
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_name()!="headless":root.mode=Window.MODE_MINIMIZED
	for path in ["res://assets/welcome/introduction.ogv","res://assets/audio/workshop_loop.ogg","res://assets/audio/wood_seat_0.wav","res://assets/audio/wood_seat_1.wav","res://assets/audio/wood_seat_2.wav","res://assets/audio/ui_tap.wav","res://shared/fonts/NotoSansSC.font.res"]:
		check(ResourceLoader.exists(path) and load(path)!=null,"bundled resource "+path)
	for path in ["res://models/joinery/catalog.json","res://classroom/science/profiles.json","res://classroom/science/force_gallery/profiles.json"]:
		check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path))!=null,"bundled runtime JSON "+path)
	check(not DirAccess.dir_exists_absolute("res://tests") and not DirAccess.dir_exists_absolute("res://docs"),"development evidence excluded")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://startup/startup.tscn","video startup entry")
	check(ProjectSettings.get_setting("display/window/size/mode")==3,"fullscreen default")
	check(ProjectSettings.get_setting("display/window/size/viewport_width")==1920 and ProjectSettings.get_setting("display/window/size/viewport_height")==1080,"1920x1080 viewport")
	check(change_scene_to_file("res://startup/startup.tscn")==OK,"load exported startup scene")
	await settle()
	var startup=current_scene
	check(startup.player.stream!=null and startup.phase==startup.Phase.VIDEO,"video stream starts")
	startup.skip.pressed.emit();await settle()
	var campaign=current_scene
	check(campaign.scene_file_path=="res://campaign/campaign.tscn","video skip enters directory")
	for n in [1,2,3]:
		campaign.chapter_buttons[n].pressed.emit();await settle()
		check(campaign.instances.has(n),"exported chapter loads "+str(n))
		if not campaign.instances.has(n):continue
		var level=campaign.instances[n]
		for id in level.learning.lesson_ids:
			level.learning.lesson_buttons[id].pressed.emit();await settle()
			check(is_instance_valid(level.learning.workshop) and level.learning.workshop.assembly.definition.id==id,"exported lesson "+id)
			level.learning.back_button.pressed.emit();await settle()
		level.learning.start_button.pressed.emit();await settle()
		var story=level.bulkhead_lesson if n==2 else level.story
		story.show_story(level.interaction);await settle()
		check(story.opened,"exported story "+str(n));story.close_button.pressed.emit();await settle()
		check(not story.opened,"exported story closes "+str(n))
		if n==2:
			level.panel.observe_button.pressed.emit();await settle()
			check(level.view.inspected,"exported chapter 2 observer")
			level.panel.overview_button.pressed.emit()
		elif n==1:
			level.panel.inspect_button.pressed.emit();await settle()
			check(level.inspector.opened,"exported chapter 1 observer")
			level.inspector.close_button.pressed.emit()
		else:
			level.panel.inspect_button.pressed.emit();await settle()
			check(level.panel.inspected,"exported chapter 3 observer")
			level.panel.overview_button.pressed.emit()
		await settle();campaign._show_menu();await settle()
		check(not campaign.instances.has(n),"directory discards exported chapter "+str(n))
	var report={"passed":passed,"failures":failures,"platform":OS.get_name(),"renderer":DisplayServer.get_name(),"scope":"Exported Windows EXE embedded pack loaded by matching Mac Godot. Resource/scene smoke only, not native Windows execution."}
	FileAccess.open("/private/tmp/windows-package-smoke.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WINDOWS_PACK_SMOKE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
