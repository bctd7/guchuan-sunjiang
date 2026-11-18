extends SceneTree
var failures: Array[String]=[]
const OUT="res://tests/evidence/exhibition-1080/"
func _initialize() -> void:run.call_deferred()
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=true;event.shift_pressed=true
	Input.parse_input_event(event)
func run() -> void:
	var startup:=root.mode
	if startup!=Window.MODE_FULLSCREEN:failures.append("default native fullscreen")
	root.add_child(load("res://campaign/campaign.tscn").instantiate())
	await create_timer(2).timeout
	key(KEY_F11);await create_timer(.5).timeout
	if root.mode!=Window.MODE_WINDOWED:failures.append("maintenance windowed shortcut")
	root.size=Vector2i(1920,1080);await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	var pixels:=root.get_texture().get_image();pixels.save_png(OUT+"native-window.png")
	var size_value:=pixels.get_size()
	key(KEY_F11);await create_timer(.5).timeout
	if root.mode!=Window.MODE_FULLSCREEN:failures.append("maintenance fullscreen shortcut")
	var report={"failed":failures.size(),"failures":failures,"startup_mode":startup,"native_capture_size":str(size_value),"native_window_size":str(root.size),"viewport":str(root.get_visible_rect()),"renderer":DisplayServer.get_name(),"method":"Native project Window; real startup fullscreen and injected keyboard maintenance toggle twice; Ctrl+Shift+Q triggers quit."}
	FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE ",JSON.stringify(report))
	key(KEY_Q)
	await create_timer(2).timeout
	push_error("maintenance quit did not exit");quit(1)
