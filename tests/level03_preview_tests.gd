extends SceneTree
## Targeted visual fixtures for the final candidate crop and cap motion repair.
var level: Node3D
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/level03_evidence/gallery-"+label+"-final.png")
func run() -> void:
	root.size = Vector2i(1440,900)
	level = load("res://levels/level03/level03.tscn").instantiate()
	root.add_child(level)
	level.learning.start_button.pressed.emit()
	await capture("zrail")
	level.state.selected = "leg"
	level.state.placed = ["zrail"]
	level._refresh()
	await capture("leg")
	level.state.stage_idx = 1
	level.state.selected = "top"
	level.state.placed = ["zrail","leg","mast","apron"]
	level._refresh()
	await capture("top")
	level.state.stage_idx = 2
	level.state.selected = "lbrace"
	level.state.placed.append("top")
	level._refresh()
	await capture("L")
	level.state.selected = "blade"
	level.state.placed.append_array(["lbrace","rudder","blade"])
	level._refresh()
	level.view.animate_place("blade")
	await create_timer(.4).timeout
	var cap: Node3D = level.view.pieces.blade.get_node("SideCap")
	assert(absf(cap.global_position.z-1.3)<.01,"opposite cap must remain parked at world Z +1.3 during back-half insertion")
	await capture("blade-first-stage")
	await create_timer(.9).timeout
	assert(absf(cap.global_position.z)<.01,"opposite cap must close only after back half seats")
	print("LEVEL03_TARGETED_VISUAL PASS: four full joint-end crop fixtures and fixed-world opposite cap animation")
	quit()
