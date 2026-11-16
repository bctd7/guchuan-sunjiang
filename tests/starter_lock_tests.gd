extends "res://tests/observation_repeat_tests.gd"
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var path:="res://tests/evidence/starter-lock/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"GPU evidence "+name);images.append(path)
func finish_held(name: String) -> void:
 var start: Vector2=level.view.drag_grab_screen()
 var travel: Vector2=level.view.drag_path_screen()*(1.0-level.view.preview_progress)
 await mouse(start,true)
 for step in range(1,13):
  var event:=InputEventMouseMotion.new();event.position=start+travel*step/12.0;event.global_position=event.position;event.relative=travel/12.0;event.button_mask=MOUSE_BUTTON_MASK_LEFT
  surface.push_input(event,true);await process_frame
 await capture(name)
 check(not level.state.failed and not level.panel.failure_overlay.visible,"holding at full contact never reports failure before release")
 await mouse(start+travel,false)
 check(not level.state.failed and level.busy,"final seating tween runs before the completed-joint verdict")
 await wait_motion()
func run():
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/starter-lock")
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 for option in ["A","B","C"]:
  await prepare("plank_0a");await button(level.panel.joint_buttons.three_way_lap);await button(level.panel.opening_buttons[option]);await settle(.5)
  var parked: Transform3D=level.view.lock_waiting_tops.plank_0a.transform
  var parked_shape: Array=level.view.TrialContact.points(level.view.TrialContact.meshes(level.view.lock_waiting_tops.plank_0a,Transform3D.IDENTITY))
  check(level.view.lock_waiting_tops.plank_0a.get_meta("opening")==option,"the matching top is already supplied before either stroke "+option)
  check(level.view.lock_waiting_tops.plank_0a.visible and level.view.pieces.plank_0a.visible,"two real uninstalled parts are visible before the first stroke "+option)
  await capture(option+"-two-waiting-parts")
  await Pointer.drag(surface,level.view,.4)
  check(level.state.placed.is_empty() and level.state.starter_locks.is_empty() and level.view.lock_waiting_tops.plank_0a.transform==parked,"shallow middle movement leaves the top parked")
  await Pointer.drag(surface,level.view,1.0);await wait_motion()
  check(level.state.starter_top() and level.state.placed.is_empty() and not level.state.failed,"middle seats without completing the joint or automatically skipping its top "+option)
  check(level.view.lock_middles.plank_0a.visible and not level.view.lock_waiting_tops.plank_0a.visible,"seated middle stays visible while the same top becomes active")
  check(level.view.pieces.plank_0a.transform.is_equal_approx(parked),"top activation preserves its actual parked transform")
  check(level.view.TrialContact.points(level.view.TrialContact.meshes(level.view.pieces.plank_0a,Transform3D.IDENTITY))==parked_shape,"activating the top cannot change its preselected geometry "+option)
  check(level.panel.joint_buttons.three_way_lap.disabled and not level.panel.options_panel.visible,"middle choice cannot silently morph while fitting the top")
  var held: Transform3D=level.view.lock_middles.plank_0a.transform
  await capture(option+"-middle-seated-top-waiting")
  if option=="C":
   await button(level.panel.overview_button);await button(level.panel.observe_button);await settle(.5)
   check(level.state.starter_top() and level.state.placed.is_empty() and level.view.lock_middles.plank_0a.visible and level.view.pieces.plank_0a.transform.is_equal_approx(parked),"returning to the frame and reopening preserves the incomplete middle/top assembly")
   await button(level.panel.observer_undo_button)
   check(level.state.starter_locks.is_empty() and level.state.placed.is_empty(),"taking back middle clears only the incomplete local joint")
   await prepare("plank_0a");await button(level.panel.joint_buttons.three_way_lap);await button(level.panel.opening_buttons.C);await settle(.5)
   await Pointer.drag(surface,level.view,1.0);await wait_motion()
  await settle(.5);await Pointer.drag(surface,level.view,.4)
  check(not level.state.failed and level.view.lock_middles.plank_0a.transform.is_equal_approx(held),"shallow top trial is neutral and cannot drag the seated middle")
  await finish_held(option+"-top-at-contact")
  check(level.state.failed and level.state.placed.size()==1 and level.state.starter_completed("plank_0a"),"paired middle and top fully assemble before the wrong-family verdict "+option)
  check(level.view.pieces.plank_0a.transform.is_equal_approx(level.view.lock_seats.plank_0a) and level.view.lock_middles.plank_0a.transform.is_equal_approx(held),"failure retains the fully seated top and middle "+option)
  check(level.panel.failure_overlay.visible and level.panel.failure_overlay.title.text=="拼装错误" and level.state.failure_result().code=="assembly_mismatch","completed local joint opens the requested error dialog "+option)
  check(not level.panel.next_piece_button.visible and level.panel.overview_button.disabled,"failed workspace no longer offers to install another piece")
  check(level.view.inspected and level.state.selected=="plank_0a" and not level.state.placed.has("plank_0b") and level.view.animations.is_empty(),"failure stays at this joint without automatic duplication or next-row navigation "+option)
  check(not level.interaction.is_processing_input() and not level.state.can_attempt("plank_1a").ok,"failed build blocks further assembly")
  await capture(option+"-assembled-error")
  await button(level.panel.failure_restart_button)
  check(not level.state.failed and level.state.placed.is_empty() and level.state.starter_locks.is_empty(),"failure restart clears the complete and pending local pieces")
 if gpu:check(not root.has_focus(),"GPU host stays unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"Actual pointer strokes: ABC retain paired geometry, seat middle then top, and open the local wrong-family dialog only after the last seating tween. Held contact, shallow motion and the middle stage stay neutral. No automatic companion or next-row navigation; pending undo/reentry and failure restart remain usable."}
 campaign.free();surface.free()
 FileAccess.open("res://tests/evidence/starter-lock/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STARTER_LOCK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
