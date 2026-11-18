extends "res://tests/campaign_tests.gd"
var audio_events: Array=[]
var mixer
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	root.size=Vector2i(1920,1080)
	mixer=root.get_node("GameAudio")
	check(AudioServer.get_driver_name()!="Dummy","real audio driver")
	mixer.configure("Music",-19,false,false);mixer.configure("SFX",-9,false,false)
	mixer.seat_played.connect(func(owner):audio_events.append({"owner":owner,"ms":Time.get_ticks_msec()}))
	var record=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record);record.set_recording_active(true)
	campaign=load("res://campaign/campaign.tscn").instantiate();root.add_child(campaign)
	await settle(3)
	check(mixer.music.playing and mixer.clips.size()==3,"music and effects loaded")
	var music_id=mixer.music.get_instance_id()
	mixer.music.seek(62.5);await settle(3)
	check(mixer.music.playing and mixer.music.get_playback_position()<5,"music loops without restarting node")
	for chapter in [1,2,3]:
		await enter(chapter)
		check(mixer.music.get_instance_id()==music_id and mixer.music.playing,"continuous music chapter "+str(chapter))
		var before=audio_events.size()
		if chapter==1:
			await place_l1("rib_l1")
			check(audio_events.size()==before+6,"first manual and automatic seating audio")
		elif chapter==2:
			await place_l2("plank_0a")
			check(audio_events.size()==before+6,"second manual and automatic seating audio")
		else:
			await place_l3("zrail")
			check(audio_events.size()==before+1,"third seating exactly once")
		before=audio_events.size()
		await button(level.panel.undo_button);await settle(.4)
		check(audio_events.size()==before,"undo silent "+str(chapter))
		await button(level.panel.restart_button);await back();await settle(.4)
		check(audio_events.size()==before,"reset and directory no stale audio "+str(chapter))
	# Real GUI wrong choice that physically seats must sound identically.
	await enter(1)
	await button(level.panel.inspect_button)
	var silent_start=audio_events.size()
	await button(level.inspector.joint_buttons.dovetail)
	await button(level.inspector.length_buttons.short)
	check(audio_events.size()==silent_start,"wrong selection is silent")
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position("rib_l1"))
	await settle(2.5);await close_l1()
	var deadline=Time.get_ticks_msec()+15000
	while level.busy and Time.get_ticks_msec()<deadline:await process_frame
	await settle(.25)
	check(audio_events.size()==silent_start+6,"wrong seated wood and repeats use physical sound")
	await back()
	# Boundary regression uses the actual blocked animation and cancellation path.
	await enter(2)
	var before_block=audio_events.size()
	level._animate_contact_stop("plank_0a","音频边界测试")
	await settle(1.5)
	check(audio_events.size()==before_block,"blocked contact is silent")
	level._restart()
	level._animate_contact_stop("plank_0a","取消回调测试")
	level._cancel_placement();await settle(1)
	check(audio_events.size()==before_block,"cancelled callback is silent")
	campaign._show_menu();await settle(.4)
	mixer.configure("Music",-30,true,false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"music independent mute")
	mixer.configure("SFX",-20,true,false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"effects mute")
	await settle(.5)
	mixer.configure("Music",-19,false,false);mixer.configure("SFX",-9,false,false)
	record.set_recording_active(false)
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/audio")
	record.get_recording().save_to_wav("res://tests/evidence/audio/game-output.wav")
	var report={"driver":AudioServer.get_driver_name(),"passed":passed,"failed":failed,"failures":failures,"events":audio_events,"music_position":mixer.music.get_playback_position(),"scope":"Actual GPU runtime, CoreAudio output and engine bus recording; no acoustic microphone or human listening claim"}
	FileAccess.open("res://tests/evidence/audio/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AUDIO ",JSON.stringify(report));campaign.free();quit(0 if failed==0 else 1)
