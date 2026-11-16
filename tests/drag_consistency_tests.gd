extends "res://tests/inspection_workspace_tests.gd"
var samples: Array=[]

func move_pointer(origin: Vector2,travel: Vector2,release:=true,touch:=false) -> void:
	if touch:
		var press:=InputEventScreenTouch.new();press.index=0;press.position=origin;press.pressed=true;surface.push_input(press,true)
	else:await mouse(origin,true)
	await process_frame
	for index in range(1,9):
		var point:=origin+travel*float(index)/8.0
		if touch:
			var event:=InputEventScreenDrag.new();event.index=0;event.position=point;event.relative=travel/8.0;surface.push_input(event,true)
		else:
			var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=travel/8.0;event.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(event,true)
		await process_frame
	if release:
		if touch:
			var end:=InputEventScreenTouch.new();end.index=0;end.position=origin+travel;end.pressed=false;surface.push_input(end,true)
		else:await mouse(origin+travel,false)
		await process_frame

func sample_gesture(kind: String,zoom: float,touch: bool) -> void:
	await settle(.48) # Separate genuine mouse card clicks from touch emulation.
	await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons.B)
	check(level.state.joint==kind and level.state.opening=="B","explicit selected stock "+kind)
	await button(level.panel.reset_observation_button)
	level.view.zoom_observation(zoom);await settle(.03)
	var canvas: Transform2D=level.view.local_surface.get_global_transform_with_canvas()
	var raw: Vector2=canvas.affine_inverse().basis_xform(level.view.drag_path_screen())
	# Independent acceptance specification, not the production input-path helper.
	var axis:=raw.normalized() if raw.length()>=18.0 else Vector2.UP
	var travel:=clampf(raw.length(),80.0,220.0)
	var start: Vector2=level.view.drag_grab_screen()
	check(level.view.inside_observation(start),"zoom retains an exposed grab point inside the operation area")
	check(level.view.pick_drag_piece(start)=="plank_0a","visible timber owns the hit "+kind)
	await settle(.48)
	await move_pointer(start,canvas.basis_xform(axis*5.0),true,touch)
	check(is_zero_approx(level.view.preview_progress) and level.state.placed.is_empty(),"five logical pixels of jitter do not move or assemble")
	await settle(.48)
	await move_pointer(start,canvas.basis_xform(axis*travel*.4),true,touch)
	check(absf(level.view.preview_progress-.4)<.002 and level.state.placed.is_empty(),"40% input is 40% preview across scale, zoom and type "+kind+"/"+str(zoom)+" actual="+str(level.view.preview_progress)+" travel="+str(level.interaction._travel)+" expected="+str(travel))
	await settle(.48)
	await move_pointer(level.view.drag_grab_screen(),canvas.basis_xform(axis*travel*.2),true,touch)
	check(absf(level.view.preview_progress-.6)<.002,"re-grab continues from the actual partial position")
	await settle(.48)
	await move_pointer(level.view.drag_grab_screen(),canvas.basis_xform(axis.orthogonal()*40),true,touch)
	check(absf(level.view.preview_progress-.6)<.002,"perpendicular motion cannot increase insertion")
	await settle(.48)
	await move_pointer(level.view.drag_grab_screen(),canvas.basis_xform(-axis*travel*.6),true,touch)
	check(level.view.preview_progress<.002 and level.state.placed.is_empty(),"withdrawal restores the separated position")
	samples.append({"size":str(surface.size),"type":kind,"zoom":zoom,"raw_logical_pixels":raw.length(),"input_logical_pixels":travel,"touch":touch})

func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	level=load("res://levels/level02/level02.tscn").instantiate();surface.add_child(level);await settle(.1)
	await button(level.learning.start_button);await button(level.panel.observe_button)
	for size_value in [Vector2i(1440,900),Vector2i(960,600)]:
		surface.size=size_value;await settle(.1)
		for kind in ["tongue_groove","cross_lap","three_way_lap"]:
			for zoom in [.25,1.0,1.6]:await sample_gesture(kind,zoom,size_value.x==960)
	await settle(.48)
	await button(level.panel.joint_buttons.tongue_groove);await button(level.panel.opening_buttons.B)
	await button(level.panel.reset_observation_button);await settle(.5)
	# End-on projection used to reject the press outright. The same arrow and
	# logical upward stroke must now remain usable even at zero projected depth.
	var center: Vector3=level.view.socket_position("plank_0a","A")
	var offset: Vector3=level.view.preview_offset("plank_0a")
	level.panel.observation_orbit.set_process(false)
	level.view.camera.position=center+offset.normalized()*10;level.view.camera.look_at(center,Vector3.UP)
	await process_frame
	var canvas: Transform2D=level.view.local_surface.get_global_transform_with_canvas()
	check(level.view.drag_path_screen().length()<1.0,"end-on setup has no projected insertion length")
	await move_pointer(level.view.drag_grab_screen(),canvas.basis_xform(Vector2(0,-32)))
	check(absf(level.view.preview_progress-.4)<.002,"end-on camera retains bounded, directed insertion")
	level.panel.observation_orbit.set_process(true)
	await button(level.panel.reset_observation_button)
	level.interaction.cancel();await settle(.05)
	var resize_start: Vector2=level.view.drag_grab_screen()
	await move_pointer(resize_start,canvas.basis_xform(Vector2(0,25)),false)
	surface.size=Vector2i(1100,800);await settle(.1)
	check(not level.interaction.dragging and is_zero_approx(level.view.preview_progress) and level.state.placed.is_empty(),"window resize cancels the old coordinate-space gesture")
	await mouse(resize_start,false)
	canvas=level.view.local_surface.get_global_transform_with_canvas()
	var raw: Vector2=canvas.affine_inverse().basis_xform(level.view.drag_path_screen())
	var axis:=raw.normalized() if raw.length()>=18 else Vector2.UP
	var travel:=clampf(raw.length(),80,220)
	await move_pointer(level.view.drag_grab_screen(),canvas.basis_xform(axis*travel*.70))
	check(level.state.placed.is_empty() and absf(level.view.preview_progress-.70)<.002,"70% shallow release stays loose")
	await move_pointer(level.view.drag_grab_screen(),Vector2.ZERO)
	check(level.state.placed.is_empty(),"tap on partly inserted timber cannot assemble it")
	var last_start: Vector2=level.view.drag_grab_screen()
	var last_travel: Vector2=canvas.basis_xform(axis*travel*.10)
	await move_pointer(last_start,last_travel,false)
	check(level.state.placed.is_empty(),"crossing threshold while held waits for release")
	await mouse(last_start+last_travel,false);await wait_motion()
	check(level.state.placed.size()==6 and not level.state.failed,"one committed gesture installs exactly one board group")
	if gpu:check(not root.has_focus(),"GPU fixture keeps user focus")
	level.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"samples":samples,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/three-groups")
	FileAccess.open("res://tests/evidence/three-groups/drag-"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DRAG_CONSISTENCY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
