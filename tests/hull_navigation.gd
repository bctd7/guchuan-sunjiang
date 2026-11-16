extends RefCounted
## Open chapter-two's local page using the actual task-card button.
static func click(surface: Viewport,point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		surface.push_input(event,true)
		await surface.get_tree().process_frame
	await surface.get_tree().process_frame
static func open_local(surface: Viewport,level: Node,id: String) -> void:
	if level.view.inspected and level.state.selected==id:return
	if level.view.inspected:
		if level.state.next_in_group()==id:
			await click(surface,level.panel.next_piece_button.get_global_rect().get_center())
			return
		await click(surface,level.panel.overview_button.get_global_rect().get_center())
	if level.state.selected!=id:
		await click(surface,level.panel.inventory_button.get_global_rect().get_center())
		await click(surface,level.panel.group_buttons[level.Rules.group_for(id)].get_global_rect().get_center())
	var delay: int=level.interaction._last_touch_ms+470-Time.get_ticks_msec()
	if delay>0:await surface.get_tree().create_timer(float(delay)/1000.0).timeout
	await click(surface,level.panel.observe_button.get_global_rect().get_center())
