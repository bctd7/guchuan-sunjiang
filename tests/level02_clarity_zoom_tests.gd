extends "res://tests/inspection_workspace_tests.gd"
## New rendering/zoom paths use actual Viewport mouse/touch; State is read-only.
func button(control: Button) -> void:
	if is_instance_valid(level) and is_instance_valid(level.interaction):
		var delay: int=level.interaction._last_touch_ms+470-Time.get_ticks_msec()
		if delay>0:await settle(float(delay)/1000.0)
	await super.button(control)
func capture(name: String) -> void:
	if not gpu:return
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/clarity-zoom/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/clarity-zoom"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU image "+name);images.append(path)
func solid_wood(node: Node) -> bool:
	if node is MeshInstance3D:
		var material=node.material_override as StandardMaterial3D
		if material==null or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or not is_equal_approx(material.albedo_color.a,1.0) or material.albedo_texture==null:return false
	for child in node.get_children():
		if not solid_wood(child):return false
	return true
func wheel(point: Vector2,up: bool) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN;event.pressed=down;surface.push_input(event,true);await process_frame
func touch_button(control: Button) -> void:
	var point:=control.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down;surface.push_input(event,true);await process_frame
	await settle(.05)
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
	await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
	await prepare("plank_0a")
	check(level.view.pieces.values().all(func(node):return solid_wood(node)),"all actual stock defaults to opaque textured timber, including uninstalled context")
	check(level.view.fixed.values().all(func(node):return solid_wood(node)),"all receiving wood uses opaque grain")
	for preview in level.panel.gallery.previews.values():check(solid_wood(preview.model_root),"type previews use opaque timber finish")
	for preview in level.panel.opening_gallery.previews.values():check(solid_wood(preview.model_root),"opening previews use opaque timber finish")
	await button(level.panel.transparent_button)
	check(level.view.transparent and solid_wood(level.view.pieces.plank_0a) and not solid_wood(level.view.local_context),"explicit reveal affects the actual first-board receiver section only")
	await button(level.panel.zoom_reset_button)
	check(level.view.transparent and level.panel.transparent_button.button_pressed,"camera reset preserves transparency choice")
	await capture("opaque-local-default")
	var zoom_before: float=level.view.framing.zoom_factor
	await wheel(workspace_rect().get_center(),true)
	check(level.view.framing.zoom_factor<zoom_before and level.state.placed.is_empty(),"wheel changes camera only")
	for i in 14:await button(level.panel.zoom_in_button)
	check(is_equal_approx(level.view.framing.zoom_factor,.25),"visible plus stops at 400 percent")
	var focus: Vector3=level.view.socket_position(level.state.selected,level.state.layout)
	check(workspace_rect().has_point(level.view.project_point(focus)),"zoom keeps the selected connection in the observation region")
	check(not level.view.model_seams.visible,"first fixed-seam task keeps the groove clear of an enlarged end-seam caption")
	await capture("connection-400-percent")
	await touch_button(level.panel.zoom_out_button)
	check(level.view.framing.zoom_factor>.25 and level.state.placed.is_empty(),"touch-friendly minus zooms without installing")
	await button(level.panel.zoom_reset_button)
	check(is_equal_approx(level.view.framing.zoom_factor,1.0) and level.panel.zoom_label.text=="100%","reset restores view and visible percentage")
	await settle(.5)
	await mouse(level.view.drag_grab_screen(),true)
	zoom_before=level.view.framing.zoom_factor;await wheel(workspace_rect().get_center(),true)
	check(is_equal_approx(level.view.framing.zoom_factor,zoom_before),"scrolling cannot change a held wood gesture's projection")
	await mouse(level.view.drag_grab_screen(),false);await settle(.5)
	await Pointer.drag(surface,level.view,.25,true)
	var depth: float=level.view.preview_progress;var choice: String=level.state.opening;var orbit: Vector2=level.panel.opening_gallery.previews.A.orbit.angles
	await button(level.panel.opening_gallery.inspect_buttons.A)
	var modal=level.panel.magnifier
	check(modal.visible and not level.interaction.is_processing_input() and level.state.opening==choice,"enlarge is read-only and suspends installation")
	check(solid_wood(modal.preview.model_root),"enlarged actual opening model stays opaque")
	await button(modal.zoom_in);await wheel(modal.preview.get_global_rect().get_center(),true)
	check(modal.preview.zoom_factor<1 and is_equal_approx(level.view.framing.zoom_factor,1.0),"large candidate zoom is independent of assembly camera")
	await drag_region(modal.preview.get_global_rect(),Vector2(70,-25),true)
	check(modal.preview.orbit.angles.length()>.03 and level.panel.opening_gallery.previews.A.orbit.angles==orbit,"touch rotates the clone without changing its source candidate")
	await capture("opening-enlarged")
	await button(modal.reset_button);check(is_equal_approx(modal.preview.zoom_factor,1.0) and modal.preview.orbit.angles.is_zero_approx(),"candidate reset restores scale and rotation")
	await button(modal.close_button)
	check(not modal.visible and level.state.opening==choice and is_equal_approx(level.view.preview_progress,depth) and level.state.placed.is_empty(),"closing candidate restores input and shallow trial depth without selecting")
	await button(level.panel.gallery.inspect_buttons.three_way_lap);await capture("three-way-type-enlarged")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;surface.push_input(escape,true);await process_frame
	check(not modal.visible and level.state.joint=="tongue_groove","Escape closes enlarged type without changing chosen joint")
	for dimensions in [Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2)
		for control in [level.panel.zoom_in_button,level.panel.zoom_out_button,level.panel.zoom_reset_button,level.panel.opening_gallery.inspect_buttons.A]:
			check(surface.get_visible_rect().encloses(control.get_global_rect()) and control.get_global_rect().size.y>=43.9,"zoom controls fit and retain 44-pixel touch height "+str(dimensions))
		await capture("local-"+str(dimensions.x));await button(level.panel.opening_gallery.inspect_buttons.B);await touch_button(modal.zoom_in)
		check(modal.visible and modal.preview.zoom_factor<1,"scaled touch enlarges opening "+str(dimensions));await capture("enlarged-"+str(dimensions.x));await button(modal.close_button)
	surface.size=Vector2i(1440,900);await settle(.2);await button(level.panel.overview_button)
	for id in level.Rules.IDS:
		if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):continue
		await prepare(id);check(solid_wood(level.view.pieces[id]),"actual correct stock is opaque "+id)
		if id in ["cross_upper","three_middle","bulkhead"]:await capture("opaque-"+id)
		await settle(.5);await Pointer.drag(surface,level.view,1.0,id.ends_with("b"));await wait_motion()
		if not level.state.completed and level.view.inspected:
			if not level.state.next_in_group().is_empty():await button(level.panel.next_piece_button)
			else:await button(level.panel.overview_button)
	check(level.state.completed and not level.state.failed,"new observation tools preserve correct full hull and final sea trial")
	await capture("correct-hull-complete")
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	campaign.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Actual Viewport mouse/simulated touch and real geometry; no business state writes; no human hardware validation"}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/clarity-zoom")
	FileAccess.open("res://tests/evidence/clarity-zoom/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CLARITY_ZOOM ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
