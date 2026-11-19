extends "res://tests/rib_feedback_visual.gd"
const ENTRY="res://tests/evidence/observer-entry/"
func capture(label: String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var path:=ENTRY+label+".png"
	check(surface.get_texture().get_image().save_png(path)==OK,"actual pixels "+label)
	images.append(path)
func run() -> void:
	check(DisplayServer.get_name()!="headless" and root.get_flag(Window.FLAG_NO_FOCUS) and not root.has_focus(),"background GPU host")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENTRY))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
	surface.add_child(campaign)
	await settle(.2)
	await button(campaign.chapter_buttons[1])
	level=campaign.current_chapter
	await button(level.learning.start_button)
	await button(level.panel.inspect_button)
	await capture("01-pick-a-joint")
	await button(level.inspector.length_buttons.long)
	check(level.joint_type.is_empty() and not level.busy,"missing choice never supplies answer")
	await capture("02-wood-picked-joint-still-needed")
	var card: Button=level.inspector.joint_buttons.blind_tenon
	await click(card.get_global_rect().position+Vector2(card.size.x*.5,55))
	check(level.joint_type=="blind_tenon","model image itself selects type")
	await button(level.inspector.length_buttons.correct)
	await capture("03-ready-to-drag")
	await drag_body(false,"entry")
	check(level.busy and level.state.placed.has("rib_l1"),"unchanged drag installs after full card choice")
	await settle(2.3)
	await capture("04-real-installation-review")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"method":"Actual GPU UI and GUI pointer events; supplementary to separately completed Windows native mouse verification."}
	FileAccess.open(ENTRY+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OBSERVER ENTRY GPU ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
