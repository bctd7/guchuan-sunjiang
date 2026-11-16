extends "res://tests/drag_consistency_tests.gd"
var grabs: Array=[]

func check_surfaces(kind: String,zoom: float) -> void:
	await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons.B)
	await button(level.panel.reset_observation_button);level.view.zoom_observation(zoom);await settle(.1)
	var area: Rect2=level.view.local_surface.get_global_rect().grow(-12)
	var toolbar: Rect2=level.panel.zoom_reset_button.get_parent().get_global_rect().grow(8)
	var candidates: Dictionary={}
	var raw: Vector2=level.view.drag_path_screen()
	# Actual projected triangle interiors and near-edge points, independent of
	# drag_grab_screen's preferred point. Do not filter with the production picker.
	for part in level.view.TrialContact.meshes(level.view.pieces.plank_0a,level.view.pieces.plank_0a.global_transform):
		var faces: PackedVector3Array=part.mesh.get_faces()
		for index in range(0,faces.size(),3):
			for weights in [Vector3(1,1,1)/3.0,Vector3(.8,.1,.1)]:
				var world: Vector3=part.pose*(faces[index]*weights.x+faces[index+1]*weights.y+faces[index+2]*weights.z)
				var point: Vector2=level.view.project_point(world)
				if not area.has_point(point) or not area.has_point(point+raw*.2) or toolbar.has_point(point) or toolbar.has_point(point+raw*.2):continue
				var grid:=Vector2i((point-area.position)/area.size*Vector2(4,4))
				candidates[grid]=point
	check(candidates.size()>=2,"several exposed surfaces available "+kind+"/"+str(zoom))
	var count:=0
	for point in candidates.values():
		if count>=8:break
		var travel: Vector2=level.view.drag_input_path_screen()*.2
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
		check(surface.gui_get_hovered_control()==level.view.local_surface,"visible timber routes input to its stage, not an overlay")
		await mouse(point,true)
		check(level.interaction.dragging and not level.interaction._orbiting,"press on actual wood starts insertion "+kind+" at "+str(point))
		motion=InputEventMouseMotion.new();motion.position=point+travel;motion.global_position=motion.position;motion.relative=travel;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion,true);await process_frame
		await mouse(point+travel,false)
		check(absf(level.view.preview_progress-.2)<.002 and level.state.placed.is_empty(),"surface/edge grab visibly moves the wood without committing")
		await move_pointer(point+raw*.2,-travel)
		check(level.view.preview_progress<.002 and level.state.placed.is_empty(),"same surface can be re-grabbed and withdrawn")
		count+=1
	grabs.append({"size":str(surface.size),"type":kind,"zoom":zoom,"distinct_surface_grabs":count})

func run() -> void:
	gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
	if gpu:root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	level=load("res://levels/level02/level02.tscn").instantiate();surface.add_child(level);await settle(.2)
	await button(level.learning.start_button);await button(level.panel.observe_button)
	for dimensions in [Vector2i(1440,900),Vector2i(960,600)]:
		surface.size=dimensions;await settle(.1)
		for kind in ["tongue_groove","cross_lap","three_way_lap"]:
			for zoom in [1.0,.25]:await check_surfaces(kind,zoom)
	if gpu:check(not root.has_focus(),"GPU grab check keeps user focus")
	level.free();surface.free()
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"grabs":grabs,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"method":"Real GUI input at projected actual triangle centres and near-edge points, not only the preferred grab point; two sizes, three families, two zooms."}
	DirAccess.make_dir_recursive_absolute("res://tests/evidence/three-groups")
	FileAccess.open("res://tests/evidence/three-groups/grabs-"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WOOD_GRABS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
