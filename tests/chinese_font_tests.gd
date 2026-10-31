extends SceneTree
## Audit actual UI font resources and render campaign paths without desktop input.
const Fonts = preload("res://shared/chinese_fonts.gd")
var passed := 0
var failures: Array[String] = []
var images: Array[String] = []
var screens: Array[String] = []
var glyphs: Dictionary = {}
var surface: SubViewport
var campaign: Node
var gpu := false
const OUTPUT := "res://tests/evidence/chinese-fonts/"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failures.append(message)
		push_error(message)
func chinese(code: int) -> bool:
	return (code >= 0x3000 and code <= 0x303f) or (code >= 0x3400 and code <= 0x9fff) or (code >= 0xff00 and code <= 0xffef)
func collect(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension() not in ["gd", "json", "tscn", "tres"]: continue
		for character in FileAccess.get_file_as_string(directory.path_join(filename)):
			var code := character.unicode_at(0)
			if chinese(code): glyphs[code] = character
	for child in DirAccess.get_directories_at(directory): collect(directory.path_join(child))
func audit(node: Node) -> void:
	var font: Font
	var text := ""
	if node is Label or node is Button:
		text = node.text
		font = node.get_theme_font("font")
	elif node is RichTextLabel:
		text = node.text
		font = node.get_theme_font("normal_font")
	elif node is Label3D:
		text = node.text
		font = node.font if node.font != null else ThemeDB.fallback_font
	if font != null:
		var contains_chinese := false
		var missing := ""
		var ts := TextServerManager.get_primary_interface()
		for character in text:
			var code := character.unicode_at(0)
			if not chinese(code): continue
			contains_chinese = true
			if not ts.font_has_char(font.get_rids()[0], code): missing += character
		if contains_chinese:
			check(font.get_font_name().begins_with("Noto Sans SC"), "bundled face at " + str(node.get_path()))
			check(missing.is_empty(), "primary face covers actual text at " + str(node.get_path()) + ": " + missing)
	for child in node.get_children(): audit(child)
func capture(label: String) -> void:
	for frame in 8: await process_frame
	audit(campaign)
	screens.append(label)
	if not gpu: return
	RenderingServer.force_draw(false)
	var pixels := surface.get_texture().get_image()
	var path := OUTPUT + label + ".png"
	check(not pixels.is_empty() and pixels.save_png(path) == OK, "actual GPU pixels " + label)
	images.append(path)
func run() -> void:
	gpu = DisplayServer.get_name() != "headless"
	if gpu:
		root.set_flag(Window.FLAG_NO_FOCUS, true)
		root.mode = Window.MODE_MINIMIZED
		for attempt in 20:
			await process_frame
			if root.mode == Window.MODE_MINIMIZED: break
			await create_timer(.05).timeout
		check(root.get_flag(Window.FLAG_NO_FOCUS) and root.mode == Window.MODE_MINIMIZED, "minimized no-focus GPU host")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for directory in ["campaign", "core", "classroom", "levels", "models", "shared"]: collect("res://" + directory)
	var ts := TextServerManager.get_primary_interface()
	for weight in [400, 500, 600]:
		var font := Fonts.font(weight)
		var missing := ""
		for code in glyphs:
			if not ts.font_has_char(font.get_rids()[0], code): missing += glyphs[code]
		check(missing.is_empty(), "all project Chinese glyphs in primary font weight %d: %s" % [weight, missing])
		check(ts.font_get_variation_coordinates(font.get_rids()[0]).get(ts.name_to_tag("wght")) == float(weight), "explicit weight %d" % weight)
	check(ThemeDB.fallback_font.get_font_name().begins_with("Noto Sans SC"), "un-themed controls and Label3D use bundled fallback")
	surface = SubViewport.new()
	surface.size = Vector2i(1440, 900)
	surface.own_world_3d = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign = load("res://campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await capture("01-main-menu")
	for chapter in range(1, 4):
		campaign.open_level(chapter)
		var level: Node = campaign.instances[chapter]
		await capture("chapter-%d-introduction" % chapter)
		for id in level.learning.lesson_ids:
			level.learning.lesson_buttons[id].pressed.emit()
			await capture("lesson-" + id)
			var workshop: Node = level.learning.workshop
			workshop.picker.get_popup().get_theme_font("font")
			if id == "dovetail":
				workshop.dynamic_science.open_for_joint(id)
				await capture("popup-dovetail-force")
				workshop.dynamic_science.close()
			if id == "zong_corner":
				workshop.force_gallery.show_joint(id)
				await capture("popup-zong-force")
				workshop.force_gallery.close()
			level.learning.back_button.pressed.emit()
			await process_frame
		level.learning.start_button.pressed.emit()
		await capture("chapter-%d-assembly" % chapter)
		if chapter == 1:
			level.panel.inspect_button.pressed.emit()
			await capture("popup-joint-inspector")
			level.inspector.close()
			level.story.show_story()
			await capture("popup-story")
			level.story.close()
			level.panel.show_failure()
			await capture("popup-level01-failure")
			level.panel.hide_failure()
		elif chapter == 2:
			level.panel.failure_overlay.open()
			await capture("popup-level02-failure")
			level.panel.failure_overlay.hide()
	var report := {"passed": passed, "failed": failures.size(), "failures": failures, "unique_project_chinese_glyphs": glyphs.size(), "screens": screens, "images": images, "method": "Actual campaign/lesson UI resources and primary glyph coverage; minimized GPU SubViewport when available. Popup calls only exercise UI display, not gameplay validation."}
	FileAccess.open(OUTPUT + ("gpu-report.json" if gpu else "headless-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("CHINESE_FONTS ", passed, " passed; ", failures.size(), " failed; ", glyphs.size(), " unique glyphs; ", screens.size(), " screens")
	surface.free()
	quit(0 if failures.is_empty() else 1)
