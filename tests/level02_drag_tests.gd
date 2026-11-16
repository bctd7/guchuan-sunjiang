extends SceneTree
const HullNavigation=preload("res://tests/hull_navigation.gd")
## Public UI + real Viewport pointers; gameplay state is read only.
const Pointer=preload("res://tests/hull_pointer.gd")
var level
var wrong_opening_run:=false
var surface: Viewport
var gpu := false
var pictures: Array[String]=[]
var captured_phases: Dictionary={}
var saw_approach := false
var saw_impact := false
var saw_leaking_motion := false
var passed:=0
var failed:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		failures.append(message)
		push_error(message)
func settle(seconds:=.1) -> void:
	await create_timer(seconds).timeout
	await process_frame
func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		surface.push_input(event,true)
		await process_frame
func button(control: Button) -> void:
	# A real touch release deliberately suppresses generated mouse taps for 450ms.
	# This mixed-device fixture must finish that grace period before its next mouse choice.
	if is_instance_valid(level) and is_instance_valid(level.interaction):
		var delay: int=level.interaction._last_touch_ms+470-Time.get_ticks_msec()
		if delay>0:await settle(float(delay)/1000.0)
	check(control.is_visible_in_tree() and not control.disabled,"operable "+control.text)
	if gpu:
		RenderingServer.force_draw(false)
		await process_frame
	var point:=control.get_global_rect().get_center()
	var movement:=InputEventMouseMotion.new();movement.position=point;movement.global_position=point;surface.push_input(movement,true)
	await process_frame
	await click(point)
	await process_frame
func prepare(id: String,layout: String="") -> void:
	await HullNavigation.open_local(surface,level,id)
	check(level.view.inspected and level.panel.observer_chrome.visible and not level.panel.main_chrome.visible,"task-card button opens separate local page "+id)
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	await button(level.panel.opening_buttons["A" if wrong_opening_run and id=="plank_0a" else level.state.Openings.target(id)])
	if not layout.is_empty() and id.ends_with("a") and level.Rules.row_for(id)>0:
		await button(level.panel.layout_buttons[layout])
	if id=="plank_1a":
		var chosen_layout: String=level.state.layout
		await button(level.panel.overview_button)
		await HullNavigation.open_local(surface,level,id)
		check(level.state.layout==chosen_layout and not level.state.placed.has(id),"local return preserves uncommitted A/B selection")
	if gpu and id in ["plank_0b","cross_upper","three_middle","bulkhead"]:await capture("local-"+id)
	check(level.view.pick_drag_piece(level.view.drag_grab_screen())==id,"actual exposed mesh hit "+id)
func wait_motion() -> void:
	var deadline:=Time.get_ticks_msec()+7000
	while level.busy and Time.get_ticks_msec()<deadline:
		if level.view.trial.phase=="approach":
			if gpu and not captured_phases.has("approach"):
				captured_phases["approach"]=true
				await capture("wave-approaching")
			saw_approach=true
			check(not level.state.checked and not level.state.completed and not level.state.failed,"wave approach precedes verdict")
		if level.view.trial.phase=="impact":
			if gpu and not captured_phases.has("impact"+str(level.view.trial.leak_rows.is_empty())):
				captured_phases["impact"+str(level.view.trial.leak_rows.is_empty())]=true
				await capture("wave-impact-"+("dry" if level.view.trial.leak_rows.is_empty() else "leaking"))
			saw_impact=true
			if level.view.trial.drops.get_child_count()>0 and not saw_leaking_motion:
				var before: Vector3=level.view.trial.drops.get_child(0).position
				await process_frame
				await process_frame
				saw_leaking_motion=not level.view.trial.drops.get_child(0).position.is_equal_approx(before)
		await process_frame
	check(not level.busy and level.view.animations.is_empty(),"motion ends before next action")
func place(id: String,layout: String,touch:=false) -> void:
	if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):return
	await prepare(id,layout)
	await settle(.5) # Real touch/mouse dedup uses wall clock.
	await Pointer.drag(surface,level.view,1.0,touch)
	if not level.state.placed.has(id):
		print("DRAG_FAILURE ",id," gate=",level.state.can_attempt(id)," opening=",level.state.opening," progress=",level.view.preview_progress," point=",level.view.drag_grab_screen()," inside=",level.view.inside_observation(level.view.drag_grab_screen())," touches=",level.interaction._touches," last_touch_ms=",Time.get_ticks_msec()-level.interaction._last_touch_ms)
	check(level.state.placed.has(id),"pointer release commits "+id)
	if level.state.placed.has(id):
		await wait_motion()
		if level.view.inspected:
			check(level.panel.observer_chrome.visible and level.panel.overview_button.is_visible_in_tree() and not level.panel.overview_button.disabled,"seated joint can be reviewed before return")
			var next: String=level.state.next_in_group()
			if not next.is_empty():
				var joint: String=level.state.joint
				await button(level.panel.next_piece_button)
				check(level.view.inspected and level.state.selected==next and level.state.joint==joint and not level.state.placed.has(next),"same-group continuation retains choice without installing next member")
				check(level.view.pieces[id].visible,"continuing shows the actual previous member")
			else:
				await button(level.panel.overview_button)
				check(not level.view.inspected and level.state.placed.has(id),"overview return keeps installed joint")
