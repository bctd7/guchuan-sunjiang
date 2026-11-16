extends "res://tests/observation_repeat_tests.gd"
## Actual Viewport mouse/touch: both incompatible types at every manual step.
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var folder:="res://tests/evidence/level02-late-fit"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var path:=folder+"/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"GPU contact result "+name);images.append(path)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 var cases:=0
 for target in level.Rules.MANUAL_IDS:
  for kind in level.Rules.JOINT_NAMES:
   if kind==level.Rules.expected(target):continue
   while level.state.next_id()!=target and not level.state.failed:
    await second_trial(level.state.next_id(),"correct")
   if level.state.failed:check(false,"correct prefix unexpectedly failed "+target);break
   await prepare(target)
   var prefix: Dictionary=level.state.placed.duplicate(true)
   await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons[level.state.Openings.target(target)])
   check(not level.panel.magnifier.visible and level.state.joint==kind,"type selection directly replaces actual waiting stock "+target+"/"+kind)
   await settle(.5);await Pointer.drag(surface,level.view,.25,cases%2==0)
   check(not level.state.failed and level.state.placed==prefix,"shallow wrong approach remains exploratory")
   await Pointer.drag(surface,level.view,1.0,cases%2==0);await wait_motion()
   if target=="plank_0a":
    if kind=="three_way_lap":
     check(level.state.starter_top() and level.state.placed==prefix and not level.state.failed,"wrong three-way middle remains playable until its top seats")
     await settle(.5);await Pointer.drag(surface,level.view,1.0);await wait_motion()
    check(level.state.failed and level.state.placed.size()==1,"wrong first-row stock completes locally before failure "+kind)
    check(level.state.placed.get("plank_0a",{}).get("joint")==kind and not level.state.placed.has("plank_0b") and level.panel.failure_overlay.visible,"wrong completed connector is retained without duplication")
    await capture("direct-"+target+"-"+kind)
    await button(level.panel.failure_restart_button)
   else:
    check(level.state.failed and level.state.placed==prefix and level.panel.failure_overlay.visible,"incompatible committed stock reaches contact then automatically fails "+target+"/"+kind)
    check(level.view.pieces[target].visible and level.view.pieces[target].transform.is_equal_approx(level.view.contact_poses[target]),"failed stock stays at the actual contact pose behind the dialog")
    await capture("direct-"+target+"-"+kind)
    await button(level.panel.failure_restart_button)
   check(not level.state.failed and level.view.preview_progress==0 and level.state.placed.is_empty(),"restart clears the entire failed build")
   cases+=1
 if gpu:check(not root.has_focus(),"GPU host remains unfocused")
 campaign.free();surface.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"images":images,"host_had_focus":root.has_focus() if gpu else false,"renderer":DisplayServer.get_name(),"method":"All eight off-type choices at four manual steps via mouse/touch. Shallow exploration is neutral; committed impossible contact fails automatically; first wrong joints finish locally before failure."}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/level02-late-fit")
 FileAccess.open("res://tests/evidence/level02-late-fit/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LEVEL02_WRONG_TYPE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
