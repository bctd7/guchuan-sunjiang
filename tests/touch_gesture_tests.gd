extends "res://tests/opening_dimensions_tests.gd"
## Real Viewport touch events exercise the shared policy in the two actual chapters.
## Device drivers and physical Windows multitouch remain an on-device check.
var activations := 0
var chapter := 1

func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = point; event.pressed = pressed; event.canceled = canceled
	surface.push_input(event, true)
	await process_frame

func move_touch(index: int, point: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = point; event.relative = delta
	surface.push_input(event, true)
	await process_frame

func pair(control: Control, ratio := 1.5) -> void:
	var rect := control.get_global_rect()
	var center := rect.get_center()
	var offset := Vector2(minf(50, rect.size.x * .22), 0)
	await touch(0, center-offset, true)
	await touch(1, center+offset, true)
	await move_touch(0, center-offset*ratio, -offset*(ratio-1))
	await move_touch(1, center+offset*ratio, offset*(ratio-1))
	await touch(0, center-offset*ratio, false)
	await touch(1, center+offset*ratio, false)
	await settle(.04)

func capture(name: String) -> void:
	if not gpu: return
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	var folder := "res://tests/evidence/touch-gestures"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder+"/"+name+".png"
	check(surface.get_texture().get_image().save_png(path)==OK, "capture "+name)
	images.append(path)

func orbit_surface() -> Control:
	return level.inspector.orbit if chapter==1 else level.view.local_surface

func main_camera() -> Camera3D:
	return level.inspector.camera if chapter==1 else level.view.camera

func main_progress() -> float:
	return level.inspector.orbit.drag_progress if chapter==1 else level.view.preview_progress

func main_zoom() -> float:
	return level.inspector.zoom_factor if chapter==1 else level.view.framing.zoom_factor

func cancel_main() -> void:
	if chapter==1: level.inspector.orbit.cancel()
	else: level.interaction.cancel()

func main_zoom_reset() -> void:
	await settle(.46)
	await button(level.inspector.zoom_bar.reset_button if chapter==1 else level.panel.zoom_reset_button)

func grab() -> Vector2:
	if chapter==2: return level.view.drag_grab_screen()
	var orbit = level.inspector.orbit
	return orbit.get_global_transform_with_canvas()*orbit._project(orbit._parent_world()*(orbit._part.transform*orbit._grab_local))

func drag_path() -> Vector2:
	if chapter==2: return level.view.drag_input_path_screen()
	var orbit = level.inspector.orbit
	var raw: Vector2 = orbit.target_screen()-orbit.drag_start_screen()
	var axis := raw.normalized() if raw.length()>=18 else Vector2.UP
	return orbit.get_global_transform_with_canvas().basis_xform(axis*clampf(raw.length(),80,220))

func drag_stock(fraction: float, release := true) -> void:
	var start := grab()
	var path := drag_path()*fraction
	await touch(0,start,true)
	for i in range(1,9): await move_touch(0,start+path*float(i)/8.0,path/8)
	if release: await touch(0,start+path,false)

func check_main(scope: String) -> void:
	var original: Dictionary = level.state.placed.duplicate(true)
	var camera := main_camera()
	var before := camera.size
	await pair(orbit_surface())
	check(camera.size<before*.8, "two fingers spread zooms the assembly view "+scope)
	await pair(orbit_surface(),.7)
	check(camera.size>before*.85, "two fingers close zooms out "+scope)
	check(level.state.placed==original, "view pinch cannot assemble "+scope)
	await main_zoom_reset()
	await drag_stock(.42,false)
	check(absf(main_progress()-.42)<.005, "single finger actually moves stock to 42 percent "+scope)
	var end := grab()
	var other := orbit_surface().get_global_rect().position+Vector2(35,45)
	var parked := main_progress()
	await touch(1,other,true)
	check(absf(main_progress()-parked)<.005, "second finger parks the real depth "+scope)
	var dragging: bool = level.inspector.orbit.assembly_dragging if chapter==1 else level.interaction.dragging
	check(not dragging, "second finger stops pending assembly submission "+scope)
	before=camera.size
	var away := (other-end).normalized()*35
	await move_touch(1,other+away,away)
	check(not is_equal_approx(camera.size,before), "stock drag switches to pinch "+scope)
	await touch(1,other+away,false)
	await move_touch(0,end+drag_path(),drag_path())
	await touch(0,end+drag_path(),false)
	check(absf(main_progress()-parked)<.005 and level.state.placed==original, "surviving finger cannot move or install after pinch "+scope)
	await drag_stock(.18)
	check(main_progress()>parked+.15 and level.state.placed==original, "fresh single finger resumes parked stock "+scope)
	cancel_main()
	await drag_stock(.3,false)
	await touch(0,grab(),false,true)
	check(is_zero_approx(main_progress()) and level.state.placed==original, "OS canceled touch cannot submit wood "+scope)
	await main_zoom_reset()
	await capture(scope+"-main")

func check_candidates(scope: String) -> void:
	var gallery = level.inspector.length_gallery if chapter==1 else level.panel.opening_gallery
	var id := "correct" if chapter==1 else "B"
	var other_id := "short" if chapter==1 else "A"
	var preview = gallery.previews[id]
	var peer = gallery.previews[other_id]
	var before: float = preview.camera.size
	activations=0
	var callback: Callable=func():activations+=1
	preview.activated.connect(callback)
	await pair(preview)
	check(preview.camera.size<before*.8 and activations==0, "candidate pinch zooms without choosing "+scope)
	if chapter==2:
		for candidate in gallery.previews.values():
			check(is_equal_approx(candidate.camera.size,preview.camera.size), "all A/B/C retain a common scale "+scope)
		await settle(.1)
		if gpu:
			check(is_equal_approx(level.panel.opening_measure.pixel_scale,preview.size.y/preview.camera.size), "reference retains candidate scale during pinch "+scope)
	# Separate cards must not form a pinch or two taps.
	before=preview.camera.size
	var a: Vector2=preview.get_global_rect().get_center()
	var b: Vector2=peer.get_global_rect().get_center()
	await touch(0,a-Vector2(22,0),true); await touch(1,a+Vector2(22,0),true)
	var outside:=Vector2(preview.get_global_rect().end.x+30,a.y)
	await move_touch(1,outside,outside-a-Vector2(22,0))
	check(preview.camera.size<before, "owned pinch continues beyond the model card "+scope)
	await touch(1,outside,false); await touch(0,a-Vector2(22,0),false)
	check(preview.orbit.pinch.points.is_empty() and activations==0, "release outside cannot leave a held finger or choose "+scope)
	before=preview.camera.size
	await touch(0,a,true); await touch(1,b,true)
	await move_touch(0,a+Vector2(24,0),Vector2(24,0))
	await touch(0,a+Vector2(24,0),false); await touch(1,b,false)
	check(is_equal_approx(preview.camera.size,before) and activations==0, "touches on different cards neither zoom nor choose "+scope)
	# A third contact invalidates the pair until ALL contacts have lifted.
	await touch(0,a-Vector2(22,0),true); await touch(1,a+Vector2(22,0),true)
	await touch(2,a,true)
	await move_touch(0,a-Vector2(45,0),Vector2(-23,0))
	await touch(2,a,false)
	await move_touch(1,a+Vector2(45,0),Vector2(23,0))
	await touch(0,a-Vector2(45,0),false); await touch(1,a+Vector2(45,0),false)
	check(is_equal_approx(preview.camera.size,before) and activations==0, "third finger cannot start another pinch or select "+scope)
	# A jittery tap remains a tap; a deliberate one-finger move remains rotation.
	await touch(0,a,true); await move_touch(0,a+Vector2(4,0),Vector2(4,0)); await touch(0,a+Vector2(4,0),false)
	check(activations==1, "small touch jitter preserves candidate tap "+scope)
	var angle: Vector2=preview.orbit.target_angles
	await touch(0,a,true); await move_touch(0,a+Vector2(28,0),Vector2(28,0)); await touch(0,a+Vector2(28,0),false)
	check(activations==1 and preview.orbit.target_angles!=angle, "one finger rotates without selecting "+scope)
	# The touch-generated mouse release must not add another activation.
	for pressed in [true,false]:
		var mouse_event:=InputEventMouseButton.new(); mouse_event.position=a; mouse_event.global_position=a
		mouse_event.button_index=MOUSE_BUTTON_LEFT; mouse_event.pressed=pressed; mouse_event.device=InputEvent.DEVICE_ID_EMULATION
		surface.push_input(mouse_event,true); await process_frame
	check(activations==1, "emulated mouse cannot duplicate a touch selection "+scope)
	await touch(0,a-Vector2(22,0),true); await touch(1,a+Vector2(22,0),true)
	preview.orbit.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await move_touch(0,a-Vector2(45,0),Vector2(-23,0))
	await touch(0,a-Vector2(45,0),false,true); await touch(1,a+Vector2(22,0),false)
	check(not preview.orbit.pinch.active and preview.orbit.pinch.points.is_empty() and activations==1, "focus loss and canceled touch clear ownership "+scope)
	before=preview.camera.size
	await pair(preview,.65)
	check(preview.camera.size>before and activations==1, "fresh pinch works after cancellation "+scope)
	await capture(scope+"-candidates")
	preview.activated.disconnect(callback)

func check_magnifier(scope: String) -> void:
	var gallery=level.inspector.length_gallery if chapter==1 else level.panel.opening_gallery
	var id:="correct" if chapter==1 else "B"
	var magnifier=level.inspector.magnifier if chapter==1 else level.panel.magnifier
	await settle(.46)
	var held:=orbit_surface().get_global_rect().position+Vector2(28,70)
	var inspect_point: Vector2=gallery.inspect_buttons[id].get_global_rect().get_center()
	await touch(0,held,true); await touch(1,inspect_point,true)
	await button(gallery.inspect_buttons[id])
	check(magnifier.visible, "existing magnifier opens "+scope)
	# These releases happen while the main raw-input listener is suspended.
	await touch(0,held,false); await touch(1,inspect_point,false)
	var before: float=magnifier.preview.camera.size
	var background: float=gallery.previews[id].camera.size
	var main_size:=main_camera().size
	var state: Dictionary=level.state.placed.duplicate(true)
	await pair(magnifier.preview)
	check(magnifier.preview.camera.size<before*.8, "magnifier accepts the same pinch "+scope)
	check(is_equal_approx(gallery.previews[id].camera.size,background) and is_equal_approx(main_camera().size,main_size) and level.state.placed==state, "modal pinch leaves underlying previews and assembly alone "+scope)
	await capture(scope+"-magnifier")
	await settle(.46)
	await button(magnifier.close_button)
	check(not magnifier.visible and magnifier.preview.orbit.pinch.points.is_empty(), "closing magnifier clears hidden gesture ownership "+scope)
	var orbit=level.inspector.orbit if chapter==1 else level.panel.observation_orbit
	var angles: Vector2=orbit.target_angles
	await touch(7,held,true); await move_touch(7,held+Vector2(24,12),Vector2(24,12)); await touch(7,held+Vector2(24,12),false)
	check(orbit.target_angles!=angles, "first fresh single touch after modal has no stale fingers "+scope)
	before=main_camera().size
	await pair(orbit_surface(),.8)
	check(main_camera().size>before, "main view pinch resumes after magnifier "+scope)

func check_resize(scope: String) -> void:
	var area:=orbit_surface()
	var center:=area.get_global_rect().get_center()
	await touch(0,center-Vector2(35,0),true); await touch(1,center+Vector2(35,0),true)
	surface.size=Vector2i(1100,800)
	await settle(.15)
	# Camera.size may still fit damped orbit angles after the resize. Check the
	# actual zoom intent and rotation target instead of freezing that animation.
	var before:=main_zoom()
	var orbit=level.inspector.orbit if chapter==1 else level.panel.observation_orbit
	var angles: Vector2=orbit.target_angles
	await move_touch(0,center-Vector2(100,0),Vector2(-65,0))
	await touch(0,center-Vector2(100,0),false); await touch(1,center+Vector2(35,0),false)
	check(is_equal_approx(main_zoom(),before) and orbit.target_angles==angles and is_zero_approx(main_progress()), "resize drops old coordinate-space gesture "+scope)
	await pair(orbit_surface(),1.2)
	check(main_zoom()<before, "new pinch works at resized surface "+scope)

func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu"); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu: root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new(); surface.size=Vector2i(1440,900); surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate(); surface.add_child(campaign); await settle(.2)
	for chapter_id in [1,2]:
		chapter=chapter_id
		await settle(.46)
		await button(campaign.chapter_buttons[chapter]); level=campaign.instances[chapter]
		await button(level.learning.start_button)
		await button(level.panel.inspect_button if chapter==1 else level.panel.observe_button)
		if chapter==1:
			await button(level.inspector.joint_buttons.blind_tenon); await button(level.inspector.length_buttons.correct)
		else:
			await button(level.panel.joint_buttons.tongue_groove); await button(level.panel.opening_buttons.B)
		for window in [Vector2i(1440,900),Vector2i(960,600)]:
			surface.size=window; await settle(.15)
			var scope:="chapter-%d-%d"%[chapter,window.x]
			await check_main(scope); await check_candidates(scope); await check_magnifier(scope)
		await check_resize("chapter-"+str(chapter))
		await main_zoom_reset()
		# Verify gestures remain usable for a real commit after cancellation and modal return.
		var count: int=level.state.placed.size()
		await drag_stock(1.0)
		await settle(1.5)
		if chapter==1 and level.inspector.opened: await button(level.inspector.close_button)
		var deadline:=Time.get_ticks_msec()+12000
		while level.busy and Time.get_ticks_msec()<deadline: await process_frame
		await settle(.1)
		check(not level.busy,"actual assembly finishes before navigation chapter "+str(chapter))
		check(level.state.placed.size()>count, "fresh touch completes actual assembly after all gesture transitions chapter "+str(chapter))
		await settle(.46)
		if chapter==1:
			if level.inspector.opened: await button(level.inspector.close_button)
		else:
			if level.view.inspected: await button(level.panel.overview_button)
		await button(campaign.back_button)
		surface.size=Vector2i(1440,900); await settle(.1)
	check(not root.has_focus() if gpu else true,"GPU audit keeps user focus unchanged")
	campaign.free(); surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"Viewport ScreenTouch/ScreenDrag in chapters 1 and 2: assembly, candidates, magnifier, cross-card/third-finger rejection, park/resume, cancellation, resize, mouse emulation, 1440x900 and 960x600. Physical Windows touch unverified."}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/touch-gestures")
	FileAccess.open("res://tests/evidence/touch-gestures/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOUCH_GESTURES ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
