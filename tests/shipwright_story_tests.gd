extends SceneTree
## Headless control/lifecycle checks; no foreground window or human GUI claim.
const Story = preload("res://levels/level01/shipwright_story.gd")
var passed := 0
var failed := 0
var closed_count := 0

class SourceInput extends Node:
	var cancel_count := 0
	func cancel() -> void: cancel_count += 1
	func _input(_event: InputEvent) -> void: pass
	func _unhandled_input(_event: InputEvent) -> void: pass
	func _unhandled_key_input(_event: InputEvent) -> void: pass
	func _shortcut_input(_event: InputEvent) -> void: pass

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(description)

func flags(source: Node) -> Array:
	return [source.is_processing_input(), source.is_processing_unhandled_input(), source.is_processing_unhandled_key_input(), source.is_processing_shortcut_input()]

func run() -> void:
	root.size = Vector2i(1440, 900)
	var source := SourceInput.new()
	root.add_child(source)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(4, 3, 8)
	camera.rotation = Vector3(.2, .3, 0)
	camera.make_current()
	var piece := Node3D.new()
	root.add_child(piece)
	piece.position = Vector3(1, 2, 3)
	var state := {"placed": ["rib_l1"], "selected": "beam1", "revision": 7}
	var state_before: Dictionary = state.duplicate(true)
	var camera_before: Transform3D = camera.transform
	var piece_before: Transform3D = piece.transform
	var story := Story.new()
	root.add_child(story)
	story.closed.connect(func(): closed_count += 1)
	await process_frame
	check(story.layer == 35 and not story.opened and not story.root.visible, "optional overlay starts hidden at layer 35")
	check(story.root.mouse_filter == Control.MOUSE_FILTER_STOP and not story.root.mouse_force_pass_scroll_events, "full-screen root blocks pointer and wheel pass-through")
	check(story.root.get_child(0).mouse_filter == Control.MOUSE_FILTER_STOP, "shade blocks backdrop clicks")
	for mask in range(16):
		source.set_process_input(bool(mask & 1))
		source.set_process_unhandled_input(bool(mask & 2))
		source.set_process_unhandled_key_input(bool(mask & 4))
		source.set_process_shortcut_input(bool(mask & 8))
		var before := flags(source)
		story.show_story(source)
		check(story.opened and story.root.visible, "opens mask %d" % mask)
		check(flags(source) == [false, false, false, false], "suspends all source input flags %d" % mask)
		story.show_story(source)
		check(source.cancel_count == mask + 1, "repeated opening does not replace saved state %d" % mask)
		story.close_button.pressed.emit()
		check(not story.opened and flags(source) == before, "button restores exact flags %d" % mask)
		story.close()
	check(closed_count == 16, "closed emitted exactly once per visit")
	var source_button := Button.new()
	source_button.position = Vector2(8, 8)
	source_button.size = Vector2(160, 60)
	root.add_child(source_button)
	var backdrop_presses := [0]
	source_button.pressed.connect(func(): backdrop_presses[0] += 1)
	source_button.grab_focus()
	story.show_story(source)
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = Vector2(30, 30)
		mouse.pressed = pressed
		root.push_input(mouse)
	check(backdrop_presses[0] == 0, "full-screen shade consumes click over underlying button")
	check(story.close_button.has_focus(), "close button receives keyboard focus")
	for viewport_size in [Vector2i(1440, 900), Vector2i(960, 600)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(story.close_button.get_global_rect()), "close button remains in viewport %s" % viewport_size)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	story._input(key)
	check(not story.opened and closed_count == 17, "Escape closes the optional story")
	check(source_button.has_focus(), "closing restores previous visible focus")
	check(camera.transform == camera_before and root.get_camera_3d() == camera, "camera stays current with identical transform")
	check(piece.transform == piece_before and state == state_before, "model pose and source assembly state unchanged")
	check(not paused, "SceneTree is never paused")
	story.show_story()
	story.close()
	check(closed_count == 18, "null-source story round-trip")
	story.show_story(source)
	source.free()
	story.close()
	check(closed_count == 19, "safe close after source was freed")
	var source2 := SourceInput.new()
	root.add_child(source2)
	source2.set_process_unhandled_input(false)
	var before_removal := flags(source2)
	story.show_story(source2)
	story.free()
	check(flags(source2) == before_removal, "removing open overlay restores source input")
	print("SHIPWRIGHT STORY: %d passed, %d failed (headless control and lifecycle checks)" % [passed, failed])
	quit(0 if failed == 0 else 1)
