extends "res://tests/exhibition_visual.gd"
const DEST="res://tests/evidence/guide-refresh/"
var frame_index:=0
func record_cycle() -> void:
	for i in 60:
		await create_timer(1.0/24).timeout
		RenderingServer.force_draw(false)
		surface.get_texture().get_image().save_png(DEST+"frames/%04d.png"%frame_index)
		frame_index+=1
func snap(name: String) -> void:
	await settle();RenderingServer.force_draw(false)
	surface.get_texture().get_image().save_png(DEST+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"frames"))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle()
	await click(campaign.chapter_buttons[1])
	var level=campaign.instances[1]
	await click(level.learning.start_button);await click(level.panel.inspect_button)
	var ui=level.inspector
	await snap("type");await record_cycle()
	await click(ui.joint_buttons.blind_tenon);await snap("material");await record_cycle()
	await click(ui.length_buttons.correct);await snap("drag")
	var orbit=ui.orbit
	var local: Vector2=orbit.drag_start_screen()
	for x in range(20,int(orbit.size.x),15):
		for y in range(20,int(orbit.size.y),15):
			if orbit._hit_part(Vector2(x,y)):local=Vector2(x,y);break
		if orbit._hit_part(local):break
	var start: Vector2=orbit.get_global_transform_with_canvas()*local
	var direction: Vector2=(orbit.target_screen()-orbit.drag_start_screen()).normalized()
	var press:=InputEventScreenTouch.new();press.index=0;press.position=start;press.pressed=true;surface.push_input(press,true);await process_frame
	for i in range(1,21):
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=start+direction*i*15;drag.relative=direction*15;surface.push_input(drag,true);await process_frame
	var release:=InputEventScreenTouch.new();release.index=0;release.position=start+direction*300;release.pressed=false;surface.push_input(release,true)
	await create_timer(4).timeout
	check(ui.animation_finished,"touch trial reached completed review")
	await snap("completed");await record_cycle()
	check(not ui.xray_button.visible and not ui.replay_button.visible and not ui.zoom_bar.visible,"completion tools hidden")
	check(not ui.root.options.get_parent().visible,"no empty option frame")
	check(ui.close_button.get_parent()==ui.root.actions,"continue in footer")
	await click(ui.retry_button)
	check(ui.observation_mode and level.state.progress_count()==0,"take back really undoes trial")
	await snap("take-back")
	await click(ui.close_button)
	print("GUIDE_COMPLETION ",JSON.stringify(failures))
	campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
