extends SceneTree

class InputConsumer extends Node:
	var received := 0

	func _input(_event: InputEvent) -> void:
		received += 1
		get_viewport().set_input_as_handled()

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func send_input(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	var exhibition := root.get_node("Exhibition")
	var audio := root.get_node("GameAudio")
	change_scene_to_file("res://app/campaign/campaign.tscn")
	await scene_changed
	var campaign := current_scene
	var campaign_id := campaign.get_instance_id()
	exhibition._idle_timeout_msec = 900
	campaign._replay_welcome()
	await create_timer(1.1).timeout
	check(current_scene == campaign and is_instance_valid(campaign.replay_layer),
		"A manual replay is protected from idle return")
	if not is_instance_valid(campaign) or not is_instance_valid(campaign.replay_layer):
		await finish(audio)
		return
	campaign.replay_layer.get_child(0).skip.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene == campaign and campaign.menu.visible,
		"A manual replay restores the original campaign")

	campaign.open_level(1)
	check(campaign.active_level == 1, "Started a chapter before idling")
	var consumer := InputConsumer.new()
	campaign.current_chapter.add_child(consumer)
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_A
	keyboard.pressed = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 10)
	for event in [keyboard, motion, touch, drag]:
		var before: int = exhibition._last_activity_msec
		await process_frame
		send_input(event)
		check(exhibition._last_activity_msec > before,
			"Window activity counted for %s" % event.get_class())
		await create_timer(0.35).timeout
		check(current_scene == campaign, "Repeated activity keeps the chapter open")
	check(consumer.received >= 4, "Chapter still receives the watched input")

	await create_timer(0.85).timeout
	var welcome := current_scene
	check(not is_instance_id_valid(campaign_id), "Idle return frees the previous campaign")
	if welcome == null or welcome.scene_file_path != "res://app/startup/startup.tscn":
		check(false, "Idle return opens the welcome scene")
		await finish(audio)
		return
	check(welcome.player.loop and audio.video_paused,
		"Idle welcome starts looping and pauses workshop music")
	await create_timer(26.0).timeout
	check(current_scene == welcome and welcome.player.is_playing(),
		"Idle welcome keeps playing beyond the first loop and playback watchdog")
	var start := InputEventKey.new()
	start.keycode = KEY_ENTER
	start.pressed = true
	send_input(start)
	start = start.duplicate()
	start.pressed = false
	send_input(start)
	await create_timer(0.25).timeout
	check(current_scene != null and current_scene.scene_file_path == "res://app/campaign/campaign.tscn"
		and current_scene.active_level == 0 and current_scene.current_chapter == null,
		"Start opens a fresh chapter directory")
	check(not audio.video_paused, "Workshop music resumes")
	await create_timer(0.85).timeout
	check(current_scene != null and current_scene.scene_file_path == "res://app/startup/startup.tscn"
		and current_scene.player.loop, "The chapter directory can enter idle mode again")
	await finish(audio)

func finish(audio: Node) -> void:
	audio.music.stop()
	print("EXHIBITION_IDLE ", JSON.stringify(failures))
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
