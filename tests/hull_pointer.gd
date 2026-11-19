extends RefCounted
## Shared real pointer gesture for assembly regressions. Never mutates gameplay state.
static func drag(surface: Viewport,view: Node3D,fraction:=1.0,touch:=false) -> void:
	var origin: Vector2=view.drag_grab_screen()
	var travel: Vector2=view.drag_input_path_screen()*fraction
	await _gesture(surface,origin,travel,touch)

static func drag_assembly(surface: Viewport,orbit: Control,fraction:=1.0,touch:=false) -> void:
	var start: Vector2 = orbit.drag_start_screen()
	var path: Vector2 = orbit.target_screen() - start
	var axis := path.normalized() if path.length() >= 18.0 else Vector2.UP
	var grip: Vector2 = start.lerp(orbit.target_screen(),orbit.drag_progress)
	var canvas := orbit.get_global_transform_with_canvas()
	await _gesture(surface,canvas * grip,canvas.basis_xform(axis * clampf(path.length(),80,220) * fraction),touch)

static func _gesture(surface: Viewport,origin: Vector2,travel: Vector2,touch: bool) -> void:
	if touch:
		var start:=InputEventScreenTouch.new()
		start.index=0
		start.position=origin
		start.pressed=true
		surface.push_input(start,true)
	else:
		var start:=InputEventMouseButton.new()
		start.button_index=MOUSE_BUTTON_LEFT
		start.position=origin
		start.global_position=origin
		start.pressed=true
		start.button_mask=MOUSE_BUTTON_MASK_LEFT
		surface.push_input(start,true)
	await surface.get_tree().process_frame
	for i in range(1,13):
		var point: Vector2=origin+travel*float(i)/12.0
		if touch:
			var motion:=InputEventScreenDrag.new()
			motion.index=0
			motion.position=point
			motion.relative=travel/12.0
			surface.push_input(motion,true)
		else:
			var motion:=InputEventMouseMotion.new()
			motion.position=point
			motion.global_position=point
			motion.relative=travel/12.0
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			surface.push_input(motion,true)
		await surface.get_tree().process_frame
	if touch:
		var end:=InputEventScreenTouch.new()
		end.index=0
		end.position=origin+travel
		end.pressed=false
		surface.push_input(end,true)
	else:
		var end:=InputEventMouseButton.new()
		end.button_index=MOUSE_BUTTON_LEFT
		end.position=origin+travel
		end.global_position=end.position
		end.pressed=false
		surface.push_input(end,true)
	await surface.get_tree().process_frame
