extends SceneTree
var failures: Array[String]=[]
var heard: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:failures.append(message)
func wait_sound() -> void:await create_timer(.45).timeout
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	var mixer=root.get_node("GameAudio")
	check(AudioServer.get_driver_name()!="Dummy","real audio output")
	mixer.feedback_played.connect(func(kind):heard.append(kind))
	var record=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record);record.set_recording_active(true)
	var button=Button.new();button.text="观察";button.position=Vector2(100,100);button.size=Vector2(220,80);root.add_child(button)
	await process_frame;await process_frame
	for text in ["观察","选择木料","撤回一步","重新搭建"]:
		button.text=text
		for pressed in [true,false]:
			var event=InputEventMouseButton.new();event.position=Vector2(150,130);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			root.push_input(event,true);await process_frame
		await wait_sound()
	check(heard==["click","click","undo","reset"],"button categories through pointer input")
	button.disabled=true;button.pressed.emit();await wait_sound()
	check(heard.size()==4,"disabled button silent")
	button.free()
	for chapter in [1,2,3]:
		var level=load("res://levels/level0%d/level0%d.tscn"%[chapter,chapter]).instantiate();root.add_child(level)
		await process_frame;level.learning.start_button.pressed.emit();await wait_sound()
		var count=heard.size()
		level.panel.success_panel.show();await wait_sound()
		check(heard.size()==count+1 and heard.back()=="success","success once chapter "+str(chapter))
		level.panel.success_panel.show();await wait_sound()
		check(heard.size()==count+1,"refresh does not repeat success")
		if chapter<3:
			level.panel.failure_overlay.show();await wait_sound()
			check(heard.back()=="failure","failure result chapter "+str(chapter))
		level.free();await process_frame
	mixer.play_feedback("click");mixer.play_feedback("click");await wait_sound()
	record.set_recording_active(false)
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/audio")
	record.get_recording().save_to_wav("res://tests/evidence/audio/feedback-preview.wav")
	var report={"driver":AudioServer.get_driver_name(),"failures":failures,"events":heard,"scope":"actual button pointer input; result panels directly displayed to test wiring, not full gameplay verdicts"}
	FileAccess.open("res://tests/evidence/audio/feedback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FEEDBACK_AUDIO ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
