extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	var demo = load("res://demo/workshop.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var p = demo.force_gallery
	for id in p.profiles:
		p.show_joint(id)
		p.set_process(false)
		await process_frame
		var d = p.diagram
		check(p.panel.find_children("*","Button",true,false).size() == 1,id+": no switch button")
		check(not d.has_method("next_mode"),id+": no manual switch callback")
		check(d.profile.modes.size() == (2 if id in ["blind_tenon","zong_corner"] else 1),id+": expected retained cases")
		d._fit(d.view_data())
		var origin: Vector2 = d.draw_origin
		var scale: float = d.draw_scale
		for turn in range(20):
			check(not d.profile.modes[d.mode].removable,id+": no removal case in autoplay")
			d.clock.elapsed = d.clock.DURATION-.01
			var before: Vector3 = d.displacement()
			d.advance(.02)
			check(d.mode == (turn+1)%d.profile.modes.size(),id+": sequential automatic load")
			check(before.distance_to(d.displacement()) < .00001,id+": no movement jump at case boundary")
			d._fit(d.view_data())
			check(d.draw_origin.is_equal_approx(origin) and is_equal_approx(d.draw_scale,scale),id+": fixed picture/framing across all cases")
		var phase: int = d.mode
		for key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_TAB]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = true
			root.push_input(event,true)
			await process_frame
			check(d.mode == phase,id+": keyboard cannot switch case")
		p.close()
		var time: float = d.clock.elapsed
		d.advance(50)
		check(d.clock.elapsed == time,id+": closed animation stopped")
		p.show_joint(id)
		check(d.mode == 0 and d.clock.elapsed == 0,id+": reopen starts first load")
		p.close()
	demo.free()
	print("AUTOMATIC LOAD SEQUENCE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
