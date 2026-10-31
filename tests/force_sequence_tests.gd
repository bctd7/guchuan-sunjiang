extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	call_deferred("run")

# Reference zong renders two loads inside one 13.2 s cycle; its inherited
# cycles-based `mode` property is not the load used by the renderer.
func displayed_mode(diagram) -> int:
	return diagram.clock.mode_index() if diagram.reference_active else diagram.mode

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900)
	var demo = load("res://classroom/classroom.tscn").instantiate()
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
		check(d.profile.modes.size() == (2 if id in ["blind_tenon","cross_lap","zong_corner"] else 1),id+": expected retained cases")
		if id == "cross_lap":
			check(d.profile.modes[0].moving == ["lower"] and d.v3(d.profile.modes[0].direction).is_equal_approx(Vector3.RIGHT), "cross_lap: lower member pulls +X first")
			check(d.profile.modes[1].moving == ["upper"] and d.v3(d.profile.modes[1].direction).is_equal_approx(Vector3.BACK), "cross_lap: upper member pulls +Z second")
		if d.reference_active:
			check(is_equal_approx(d.clock.DURATION,13.2), "zong: both loads share the documented 13.2 second scene")
			for load_index in 2:
				d.clock.elapsed=d.clock.LEAD+d.clock.STAGE*load_index+2.0
				var loaded: String="xrail" if load_index==0 else "zrail"
				var fixed: String="zrail" if load_index==0 else "xrail"
				var travel: Vector3=Vector3(.02,0,0) if load_index==0 else Vector3(0,0,.02)
				check(displayed_mode(d)==load_index and d.profile.modes[displayed_mode(d)].moving==[loaded], "zong: actual renderer selects "+loaded)
				check(d.displacement().is_equal_approx(travel) and d.part_offset(loaded,travel).is_equal_approx(travel), "zong: actual loaded rail moves to its documented contact")
				check(d.part_offset(fixed,travel).is_zero_approx() and d.part_offset("leg",travel).is_zero_approx(), "zong: other rail and leg remain fixed")
			d.clock.restart()
		d._fit(d.view_data())
		var origin: Vector2 = d.draw_origin
		var scale: float = d.draw_scale
		for turn in range(20):
			check(not d.profile.modes[displayed_mode(d)].removable,id+": no removal case in autoplay")
			d.clock.elapsed = (d.clock.LEAD+d.clock.STAGE if d.reference_active and turn%2 == 0 else d.clock.DURATION)-.01
			var before: Vector3 = d.displacement()
			d.advance(.02)
			check(displayed_mode(d) == (turn+1)%d.profile.modes.size(),id+": sequential automatic load")
			check(before.distance_to(d.displacement()) < .00001,id+": no movement jump at case boundary")
			d._fit(d.view_data())
			check(d.draw_origin.is_equal_approx(origin) and is_equal_approx(d.draw_scale,scale),id+": fixed picture/framing across all cases")
		var phase: int = displayed_mode(d)
		for key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_TAB]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = true
			root.push_input(event,true)
			await process_frame
			check(displayed_mode(d) == phase,id+": keyboard cannot switch case")
		p.close()
		var time: float = d.clock.elapsed
		d.advance(50)
		check(d.clock.elapsed == time,id+": closed animation stopped")
		p.show_joint(id)
		check(displayed_mode(d) == 0 and d.clock.elapsed == 0,id+": reopen starts first load")
		p.close()
	demo.free()
	print("AUTOMATIC LOAD SEQUENCE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