func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu")
	root.size=Vector2i(1440,900)
	surface=root
	if gpu:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.mode=Window.MODE_MINIMIZED
	var sub:=SubViewport.new()
	sub.size=Vector2i(1440,900)
	sub.own_world_3d=true
	sub.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	surface=sub
	level=load("res://levels/level02/level02.tscn").instantiate()
	surface.add_child(level)
	await settle(.15) # Let the real introduction layout finish before its first click.
	await button(level.learning.start_button)
	await settle(.1)
	check(level.panel.main_chrome.visible and not level.panel.observer_chrome.visible and not level.panel.gallery.is_visible_in_tree(),"overview focuses current task rather than candidate toolbar")
	check(not level.panel.inventory_panel.visible and level.panel.group_buttons.size()==3 and level.panel.group_buttons.values().all(func(button):return not button.is_visible_in_tree()),"three-group details are collapsed behind the single footer progress")
	await capture("00-overview")
	await prepare("plank_0a")
	await capture("01-observe-and-choose")
	var lesson_choice: String=level.state.joint
	await button(level.panel.lesson_button)
	check(level.learning.modal_open(),"local page can revisit chapter teaching")
	await button(level.learning.start_button)
	check(level.view.inspected and level.panel.observer_chrome.is_visible_in_tree() and level.state.joint==lesson_choice,"teaching return restores local operation and explicit choice")
	var stable_children: int=level.get_child_count()
	var selected_before: String=level.state.joint
	await button(level.panel.overview_button)
	check(not level.view.inspected and level.state.joint==selected_before and level.state.placed.is_empty(),"return keeps chosen type without installing wood")
	var target: Vector2=level.panel.observe_button.get_global_rect().get_center()
	for pressed in [true,false]:
		var tap:=InputEventScreenTouch.new()
		tap.index=0
		tap.position=target
		tap.pressed=pressed
		surface.push_input(tap,true)
		await process_frame
	check(level.view.inspected and level.state.joint==selected_before and level.state.placed.is_empty(),"touching task-card button reopens local page and keeps choices")
	check(level.get_child_count()==stable_children and level.panel.gallery.get_child_count()==3,"local reentry reuses existing view and candidate cards")
	await settle(.5)
	var home: Transform3D=level.view.pieces.plank_0a.transform
	print("DRAG_PROBE ",level.view.drag_grab_screen()," path ",level.view.drag_path_screen()," pick ",level.view.pick_drag_piece(level.view.drag_grab_screen()))
	await click(level.view.drag_grab_screen())
	check(level.state.placed.is_empty(),"tap never replaces drag")
	await Pointer.drag(surface,level.view,.30)
	check(level.state.placed.is_empty() and is_equal_approx(level.view.preview_progress,.30),"shallow mouse release retains actual travel")
	await capture("02-shallow-push")
	check(not level.view.pieces.plank_0a.transform.is_equal_approx(home),"actual timber mesh moved before state placement")
	await Pointer.drag(surface,level.view,-.20)
	check(level.state.placed.is_empty() and is_equal_approx(level.view.preview_progress,.10),"pulling back retracts same timber")
	await Pointer.drag(surface,level.view,.75)
	check(level.state.placed.has("plank_0a"),"regrab and push seats board")
	await wait_motion()
	await capture("local-seated-before-return")
	if level.view.inspected:await button(level.panel.overview_button)
	check(level._try_socket("plank_0b").code=="drag_required","stale socket signal cannot bypass pointer travel")
	for id in level.Rules.IDS:
		if id=="plank_0a":continue
		var row: int=level.Rules.row_for(id)
		await place(id,"B" if row==1 else "A",id in ["plank_0b","three_middle","bulkhead"])
	check(surface.get_visible_rect().encloses(level.panel.success_panel.get_global_rect()),"success card stays within viewport")
	await capture("03-successful-sea-trial")
	check(saw_approach and saw_impact,"visible approach and impact precede result")
	check(level.view.trial.drops.get_child_count()==0,"correct staggered hull has no simulated leaks")
	check(level.state.completed and not level.state.failed and level.panel.success_panel.visible,"staggered full hull passes")
	await button(level.panel.success_panel.get_child(0).get_child(3))
	await button(level.panel.inventory_button)
	await capture("04-three-groups")
	await button(level.panel.inventory_close_button)
	await button(level.panel.bulkhead_button)
	var before_reading: Dictionary=level.state.placed.duplicate(true)
	check(level.bulkhead_lesson.opened and not level.interaction.is_processing_input(),"lesson blocks background drag")
	await capture("05-waterproof-compartments")
	await button(level.bulkhead_lesson.close_button)
	check(not level.bulkhead_lesson.opened and level.interaction.is_processing_input() and level.state.placed==before_reading,"lesson restores input and keeps assembly")
	await button(level.panel.restart_button)
	wrong_opening_run=true
	for id in level.Rules.IDS: await place(id,"A",id.ends_with("b"))
	wrong_opening_run=false
	await capture("06-leaking-hull-failure")
	check(saw_leaking_motion,"leak droplets actually move")
	check(level.view.trial.drops.get_child_count()>0,"failed seams create leak particles")
	check(level.state.failed and not level.state.completed and level.panel.failure_overlay.visible,"seatable wrong openings fail only at end")
	var saved: Dictionary=level.state.placed.duplicate(true)
	level.interaction.socket_requested.emit("bulkhead")
	check(level.state.placed==saved and level.state.failed,"late release cannot alter failed hull")
	await button(level.panel.failure_restart_button)
	check(level.state.placed.is_empty() and not level.state.failed and not level.busy,"restart clears only this challenge")
	await prepare("plank_0a")
	await settle(.5)
	await Pointer.drag(surface,level.view,.25,true)
	check(level.view.preview_progress>.2 and not level.state.placed.has("plank_0a"),"shallow touch retains travel")
	level.interaction.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(is_zero_approx(level.view.preview_progress) and not level.interaction.dragging,"focus loss cancels pending gesture")
	await resize_checks()
	await cancellation_checks()
	if gpu: check(not root.has_focus(),"GPU host never takes keyboard focus")
	var owned: Array=[weakref(level.view),weakref(level.panel),weakref(level.interaction)]
	level.free()
	check(owned.all(func(ref):return ref.get_ref()==null),"freeing chapter releases owned view, UI and pointer adapter")
	surface.free()
	var report:={"revision":"level02-model-seams-20261101","passed":passed,"failed":failed,"failures":failures,"images":pictures,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"actual Viewport mouse and simulated touch; no gameplay state mutation; not human hardware validation"}
	FileAccess.open("res://tests/level02_drag_gpu_report.json" if gpu else "res://tests/level02_drag_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LEVEL02 DRAG ",JSON.stringify(report))
	quit(0 if failed==0 else 1)

