extends "res://tests/exhibition_visual.gd"
const DEST="res://tests/evidence/guide-text-cleanup/"
func snap(label: String) -> void:
	await settle();RenderingServer.force_draw(false)
	surface.get_texture().get_image().save_png(DEST+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode=Window.MODE_MINIMIZED
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle()
	for n in [1,2,3]:
		await click(campaign.chapter_buttons[n])
		var level=campaign.current_chapter
		await click(level.learning.start_button)
		if n==1:
			check(level.panel.get("guidance")==null,"first guide text removed")
			check(level.panel.step_guide.target==level.panel.inspect_button,"first visual target retained")
			check(not level.panel.feedback_label.text.contains("先进入"),"initial feedback cleaned")
		elif n==2:check(level.panel.main_guide.target==level.panel.observe_button,"second visual target retained")
		else:check(level.panel.get("hint_label")==null,"third guide text removed")
		await snap(str(n)+"-main")
		if n<3:
			await click(level.panel.inspect_button if n==1 else level.panel.observe_button)
			var ui=level.inspector if n==1 else level.panel
			var workspace=ui.root if n==1 else ui.workspace
			check(workspace.get("explanation")==null,"observer hints removed "+str(n))
			await snap(str(n)+"-observe")
			await click(ui.joint_buttons.blind_tenon if n==1 else ui.joint_buttons.tongue_groove)
			await snap(str(n)+"-chosen")
			check(workspace.get("explanation")==null,"refresh does not restore text "+str(n))
			await click(ui.close_button if n==1 else ui.overview_button)
		await click(level.panel.restart_button)
		if n==1:check(level.panel.feedback_label.text=="龙骨已就位。","restart has no instructions")
		# Error/status feedback remains literal and visible.
		var feedback_ui=preload("res://components/ui/chapter_ui.gd")
		feedback_ui.feedback(level.panel.feedback_label,"槽口不匹配。",true)
		check(level.panel.feedback_label.text=="槽口不匹配。" and level.panel.feedback_label.visible,"error feedback retained "+str(n))
		campaign._show_menu();await settle()
	FileAccess.open(DEST+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures},"  "))
	print("GUIDE_TEXT ",failures);campaign.free();surface.free();quit(0 if failures.is_empty() else 1)
