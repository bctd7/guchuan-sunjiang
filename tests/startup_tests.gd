extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	var audio := root.get_node("GameAudio")
	for mode in ["loop", "missing", "stalled"]:
		var boot := preload("res://app/startup/startup.tscn").instantiate()
		if mode == "missing":
			boot.video_path = "res://missing.ogv"
		change_scene_to_node(boot)
		await scene_changed
		match mode:
			"loop":
				await click(Vector2(10, 10))
				check(current_scene == boot, "Clicking outside Start keeps the welcome page")
				await create_timer(26.0).timeout
				check(is_instance_valid(boot) and current_scene == boot and boot.player.is_playing(),
					"Welcome video is still playing after the first loop")
			"stalled":
				boot.player.paused = true
				await create_timer(3.3).timeout
		if not is_instance_valid(boot) or current_scene != boot:
			check(false, "%s left the welcome page without Start" % mode)
			continue
		if mode != "loop":
			var poster := boot.frame.get_child(0) as TextureRect
			check(poster != null and poster.texture != null and poster.is_visible_in_tree()
				and not boot.player.visible,
				"%s leaves the welcome poster visible" % mode)
		check(boot.skip.text == "开始体验" and not boot.skip.disabled, "Start is available")
		await click(boot.skip.get_global_rect().get_center())
		await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://app/campaign/campaign.tscn",
			"%s enters the directory after Start" % mode)
		check(not audio.music.stream_paused, "%s restores music" % mode)
	print("STARTUP_WELCOME ", JSON.stringify(failures))
	audio.music.stop()
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
