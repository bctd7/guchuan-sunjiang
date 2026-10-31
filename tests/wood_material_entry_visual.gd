extends SceneTree
## Capture the user's real campaign -> chapter -> observe entry, not an isolated workshop.
var output := "res://tests/evidence/wood-material-entry/"
var surface: SubViewport
var campaign: Node
var images: Array[String] = []
var failures: Array[String] = []
var probes: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(label: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw(false)
	var pixels := surface.get_texture().get_image()
	check(not pixels.is_empty(), "GPU pixels " + label)
	check(pixels.save_png(output + label + ".png") == OK, "save " + label)
	images.append(output + label + ".png")
func inspect_world(node: Node, out: Array) -> void:
	if node is WorldEnvironment:
		out.append({"path": str(node.get_path()), "type": "environment", "background": str(node.environment.background_color), "mode": node.environment.background_mode})
	if node is Light3D:
		out.append({"path": str(node.get_path()), "type": "light", "visible": node.is_visible_in_tree(), "energy": node.light_energy})
	for child in node.get_children(): inspect_world(child, out)
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	check(root.get_flag(Window.FLAG_NO_FOCUS), "no-focus host")
	check(DisplayServer.get_name() != "headless", "GPU renderer required")
	if not failures.is_empty(): quit(2); return
	if not OS.get_cmdline_user_args().is_empty(): output += OS.get_cmdline_user_args()[0] + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface = SubViewport.new()
	surface.size = Vector2i(1440, 900)
	surface.own_world_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign = load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	for chapter in range(1, 4):
		campaign.open_level(chapter)
		var level = campaign.instances[chapter]
		await capture("chapter-%d-introduction" % chapter)
		for id in level.learning.lesson_ids:
			level.learning.lesson_buttons[id].pressed.emit()
			await capture("embedded-" + id)
			var w = level.learning.workshop
			var nodes: Array = []
			inspect_world(level, nodes)
			probes.append({"joint": id, "camera_environment": w.camera.environment != null, "world_environment_background": str(w.get_world_3d().environment.background_color) if w.get_world_3d().environment != null else "null", "nodes": nodes})
			if id == "dovetail":
				surface.size = Vector2i(1000, 625)
				await capture("embedded-dovetail-1000")
				surface.size = Vector2i(1440, 900)
			w.assembly.set_xray(true)
			await capture("xray-" + id)
			w.assembly.set_xray(false)
			level.learning.back_button.pressed.emit()
			await process_frame
		level.learning.start_button.pressed.emit()
		await capture("chapter-%d-returned" % chapter)
	check(not root.has_focus(), "background renderer did not take keyboard focus")
	var report := {"failed": failures.size(), "failures": failures, "images": images, "renderer": DisplayServer.get_name(), "no_focus": root.get_flag(Window.FLAG_NO_FOCUS), "host_had_focus": root.has_focus(), "probes": probes, "method": "Actual campaign chapter lesson buttons -> embedded classroom GPU pixels; minimized NO_FOCUS host, no desktop input."}
	FileAccess.open(output + "report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("WOOD_ENTRY_VISUAL ", failures.size(), " failures; ", images.size(), " images; ", output)
	surface.free()
	quit(0 if failures.is_empty() else 1)
