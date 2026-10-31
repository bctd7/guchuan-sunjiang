extends "res://tests/trial_receiver_visual.gd"
const GUIDED_OUT="res://tests/evidence/guided-r5-final/"
func save_frame(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GUIDED_OUT))
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=GUIDED_OUT+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"guided GPU "+label)
	images.append(path)
func trial(id: String,kind: String,length: String,index: int,record_case: bool=true) -> bool:
	await choose_trial(kind,length)
	var label:=id+"-"+kind+"-"+length
	var overlay=level.inspector.orbit
	var grip:=visible_grip()
	var unit:=Vector3.RIGHT if id=="rib_l1" else (Vector3.BACK if id=="bow" else Vector3.LEFT)
	var center: Vector3=level.inspector.animated_piece.global_position
	# Direction is independently projected from the ship's physical insertion
	# axis. No internal drag target, grip target or placement state is injected.
	var direction: Vector2=(project(center+unit)-project(center)).normalized()
	var start: Vector2=overlay.global_position+grip
	var angles: Vector2=overlay.target_angles
	var touching:=index%2==1
	await pointer(start,true,touching)
	await stroke_move(start+direction*32,touching,start)
	var deep: float=overlay.drag_progress
	await stroke_move(start+direction*14,touching,start+direction*32)
	check(overlay.drag_progress<deep,"live pull-back reduces real insertion depth "+label)
	await pointer(start+direction*14,false,touching)
	var partial: Transform3D=level.inspector.animated_piece.transform
	check(not level.state.placed.has(id) and overlay.drag_progress>0,"shallow release keeps adjustable stock "+label)
	check(not partial.is_equal_approx(overlay._rest_pose),"partial stock remains at dragged depth "+label)
	await capture(label+"-partial") if index%9==0 else process_frame
	grip=visible_grip()
	start=overlay.global_position+grip
	await stroke(start,start+direction*215,touching)
	var accepted: bool=level.state.placed.has(id)
	check(accepted,"guided hand stroke accepts "+label)
	var stable: bool=kind==level.Rules.expected_joint(id) and length=="correct"
	var row={"socket":id,"joint":kind,"length":length,"program_drag_accepted":accepted,"expected_stable":stable,"native_mouse_tested":false,"physical_touch_tested":false,"partial_pullback_tested":true}
	if not accepted:rows.append(row);return false
	check(overlay.target_angles==angles,"part gesture did not rotate camera "+label)
	check(level.state.placed[id].joint==kind and level.state.placed[id].length==length,"actual choice retained "+label)
	check(level.inspector.animated_piece.has_meta("trial_release_start"),"animation continues from actual dragged pose "+label)
	await wait_review(not stable,label)
	check(level.Rules.connection_correct(id,level.state.placed)==stable,"stability rule retained "+label)
	await capture(label+"-inserted")
	if record_case:
		await take_back(id)
		row["takeback"]=not level.state.placed.has(id) and level.joint_type.is_empty() and level.tenon_length.is_empty()
		check(row.takeback,"takeback clears trial and choices "+label)
		rows.append(row)
	print("GUIDED_CASE ",index+1," ",label," accepted=",accepted)
	return true
func stroke_move(point: Vector2,touching: bool,last: Vector2) -> void:
	if touching:
		var event:=InputEventScreenDrag.new();event.position=point;event.relative=point-last;event.index=0;surface.push_input(event,true)
	else:
		var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=point-last;event.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(event,true)
	await process_frame
func finish_report() -> void:
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":rows,"case_count":rows.size(),"images":images,"method":"Hidden no-focus GPU; actual GUI Viewport mouse/touch events, physical insertion axis, partial push/retract/re-grab, all 27 selections, takeback, correct completion, wrong through-stock cutaway at three angles. Not native mouse or physical touch."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GUIDED_OUT))
	FileAccess.open(GUIDED_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GUIDED_GPU ",passed," passed; ",failures.size()," failed; cases=",rows.size())
	surface.free();quit(0 if failures.is_empty() else 1)
