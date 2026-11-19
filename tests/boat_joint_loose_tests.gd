extends "res://tests/boat_joint_interaction_tests.gd"
## Real GUI wide-notch route, including every wave frame against actual hull wood.
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
 for id in ["plank_0a","plank_1a","plank_2a"]:await second_trial(id,"correct")
 await prepare("cross_upper");await button(level.panel.opening_buttons.B);await push()
 var rest: Transform3D=level.view.pieces.cross_upper.transform
 check(level.state.placed.has("cross_upper") and not level.state.failed,"wide lap remains a credible installed but loose connection")
 check(absf(rest.origin.y-1.25)<.0001 and rest.basis.is_equal_approx(Basis.IDENTITY),"wide lap reaches the same floor, with no vertical gap or tipping")
 await capture("wide-cross-seated-with-clearance")
 await drag_region(workspace_rect(),Vector2(90,-50))
 await capture("wide-cross-rotated-clearance")
 check(level.view.pieces.cross_upper.transform.is_equal_approx(rest),"viewing the side clearance does not move the fitted stock")
 await button(level.panel.overview_button)
 for id in ["three_middle","three_upper"]:await second_trial(id,"correct")
 await prepare("bulkhead")
 var probe=load("res://tests/stock_clearance.gd").new()
 var peak:=0.0;var wave_frames:=0;var captured:=false
 await settle(.5);await Pointer.drag(surface,level.view,1.0)
 var deadline:=Time.get_ticks_msec()+10000
 while level.busy and Time.get_ticks_msec()<deadline:
  probe.sample(level)
  if level.view.trial.phase=="impact":
   wave_frames+=1
   var displacement: Vector3=level.view.pieces.cross_upper.position-rest.origin
   peak=maxf(peak,absf(displacement.z))
   check(absf(displacement.x)<.0001 and absf(displacement.y)<.0001 and absf(displacement.z)<=.0251,"wave slides along the real notch without lifting or passing the shoulder")
   if absf(displacement.z)>.02 and not captured:
    captured=true;await capture("wide-cross-wave")
  await process_frame
 check(wave_frames>10 and peak>.02,"actual sea-trial animation visibly exercises the loose side clearance")
 check(probe.violations.is_empty(),"independent mesh observer finds no wave penetration: "+str(probe.violations.keys()))
 check(level.state.failed and level.state.failure_result().get("code")=="structure" and level.state.placed.size()==10,"complete loose build ends in structural failure")
 check(level.view.trial.drops.get_child_count()==0 and level.view.trial.phase=="loose","internal loose joint creates no invented hull leakage")
 check(level.view.pieces.cross_upper.transform.is_equal_approx(rest),"loose member returns to its actual resting contact after the wave")
 await capture("wide-cross-structural-verdict")
 await button(level.panel.failure_restart_button)
 check(level.state.placed.is_empty() and level.view.trial.phase=="idle","restart clears the entire trial and wave")
 if gpu:check(not root.has_focus(),"GPU host remains unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"wave_frames":wave_frames,"peak_side_travel":peak,"scope":"Actual Viewport input builds all ten members with cross B, then observes real sea-trial frames with independent mesh clearance; distinguishes side play, no invented leak, final structural verdict and restart."}
 probe.free();campaign.free();surface.free()
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/boat-joint-redesign")
 FileAccess.open("res://tests/evidence/boat-joint-redesign/loose-"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BOAT_LOOSE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
