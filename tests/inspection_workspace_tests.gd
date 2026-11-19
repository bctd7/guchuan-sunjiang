extends SceneTree
## Real GUI choices/orbit/drag; both chapters are exercised in one campaign instance.
const Pointer=preload("res://tests/hull_pointer.gd")
const Navigation=preload("res://tests/hull_navigation.gd")
var surface: SubViewport
var campaign
var level
var gpu:=false
var passed:=0
var failures: Array[String]=[]
var images: Array[String]=[]
var rects: Dictionary={}
var captured_opening_impact:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if ok:passed+=1
	else:failures.append(message);push_error(message)
func settle(seconds:=.1) -> void:
	await create_timer(seconds).timeout
	await process_frame
func mouse(point: Vector2,down: bool) -> void:
	var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	surface.push_input(e,true);await process_frame
func button(control: Button) -> void:
	check(control.is_visible_in_tree() and not control.disabled,"operable "+control.text)
	if gpu:
		RenderingServer.force_draw(false)
		await process_frame
	var point:=control.get_global_rect().get_center()
	var movement:=InputEventMouseMotion.new();movement.position=point;movement.global_position=point;surface.push_input(movement,true)
	await process_frame
	await mouse(point,true);await mouse(point,false);await settle(.03)
func drag_region(rect: Rect2,travel: Vector2,touch:=false) -> void:
	var origin:=rect.get_center()
	for i in range(0,13):
		var point:=origin+travel*float(i)/12.0
		if i==0:
			if touch:
				var e:=InputEventScreenTouch.new();e.index=0;e.position=point;e.pressed=true;surface.push_input(e,true)
			else:await mouse(point,true)
		else:
			if touch:
				var e:=InputEventScreenDrag.new();e.index=0;e.position=point;e.relative=travel/12.0;surface.push_input(e,true)
			else:
				var e:=InputEventMouseMotion.new();e.position=point;e.global_position=point;e.relative=travel/12.0;e.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(e,true)
		await process_frame
	if touch:
		var e:=InputEventScreenTouch.new();e.index=0;e.position=origin+travel;e.pressed=false;surface.push_input(e,true);await process_frame
	else:await mouse(origin+travel,false)
	await settle(.25)
func capture(name: String) -> void:
	if not gpu:return
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://tests/evidence/inspection-workspace/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/inspection-workspace"))
	check(surface.get_texture().get_image().save_png(path)==OK,"GPU screenshot "+name);images.append(path)
func wait_motion() -> void:
	var deadline:=Time.get_ticks_msec()+45000
	while level.busy and Time.get_ticks_msec()<deadline:
		check(not level.state.completed and not level.state.failed,"final seating and trial precede verdict")
		if gpu and not captured_opening_impact and level.view.trial.phase=="impact" and not level.view.trial.presentation_snapshot().connection_points.is_empty():
			captured_opening_impact=true
			await capture("opening-mismatch-wave-impact")
		await process_frame
	check(not level.busy,"motion finishes")
func prepare(id: String,opening: String="") -> void:
	await Navigation.open_local(surface,level,id)
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	await button(level.panel.opening_buttons[opening if not opening.is_empty() else level.state.Openings.target(id)])
	await settle(.03)
	var points: Array[Vector3]=level.view.inspection_focus_corners()
	var frame: Rect2=workspace_rect().grow(1)
	check(not points.is_empty() and points.all(func(point):return frame.has_point(level.view.project_point(point))),"actual mating members fit observation frame "+id)
func place(id: String,opening: String="",touch:=false) -> void:
	if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):return
	await prepare(id,opening)
	await settle(.5)
	await Pointer.drag(surface,level.view,1.0,touch)
	check(level.state.placed.has(id),"actual pointer installs "+id)
	await wait_motion()
	if not level.state.failed and level.view.inspected:
		if not level.state.next_in_group().is_empty():
			var next: String=level.state.next_in_group()
			await button(level.panel.next_piece_button)
			check(level.view.inspected and level.state.selected==next and not level.state.placed.has(next),"same-group continuation never auto-installs next member")
		else:await button(level.panel.overview_button)
func mesh_signature(node: Node) -> String:
	var output:=str(node.transform) if node is Node3D else ""
	if node is MeshInstance3D:output+=str(node.mesh.get_faces())
	for child in node.get_children():output+=mesh_signature(child)
	return output
