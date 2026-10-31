extends SceneTree
## Actual GPU specimens + all classroom entry views. Scripted setup, no hardware input.
const OUTPUT := "res://tests/evidence/wood-materials/"
const Preview = preload("res://classroom/display/lesson_model_preview.gd")
const Workshop = preload("res://classroom/classroom.gd")
var surface: SubViewport
var images: Array[String] = []
var failures: Array[String] = []
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(label: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels := surface.get_texture().get_image()
	check(not pixels.is_empty(), "GPU pixels " + label)
	check(pixels.save_png(OUTPUT + label + ".png") == OK, "save " + label)
	images.append(OUTPUT + label + ".png")
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	check(root.get_flag(Window.FLAG_NO_FOCUS), "no-focus host")
	check(DisplayServer.get_name() != "headless", "GPU renderer required")
	if not failures.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	surface = SubViewport.new()
	surface.size = Vector2i(1440, 1050)
	surface.own_world_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("f3ead7")
	background.size = Vector2(1440, 1050)
	surface.add_child(background)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	for i in catalog.size():
		var origin := Vector2((i % 3) * 480, floori(float(i) / 3) * 350)
		var label := Label.new()
		label.position = origin + Vector2(24, 12)
		label.text = str(catalog[i].name)
		label.add_theme_color_override("font_color", Color("544735"))
		label.add_theme_font_size_override("font_size", 22)
		background.add_child(label)
		var preview := Preview.new()
		preview.position = origin + Vector2(15, 48)
		preview.size = Vector2(450, 290)
		background.add_child(preview)
		preview.configure(str(catalog[i].id))
	await create_timer(.5).timeout
	await capture("01-nine-teaching-previews")
	background.free()
	surface.size = Vector2i(1440, 900)
	var workshop := Workshop.new()
	surface.add_child(workshop)
	for i in catalog.size():
		workshop.load_joint(i)
		await capture("workshop-" + str(catalog[i].id))
	workshop.assembly.set_xray(true)
	await capture("workshop-xray")
	workshop.assembly.set_xray(false)
	await capture("workshop-solid-restored")
	workshop.free()
	var level = load("res://levels/level01/level01.tscn").instantiate()
	surface.add_child(level)
	level.learning.start_button.pressed.emit()
	await capture("level01-timber-reference")
	level.free()
	var report := {"failed": failures.size(), "failures": failures, "images": images, "renderer": DisplayServer.get_name(), "no_focus": root.get_flag(Window.FLAG_NO_FOCUS), "method": "Actual GPU SubViewport pixels, minimized NO_FOCUS host; scripted setup, no hardware input."}
	FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("WOOD_VISUAL ", JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
