extends SceneTree
## Actual pointer activation of the directory replay; retained campaign and audio state.
var failures: Array[String]=[]
var passed:=0
var surface: SubViewport
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok:passed+=1
	else:failures.append(message);push_error(message)
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;surface.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		surface.push_input(event,true);await process_frame
	await process_frame
func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	var campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign)
	await create_timer(.3).timeout
	var original_id:int=campaign.get_instance_id()
	var audio=root.get_node("GameAudio")
	var gains:Dictionary=audio.gains.duplicate()
	var muted:Dictionary=audio.muted.duplicate()
	campaign.completed[2]=true
	for mode in ["skip","finished"]:
		await click(campaign.menu_root.replay_button)
		check(is_instance_valid(campaign.replay_layer) and not campaign.menu.visible,"replay opens and hides directory "+mode)
		var layer=campaign.replay_layer
		var welcome=layer.get_child(0)
		await create_timer(.3).timeout
		check(welcome.phase==welcome.Phase.VIDEO and welcome.player.is_playing(),"video plays "+mode)
		check(audio.video_paused,"background music paused "+mode)
		for repeat in 5:campaign._replay_welcome()
		check(campaign.replay_layer==layer and layer.get_child_count()==1,"duplicate replay does not create players")
		if mode=="skip":
			await click(welcome.skip)
		else:
			var ended: Array=[]
			welcome.player.finished.connect(func():ended.append(true))
			await create_timer(21).timeout
			check(not ended.is_empty(),"video reaches natural finished signal")
		await create_timer(.2).timeout
		check(not is_instance_valid(campaign.replay_layer) and campaign.menu.visible,"replay returns to directory "+mode)
		check(campaign.get_instance_id()==original_id and campaign.completed.get(2,false),"same campaign and completion preserved "+mode)
		check(not audio.video_paused and audio.gains==gains and audio.muted==muted,"music restored without changing preferences "+mode)
	var missing=load("res://startup/startup.tscn").instantiate()
	missing.replay_mode=true;missing.video_path="res://missing-welcome.ogv"
	var closed: Array=[];missing.replay_finished.connect(func():closed.append(true))
	surface.add_child(missing);await process_frame;await process_frame
	check(closed.size()==1 and is_instance_valid(campaign),"missing replay closes without replacing campaign")
	missing.queue_free()
	await click(campaign.chapter_buttons[1])
	check(campaign.active_level==1,"chapter entry still works after replay")
	campaign._show_menu();await process_frame
	check(campaign.menu.visible and campaign.active_level==0,"chapter return still works after replay")
	print("MENU_REPLAY ",JSON.stringify({"passed":passed,"failed":failures.size(),"failures":failures}))
	campaign.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