func run() -> void:
	var clearance=load("res://tests/stock_clearance.gd").new()
	clearance.level_provider=func():return self.level
	root.add_child(clearance)
	gpu=OS.get_cmdline_user_args().has("--gpu")
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.25)
	for chapter in [1,2]:
		await button(campaign.chapter_buttons[chapter])
		check(campaign.current_chapter != null,"directory click enters actual chapter "+str(chapter))
		if campaign.current_chapter == null:quit(2);return
		level=campaign.current_chapter;await button(level.learning.start_button)
		check(level.panel.main_chrome.find_child("WorkshopAuxiliary",true,false)==null,"restored main task panel has no added auxiliary card "+str(chapter))
		rects[chapter]=[level.panel.main_header.get_global_rect(),level.panel.main_sidebar.get_global_rect(),level.panel.main_footer.get_global_rect()]
		await capture("chapter-%d-overview"%chapter)
		await button(level.panel.inspect_button if chapter==1 else level.panel.observe_button)
		var workspace: Control=level.inspector.root if chapter==1 else level.panel.workspace
		var candidates: Rect2=workspace.candidates.get_global_rect()
		var stage: Rect2=workspace.stage_surface.get_global_rect()
		var options: Rect2=workspace.options.get_global_rect()
		var actions: Rect2=workspace.actions.get_global_rect()
		check(candidates.end.y<=stage.position.y and stage.end.x<=options.position.x and stage.end.y<=actions.position.y,
			"chapter observation uses the shared layout with clear candidate, stage, options and action areas "+str(chapter))
		await capture("chapter-%d-local"%chapter)
		if chapter==1:
			await button(level.inspector.joint_buttons.blind_tenon);await button(level.inspector.length_buttons.correct)
			await capture("chapter-1-selected")
			await button(level.inspector.close_button);await button(campaign.back_button)
	check(rects[1]==rects[2],"overview header/current task/footer share actual placement and size")
	var preview=level.panel.gallery.previews.tongue_groove
	var original_signature: String=mesh_signature(level.view.pieces.plank_0a)
	await drag_region(preview.get_global_rect(),Vector2(55,20))
	check(level.state.joint.is_empty() and preview.orbit.target_angles.length()>.05,"dragging type preview rotates without selecting")
	await button(level.panel.joint_buttons.tongue_groove)
	await settle(.5)
	var option=level.panel.opening_gallery.previews.A
	await drag_region(option.get_global_rect(),Vector2(30,-12),true)
	check(level.state.opening.is_empty() and option.orbit.target_angles.length()>.05,"touch rotation of opening preview does not select")
	# Two fingers on different model cards must not become two accidental taps.
	for index in 2:
		var e:=InputEventScreenTouch.new();e.index=index;e.position=level.panel.opening_gallery.previews["A" if index==0 else "C"].get_global_rect().get_center();e.pressed=true;surface.push_input(e,true);await process_frame
	for index in 2:
		var e:=InputEventScreenTouch.new();e.index=index;e.position=level.panel.opening_gallery.previews["A" if index==0 else "C"].get_global_rect().get_center();e.pressed=false;surface.push_input(e,true);await process_frame
	check(level.state.opening.is_empty(),"multi-touch across candidate cards cannot select or install")
	await settle(.5)
	await button(level.panel.opening_buttons.B)
	check(level.state.opening=="B","model tap explicitly selects opening position")
	var a: Node3D=level.view.candidate_opening("plank_0a","A");var b: Node3D=level.view.candidate_opening("plank_0a","B");var c: Node3D=level.view.candidate_opening("plank_0a","C")
	check(mesh_signature(a)!=mesh_signature(b) and mesh_signature(b)!=mesh_signature(c),"same-type opening choices contain genuinely different geometry")
	a.free();b.free();c.free()
	for touch in [false,true]:
		var rect: Rect2=workspace_rect()
		var point:=rect.position+Vector2(24,24)
		check(level.view.pick_drag_piece(point).is_empty(),"orbit start is clear of movable timber")
		var before: Vector2=level.panel.observation_orbit.target_angles
		await settle(.5)
		await drag_region(Rect2(point-Vector2(3,3),Vector2(6,6)),Vector2(52,16),touch)
		check(level.panel.observation_orbit.target_angles!=before and level.state.placed.is_empty() and level.state.opening=="B","main joint rotates without selecting or installing, touch="+str(touch))
	check(mesh_signature(level.view.pieces.plank_0a)==original_signature,"model rotations leave actual geometry and trial pose unchanged")
	await capture("chapter-2-rotated")
	await button(level.panel.reset_observation_button)
	await capture("chapter-2-selected")
	await button(level.panel.lesson_button);await button(level.learning.start_button)
	check(level.view.get_parent()==level.panel.local_viewport and level.state.opening=="B","teaching return restores the local world and explicit opening")
	check(level.panel.local_viewport.render_target_update_mode!=SubViewport.UPDATE_DISABLED,"restored local viewport resumes rendering")
	await button(level.panel.overview_button)
	check(level.view.get_parent()==level and level.panel.local_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"overview restores the original world and suspends local rendering")
	check(level.panel.gallery.previews.values().all(func(card):return not card.orbit.is_processing() and not card.orbit.is_processing_input()),"hidden candidate cards suspend orbit work and raw input")
	var wrong: Dictionary={"plank_0a":"A","cross_upper":"A"}
	for id in level.Rules.IDS:
		await place(id,str(wrong.get(id,"")),id in ["plank_0b","three_upper"])
		if id!=level.Rules.IDS.back():check(not level.state.failed and not level.state.checked,"seatable mismatches wait for the last real member "+id)
	check(level.state.failed and level.state.mismatched_openings().size()==8 and not level.state.completed,"all ten pieces precede the verdict; six boards and both cross members preserve the selected wrong opening")
	check(level.view.trial.presentation_snapshot().connection_points.size()==6 and level.view.trial.drops.get_child_count()>0,"the six inherited hull openings leak; interior cross members stay dry")
	await capture("wrong-openings-final-trial")
	await button(level.panel.failure_restart_button)
	check(level.state.placed.is_empty() and level.state.opening.is_empty() and not level.view.trial.visible,"restart clears mismatches and old trial")
	for id in level.Rules.IDS:await place(id,"",id in ["plank_0a","bulkhead"])
	check(level.state.completed and level.state.mismatched_openings().is_empty() and level.view.trial.presentation_snapshot().connection_points.is_empty(),"matching all actual openings plus staggered seams completes whole challenge")
	await capture("matching-openings-complete")
	level.panel.success_panel.hide()
	await button(level.panel.undo_button)
	check(not level.state.completed and level.state.placed.size()==9 and level.state.opening.is_empty(),"undo retains other real members and requires a fresh opening choice")
	for dimensions in [Vector2i(1100,800),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.2);await prepare("three_upper")
		check(surface.get_visible_rect().encloses(level.panel.overview_button.get_global_rect()) and surface.get_visible_rect().encloses(level.panel.opening_buttons.C.get_global_rect()),"opening choices and return fit viewport "+str(dimensions))
		await capture("last-member-local-"+str(dimensions.x));await button(level.panel.overview_button)
		await prepare("three_upper");await settle(.5);await Pointer.drag(surface,level.view,.25,true)
		check(not level.state.placed.has("three_upper") and level.view.preview_progress>.2,"scaled own-viewport touch maps to actual timber "+str(dimensions))
		await button(level.panel.overview_button)
	if gpu:check(not root.has_focus(),"GPU host remains unfocused")
	check(clearance.samples>0 and clearance.violations.is_empty(),"loose trial wood stays clear through drag, seating and wave frames: "+str(clearance.violations.keys()))
	var clearance_samples: int=clearance.samples
	clearance.free()
	campaign.free();surface.free()
	var report={"revision":"inspection-workspace-20261101","passed":passed,"failed":failures.size(),"failures":failures,"images":images,"host_had_focus":root.has_focus() if gpu else false,"renderer":DisplayServer.get_name(),"clearance_samples":clearance_samples,"method":"Actual Viewport mouse and simulated touch, original geometry and full trial paths; not human hardware validation"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/inspection-workspace"))
	FileAccess.open("res://tests/evidence/inspection-workspace/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INSPECTION_WORKSPACE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func workspace_rect() -> Rect2:return level.panel.workspace.stage_surface.get_global_rect()
