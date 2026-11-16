extends "res://tests/observation_repeat_tests.gd"
## Real input: wrong cross stock seats fully, then fails in the local workspace.
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var path:="res://tests/evidence/continuable-joints/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"GPU evidence "+name);images.append(path)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/continuable-joints")
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 var kind:="cross_lap"
 for code in ["A","B","C"]:
  await prepare("plank_0a")
  await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons[code])
  await capture(kind+"-"+code+"-waiting")
  await settle(.5);await Pointer.drag(surface,level.view,.55)
  check(not level.state.failed and level.state.placed.is_empty() and not level.panel.failure_overlay.visible,"shallow cross trial remains neutral "+code)
  await capture(kind+"-"+code+"-approach")
  await Pointer.drag(surface,level.view,1.0);await wait_motion()
  check(level.state.failed and level.state.placed.size()==1,"cross completes contact before the local wrong-family verdict "+code)
  check(level.panel.failure_overlay.visible and level.panel.failure_overlay.title.text=="拼装错误" and level.state.failure_result().code=="assembly_mismatch","requested local failure dialog opens "+code)
  check(level.view.pieces.plank_0a.transform.is_equal_approx(level.view.contact_poses.plank_0a),"dialog preserves the real final cross pose "+code)
  check(level.state.selected=="plank_0a" and level.view.inspected and not level.state.placed.has("plank_0b") and level.view.animations.is_empty(),"wrong cross never repeats or opens the next row "+code)
  check(not level.view.pieces.plank_0a.get_child(0).has_node("PlankBody"),"wrong joint has no appended plank body or outgoing tongue")
  await capture(kind+"-"+code+"-assembled-error")
  if not level.state.failed:break
  await button(level.panel.failure_restart_button)
 # Correct groove candidates use the same default scale and expose the slot.
 await prepare("plank_0a");await capture("tongue-groove-candidate-cuts")
 if gpu:check(not root.has_focus(),"GPU host stays unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"ABC cross stock via real pointer: neutral shallow motion, completed physical seating then local assembly_mismatch dialog, no automatic companion/next-row advance, restart. Three-part locks are covered by starter_lock_tests."}
 campaign.free();surface.free()
 FileAccess.open("res://tests/evidence/continuable-joints/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CONTINUABLE_JOINTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
