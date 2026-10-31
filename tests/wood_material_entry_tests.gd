extends SceneTree
## Guard the real campaign entry and unchanged source state/environment on return.
var passed := 0
var failed := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)
func signature(node: Node) -> Array:
	var out: Array = []
	if node is Node3D: out.append(node.transform)
	if node is MeshInstance3D: out.append(node.mesh)
	for child in node.get_children(): out.append(signature(child))
	return out
func run() -> void:
	root.size = Vector2i(1440, 900)
	var campaign = load("res://campaign/campaign.tscn").instantiate()
	root.add_child(campaign)
	for chapter in range(1,4):
		campaign.open_level(chapter)
		var level = campaign.instances[chapter]
		await process_frame
		var source: Node3D = level.learning.source_view
		var environment := source.get_world_3d().environment
		var host_environment: Environment = level.get_world_3d().environment
		var source_environment: Environment = source.camera.environment
		var before := signature(source)
		for id in level.learning.lesson_ids:
			level.learning.lesson_buttons[id].pressed.emit()
			await process_frame
			var workshop = level.learning.workshop
			var camera: Camera3D = workshop.camera
			check(camera.environment != null, "embedded camera owns its timber environment " + id)
			check(camera.environment.background_mode == Environment.BG_COLOR and camera.environment.background_color == Color("f3ead7"), "paper backdrop applies through campaign entry " + id)
			check(camera.get_world_3d().environment == host_environment, "lesson does not replace level world environment " + id)
			check(signature(source) == before, "entry preserves ship transforms and mesh resources " + id)
			level.learning.back_button.pressed.emit()
			await process_frame
			check(source.get_world_3d().environment == environment and source.camera.environment == source_environment, "return preserves level environment " + id)
			check(signature(source) == before, "return preserves ship transforms and mesh resources " + id)
		level.learning.start_button.pressed.emit()
		check(source.is_visible_in_tree() and source.get_viewport().get_camera_3d() == source.camera, "ship view and camera restored for chapter " + str(chapter))
	campaign.free()
	print("WOOD_ENTRY ",passed," passed; ",failed," failed")
	quit(0 if failed == 0 else 1)