func capture(name: String) -> void:
	if not gpu:return
	for i in 4:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/level02-model-seams/"+name+".png"
	if pictures.has(path):return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/level02-model-seams"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU screenshot "+name)
	pictures.append(path)
func resize_checks() -> void:
	await place("plank_0a","")
	await prepare("cross_upper")
	for dimensions in [Vector2i(1440,900),Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2)
		check(surface.get_visible_rect().encloses(level.panel.overview_button.get_global_rect()),"local return fits "+str(dimensions))
		var prefix: Dictionary=level.state.placed.duplicate(true)
		await button(level.panel.opening_buttons.B)
		check(level.view.pick_drag_piece(level.view.drag_grab_screen())=="cross_upper","scaled actual timber owns its hit")
		check(level.state.placed==prefix and not level.state.checked,"comparing opening stock leaves installed group intact")
		await button(level.panel.transparent_button)
		check(level.panel.transparent_button.button_pressed,"receiver reveal has an accurate visible toggle")
		await capture("08-receiver-reveal-"+str(dimensions.x))
		await button(level.panel.transparent_button)
		await settle(.5);await Pointer.drag(surface,level.view,.25)
		check(level.view.preview_progress>.2,"scaled viewport real mesh can drag "+str(dimensions))
		level.interaction.cancel()
	await button(level.panel.overview_button);await button(level.panel.restart_button)

func cancellation_checks() -> void:
	await prepare("plank_0a")
	var origin: Vector2=level.view.drag_grab_screen()
	for index in 2:
		var event:=InputEventScreenTouch.new()
		event.index=index
		event.position=origin
		event.pressed=true
		surface.push_input(event,true)
		await process_frame
	check(not level.interaction.dragging and is_zero_approx(level.view.preview_progress),"second finger cancels timber gesture")
	for index in 2:
		var event:=InputEventScreenTouch.new()
		event.index=index
		event.position=origin
		event.pressed=false
		surface.push_input(event,true)
		await process_frame
	check(level.state.placed.is_empty(),"multiple fingers never place wood")
	await settle(.5)
	for id in level.Rules.IDS:
		if id=="three_upper":break
		var row: int=level.Rules.row_for(id)
		await place(id,"B" if row==1 else "A")
	await prepare("three_upper")
	await Pointer.drag(surface,level.view,1.0)
	var deadline:=Time.get_ticks_msec()+3000
	while level.view.trial.phase=="idle" and Time.get_ticks_msec()<deadline:await process_frame
	check(level.busy and not level.state.completed and not level.state.failed,"wave trial is cancellable before verdict")
	await button(level.panel.restart_button)
	await settle(3.0)
	check(level.state.placed.is_empty() and not level.state.checked and not level.state.completed and not level.state.failed,"restart rejects old wave callback")
	check(not level.busy and level.view.animations.is_empty() and not level.view.trial.visible and level.view.trial.drops.get_child_count()==0,"restart cleans trial geometry and motion")
