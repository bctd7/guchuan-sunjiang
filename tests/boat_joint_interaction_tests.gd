extends "res://tests/observation_repeat_tests.gd"
## The nine real middle/top combinations use the same two-outcome interaction.
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var folder:="res://tests/evidence/boat-joint-redesign"
 DirAccess.make_dir_recursive_absolute(folder)
 var path:=folder+"/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"GPU frame "+name);images.append(path)
func push() -> void:
 await settle(.5);await Pointer.drag(surface,level.view,.80)
 check(level.busy and not level.state.failed,"committed release still finishes its visible contact motion before verdict")
 await wait_motion()
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
 await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
 for id in ["plank_0a","cross_upper"]:await second_trial(id,"correct")
 var prefix: Dictionary=level.state.placed.duplicate(true)
 check(prefix.size()==8,"real pointer-built boards and frame supply the retained test prefix")
 for middle in ["A","B","C"]:
  for top in ["A","B","C"]:
   # Restore the same actually assembled prefix so each pair isolates its own
   # real side-entry and downward strokes, instead of testing answer flags.
   level._restart();level.state.placed=prefix.duplicate(true);level.state.select("three_middle")
   await prepare("three_middle");await button(level.panel.opening_buttons[middle]);await push()
   check(not level.state.failed and level.state.placed.size()==9 and level.state.placed.three_middle.opening==middle,"every middle option really seats and continues "+middle)
   var held_prefix: Dictionary=level.state.placed.duplicate(true)
   var held_model: String=mesh_signature(level.view.pieces.three_middle)
   await button(level.panel.next_piece_button);await prepare("three_upper");await button(level.panel.opening_buttons[top])
   check(is_equal_approx(level.panel.opening_measure.dimensions.width,.13 if middle=="A" else .284),"reference follows the installed middle's actual upper mouth")
   await settle(.5);await Pointer.drag(surface,level.view,.25)
   check(not level.state.failed and level.state.placed==held_prefix and not level.panel.failure_overlay.visible,"shallow mismatched top exploration remains neutral")
   await push()
   var fits: bool=middle=="C" and top=="A"
   if fits:
    check(level.state.completed and not level.state.failed and level.state.placed.size()==10,"matching actual channels finish the whole hull")
    await capture("matching-middle-and-top-complete")
   else:
    check(level.state.failed and level.state.failure_result().code=="assembly_failed" and level.state.placed==held_prefix,"impossible top automatically fails without a third held-obstruction mode "+middle+"/"+top)
    check(level.panel.failure_overlay.visible and not level.state.checked,"failure is automatic at contact, before wave trial")
    check(level.view.pieces.three_upper.visible and level.view.pieces.three_upper.transform.is_equal_approx(level.view.contact_poses.three_upper),"blocked stock remains visible at real contact behind failure")
    check(mesh_signature(level.view.pieces.three_middle)==held_model,"later top cannot morph or correct the retained wrong middle")
    check(level.view.pieces.three_upper.position.y>level.view.THREE_CENTER.y+.05,"actual top remains above its obstructing shoulders")
    await capture("automatic-failure-"+middle+"-"+top)
    if middle=="A" and top=="A":
     await button(level.panel.failure_return_button);await button(campaign.chapter_buttons[2]);await button(level.learning.start_button)
     check(level.state.failed and level.panel.failure_overlay.visible and level.state.placed==held_prefix,"terminal failure persists through directory reentry")
    await button(level.panel.failure_restart_button)
    check(not level.state.failed and level.state.placed.is_empty(),"failure restart clears the whole run")
 if gpu:check(not root.has_focus(),"GPU host stays unfocused")
 campaign.free();surface.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"All nine middle/top combinations, real side/down pointer strokes against an eight-piece prefix originally assembled through real UI. Shallow exploration, visible final contact, automatic failure/restart, actual retained predecessor, and correct whole-hull completion."}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/boat-joint-redesign")
 FileAccess.open("res://tests/evidence/boat-joint-redesign/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BOAT_INTERACTION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
