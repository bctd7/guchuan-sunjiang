extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,words: String) -> void:
	if not ok:failures.append(words);push_error(words)
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	for mode in ["finished","skip","missing"]:
		var boot=load("res://startup/startup.tscn").instantiate()
		if mode=="missing":boot.video_path="res://missing.ogv"
		root.add_child(boot);current_scene=boot
		await process_frame
		if mode!="missing":
			if mode=="finished":
				await create_timer(21).timeout
			else:
				await create_timer(.2).timeout
				for i in 10:boot.skip.pressed.emit()
		await create_timer(.5).timeout
		check(current_scene.scene_file_path=="res://campaign/campaign.tscn",mode+" goes directly to directory")
		check(not root.get_node("GameAudio").music.stream_paused,mode+" restores music")
		current_scene.free();current_scene=null
	print("STARTUP_DIRECT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
