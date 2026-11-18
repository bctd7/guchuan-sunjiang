extends Control
signal replay_finished
var replay_mode := false
const Style=preload("res://shared/ui/workshop_ui_style.gd")
@export var video_path := "res://assets/welcome/introduction.ogv"
enum Phase { READY, VIDEO, ENTERING }
var phase := Phase.READY
var frame: Control
var player: VideoStreamPlayer
var skip: Button
var elapsed := 0.0
var stalled := 0.0
var last_position := -1.0
func _ready() -> void:
	var black=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
	frame=Control.new();frame.size=Vector2(1920,1080);add_child(frame)
	player=VideoStreamPlayer.new();player.size=Vector2(1920,1080);player.expand=true;player.bus="Music";player.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_child(player);player.finished.connect(_enter_campaign)
	skip=Button.new();skip.text="跳过介绍";skip.position=Vector2(1640,980);skip.size=Vector2(220,72)
	skip.add_theme_font_override("font",Style.font(400));skip.add_theme_font_size_override("font_size",22)
	for state in ["normal","hover","pressed"]:
		var box=StyleBoxFlat.new();box.bg_color=Color(0.08,0.10,0.08,.30 if state=="normal" else .55)
		box.set_corner_radius_all(12);skip.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color"]:skip.add_theme_color_override(state,Color("f6f0e3"))
	frame.add_child(skip);skip.pressed.connect(_enter_campaign)
	get_viewport().size_changed.connect(_fit);_fit();_play_video()
func _fit() -> void:
	var available=get_viewport_rect().size
	var factor=minf(available.x/1920,available.y/1080)
	frame.scale=Vector2.ONE*factor;frame.position=(available-Vector2(1920,1080)*factor)/2
func _play_video() -> void:
	if phase==Phase.ENTERING or phase==Phase.VIDEO:return
	player.stop();player.stream=null
	if not ResourceLoader.exists(video_path):_enter_campaign();return
	var stream=load(video_path)
	if not stream is VideoStream:_enter_campaign();return
	phase=Phase.VIDEO;skip.show();player.show()
	elapsed=0;stalled=0;last_position=-1
	var audio=get_node_or_null("/root/GameAudio")
	if audio!=null:audio.pause_for_video(true)
	player.stream=stream;player.play()
func _process(delta: float) -> void:
	if phase!=Phase.VIDEO:return
	elapsed+=delta
	var position=player.stream_position
	stalled=stalled+delta if is_equal_approx(position,last_position) else 0.0
	last_position=position
	# Broken decoder/device must never strand visitors on an opaque player.
	if elapsed>25 or stalled>3:_enter_campaign()
func _enter_campaign() -> void:
	if phase==Phase.ENTERING:return
	phase=Phase.ENTERING;skip.disabled=true
	player.stop();player.stream=null
	var audio=get_node_or_null("/root/GameAudio")
	if audio!=null:audio.pause_for_video(false)
	# Defer scene replacement so missing-video fallback is safe during _ready.
	_finish_entry.call_deferred()
func _finish_entry() -> void:
	if replay_mode:
		replay_finished.emit()
		return
	var error=get_tree().change_scene_to_file("res://campaign/campaign.tscn")
	if error!=OK:
		phase=Phase.READY;skip.text="进入章节目录";skip.disabled=false
func _exit_tree() -> void:
	player.stop()
	var audio=get_node_or_null("/root/GameAudio")
	if audio!=null:audio.pause_for_video(false)
