extends "res://tests/guided_insertion_visual.gd"
const AUDIT_OUT="res://tests/evidence/alignment-r6-verified/"
var camera_checks:=0
func stroke_move(point: Vector2,touching: bool,last: Vector2) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIT_OUT))
	await super.stroke_move(point,touching,last)
	if level.inspector.orbit.assembly_dragging:
		await RenderingServer.frame_post_draw
		var inspector=level.inspector
		var label: String=inspector.animated_piece_id+"-"+inspector.selected_joint+"-"+inspector.selected_length
		var path:=AUDIT_OUT+label+"-hand-depth-"+str(roundi(inspector.orbit.drag_progress*100))+".png"
		check(inspector.viewport.get_texture().get_image().save_png(path)==OK,"live hand-stage pixels "+label)
		images.append(path)
func stroke(start: Vector2,end: Vector2,touch:=false,cancelled:=false) -> void:
	var before: Transform3D=level.inspector.camera.transform
	await super.stroke(start,end,touch,cancelled)
	if level.inspector.is_animating and level.inspector.animated_piece_id in ["bow","beam1"]:
		check(level.inspector.camera.transform.is_equal_approx(before),"release keeps the same camera; no perceived pose jump")
		camera_checks+=1
func wait_review(wrong: bool,label: String) -> void:
	var start:=Time.get_ticks_msec()
	var near_seated:=false;var loosened:=false;var saved:=false
	var final: Transform3D=level.view.trial_pose(level.inspector.animated_piece_id,level.inspector.selected_length,level.inspector.selected_joint)
	var previous: Vector3=level.inspector.camera.position
	var max_camera_step:=0.0
	while level.inspector.is_animating and Time.get_ticks_msec()-start<6000:
		var distance: float=level.inspector.animated_piece.position.distance_to(final.origin)
		if distance<.02:near_seated=true
		if near_seated and distance>.026:loosened=true
		max_camera_step=maxf(max_camera_step,level.inspector.camera.position.distance_to(previous));previous=level.inspector.camera.position
		if not saved and Time.get_ticks_msec()-start>100:
			await RenderingServer.frame_post_draw
			var path:=AUDIT_OUT+label+"-inserting.png"
			check(level.inspector.viewport.get_texture().get_image().save_png(path)==OK,"actual insertion-stage pixels "+label)
			images.append(path);saved=true
		await process_frame
	check(level.inspector.animation_finished and not level.inspector.retry_button.disabled,"trial completes and allows takeback "+label)
	check(level.inspector.animated_piece.transform.is_equal_approx(final),"final stock pose matches chosen trial "+label)
	check(max_camera_step<1.0,"camera recenters continuously "+label)
	if wrong:check(loosened and not level.state.is_stable(),"wrong stock visibly loosens "+label)
func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIT_OUT))
	if not label.ends_with("-inserted"):
		await process_frame;await RenderingServer.frame_post_draw
		var path:=AUDIT_OUT+label+".png";check(surface.get_texture().get_image().save_png(path)==OK,"UI pixels "+label);images.append(path)
		return
	var inspector=level.inspector
	var center: Vector3=inspector.orbit._center
	var direction: Vector3=inspector.orbit._direction
	var angles: Vector2=inspector.orbit.target_angles
	var size_before: float=inspector.camera.size
	var sheet:=Image.create(1000,490,false,Image.FORMAT_RGBA8);sheet.fill(Color("f4ebd6"))
	var views: Array[String]=["front","side","back","inside"]
	for index in 4:
		inspector._set_cutaway(false)
		inspector.orbit.configure(inspector.camera,center,direction.rotated(Vector3.UP,[0.0,PI*.5,PI,0.0][index]),true)
		inspector.camera.size=size_before
		if index==3:inspector._set_cutaway(true)
		await settle(.10);await RenderingServer.frame_post_draw
		var pixels: Image=inspector.viewport.get_texture().get_image()
		var path:=AUDIT_OUT+label+"-"+views[index]+".png"
		check(pixels.save_png(path)==OK,"actual final "+views[index]+" pixels "+label)
		images.append(path)
		var factor: float=minf(500.0/pixels.get_width(),245.0/pixels.get_height())
		pixels.resize(roundi(pixels.get_width()*factor),roundi(pixels.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(pixels,Rect2i(Vector2i.ZERO,pixels.get_size()),Vector2i((index%2)*500+(500-pixels.get_width())/2,(index/2)*245+(245-pixels.get_height())/2))
	var montage:=AUDIT_OUT+label+"-angles.png";check(sheet.save_png(montage)==OK,"four-view contact sheet "+label);images.append(montage)
	inspector._set_cutaway(false)
	inspector.orbit.configure(inspector.camera,center,direction,true);inspector.orbit.target_angles=angles;inspector.camera.size=size_before
	await settle(.1)
func finish_report() -> void:
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":rows,"case_count":rows.size(),"images":images,"camera_release_checks":camera_checks,"montage_order":["front","side","back","inside"],"method":"Hidden no-focus GPU; Viewport GUI events for 27 choices, push/pull/re-grab, final and insertion-stage pixels, front/side/back/opaque section, smooth camera release checks. Not native mouse or physical touch."}
	FileAccess.open(AUDIT_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ALIGNMENT_GPU ",passed," passed; ",failures.size()," failed; cases=",rows.size())
	surface.free();quit(0 if failures.is_empty() else 1)
