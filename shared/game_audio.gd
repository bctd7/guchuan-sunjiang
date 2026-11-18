extends Node
## Persistent music, one seating voice and one quiet UI voice; no delayed queue.
signal seat_played(owner_id: int)
const CONFIG="user://audio.cfg"
var music: AudioStreamPlayer
var music_fade: Tween
var video_paused := false
var effects: AudioStreamPlayer
var feedback: AudioStreamPlayer
var tap: AudioStream
var _last_ui_ms := -1000
signal feedback_played(kind: String)
var clips: Array[AudioStream]=[]
var effect_owner := 0
var sequence := 0
var gains={"Music":-19.0,"SFX":-9.0}
var muted={"Music":false,"SFX":false}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	for bus in gains:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus),"Master")
	var config=ConfigFile.new()
	if config.load(CONFIG)==OK:
		for bus in gains:
			gains[bus]=clampf(float(config.get_value(bus,"volume_db",gains[bus])),-60,0)
			muted[bus]=bool(config.get_value(bus,"muted",false))
	_apply()
	music=AudioStreamPlayer.new();music.bus="Music";add_child(music)
	effects=AudioStreamPlayer.new();effects.bus="SFX";add_child(effects)
	feedback=AudioStreamPlayer.new();feedback.bus="SFX";add_child(feedback)
	get_tree().node_added.connect(_node_added)
	_scan_buttons.call_deferred(get_tree().root)
	var path="res://assets/audio/workshop_loop.ogg"
	if ResourceLoader.exists(path):
		music.stream=load(path)
		if music.stream is AudioStreamOggVorbis:music.stream.loop=true
		music.volume_db=-60;music.play()
		music_fade=create_tween()
		music_fade.tween_property(music,"volume_db",0.0,2.5)
	if ResourceLoader.exists("res://assets/audio/ui_tap.wav"):tap=load("res://assets/audio/ui_tap.wav")
	for index in 3:
		path="res://assets/audio/wood_seat_%d.wav"%index
		if ResourceLoader.exists(path):clips.append(load(path))
func _apply() -> void:
	for bus in gains:
		var index=AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index,gains[bus]);AudioServer.set_bus_mute(index,muted[bus])
func configure(bus: String, volume_db: float, mute: bool, persist:=true) -> void:
	if not gains.has(bus):return
	gains[bus]=clampf(volume_db,-60,0);muted[bus]=mute;_apply()
	if persist:
		var config=ConfigFile.new()
		for key in gains:
			config.set_value(key,"volume_db",gains[key]);config.set_value(key,"muted",muted[key])
		config.save(CONFIG)
func seat(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or clips.is_empty():return
	# Each clip ends in 240 ms. Monophonic playback bounds loudness during batches.
	effect_owner=owner.get_instance_id()
	var cleanup=cancel.bind(owner)
	if not owner.tree_exiting.is_connected(cleanup):owner.tree_exiting.connect(cleanup,CONNECT_ONE_SHOT)
	effects.stream=clips[sequence%clips.size()];sequence+=1
	effects.play();seat_played.emit(effect_owner)
func cancel(owner: Node) -> void:
	if is_instance_valid(owner) and owner.get_instance_id()==effect_owner:effects.stop()
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not event.ctrl_pressed or not event.shift_pressed:return
	var bus="Music" if event.keycode in [KEY_F5,KEY_F6,KEY_F9] else "SFX"
	if event.keycode in [KEY_F5,KEY_F6,KEY_F7,KEY_F8]:
		configure(bus,gains[bus]+(-2 if event.keycode in [KEY_F5,KEY_F7] else 2),muted[bus])
	elif event.keycode in [KEY_F9,KEY_F10]:configure(bus,gains[bus],not muted[bus])
	else:return
	get_viewport().set_input_as_handled()

# Subscribe to actual successful button activation, not raw pointer-down events.
func _node_added(node: Node) -> void:
	if node is BaseButton:_bind_button.call_deferred(weakref(node))
func _scan_buttons(node: Node) -> void:
	if node is BaseButton:_bind_button(weakref(node))
	for child in node.get_children():_scan_buttons(child)
func _bind_button(reference: WeakRef) -> void:
	var button=reference.get_ref()
	if button==null or button.has_meta("audio_bound"):return
	button.set_meta("audio_bound",true)
	button.pressed.connect(func():
		var live=reference.get_ref()
		if live==null or live.disabled:return
		var words: String=live.text if live is Button else ""
		var kind="reset" if "重新" in words else ("undo" if "撤回" in words or "取回" in words else "click")
		play_feedback(kind))
func play_feedback(kind: String) -> void:
	if clips.is_empty():return
	var result=kind in ["success","failure"]
	var now=Time.get_ticks_msec()
	if not result and (now-_last_ui_ms<110 or effects.playing or feedback.playing):return
	_last_ui_ms=now
	feedback.stream=tap if tap!=null else clips[0]
	feedback.pitch_scale={"click":1.5,"undo":.85,"reset":.95,"success":1.25,"failure":.7}.get(kind,1.5)
	feedback.volume_db=-5 if result else -13
	feedback.play();feedback_played.emit(kind)
func watch_result(panel: CanvasItem, kind: String) -> void:
	panel.visibility_changed.connect(func():
		if not panel.visible:
			panel.set_meta("audio_announced",false)
		elif panel.is_visible_in_tree() and not panel.get_meta("audio_announced",false):
			panel.set_meta("audio_announced",true)
			play_feedback(kind))

func pause_for_video(paused: bool) -> void:
	if video_paused==paused:return
	video_paused=paused
	if is_instance_valid(music_fade):music_fade.kill()
	music.stream_paused=paused
	if not paused and music.playing:
		music.volume_db=-60
		music_fade=create_tween()
		music_fade.tween_property(music,"volume_db",0.0,1.2)
