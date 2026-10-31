extends RefCounted
## Shared real pointer gesture for chapter-two regressions. Never mutates gameplay state.
static func drag(surface: Viewport,view: Node3D,fraction:=1.0,touch:=false) -> void:
	var origin: Vector2=view.drag_grab_screen()
	var travel: Vector2=view.drag_path_screen()*fraction
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
