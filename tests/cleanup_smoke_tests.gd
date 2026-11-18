extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var campaign=load("res://campaign/campaign.tscn").instantiate()
	root.add_child(campaign)
	for i in 8:await process_frame
	for chapter in [1,2,3]:
		campaign.open_level(chapter)
		for i in 8:await process_frame
		var level=campaign.instances[chapter]
		check(campaign.active_level==chapter,"enter chapter "+str(chapter))
		level.learning.start_button.pressed.emit()
		for i in 8:await process_frame
		if chapter==1:
			check(level.panel.main_sidebar.find_children("*","BaseButton",true,false)==[level.panel.inspect_button,level.panel.lesson_button],"main sidebar has only observation and story actions")
			check(level.panel.root.find_children("*","BaseButton",true,false).all(func(button):return not button.toggle_mode),"no duplicate toggle selectors on main page")
			check(level.inspector.joint_buttons.size()==3,"real observer joint choices retained")
			check(level.inspector.orbit.get_script().get_base_script().resource_path=="res://levels/shared/inspection_orbit.gd","assembly drag inherits shared orbit directly")
		if chapter==2:
			check(level.Rules.GROUPS.size()==3 and level.Rules.IDS.size()==10,"three groups ten records")
		campaign._show_menu()
		for i in 8:await process_frame
		check(campaign.active_level==0 and campaign.menu.visible,"return directory "+str(chapter))
	campaign.free()
	print("CLEANUP_SMOKE ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
