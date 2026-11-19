extends "res://tests/observation_repeat_tests.gd"
const Lighting=preload("res://levels/level02/timber_lighting.gd")
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var path:="res://tests/evidence/first-join/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"first joint GPU image "+name);images.append(path)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/first-join")
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
 await prepare("plank_0a")
 var receiver: Transform3D=level.view.fixed.starter.transform
 var solids_before: Array=[]
 for part in level.view.TrialContact.meshes(level.view.fixed.starter,receiver):solids_before.append(part.mesh.get_faces())
 for kind in ["cross_lap","three_way_lap","tongue_groove"]:
  await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons.C if kind=="three_way_lap" else level.panel.opening_buttons.B)
  check(not level.panel.magnifier.visible and level.state.joint==kind,"type click changes the actual stock directly without opening preview "+kind)
  check(level.view.preview_progress==0,"each type starts physically separated from its receiver")
  check(level.view.fixed.starter.transform.is_equal_approx(receiver),"fixed receiver remains at the same transform")
  var solids_after: Array=level.view.TrialContact.meshes(level.view.fixed.starter,receiver)
  check(solids_after.size()==solids_before.size(),"receiver does not morph on type change")
  for index in solids_before.size():check(solids_after[index].mesh.get_faces()==solids_before[index],"same fixed socket triangles for all candidates")
  await capture(kind+"-direct-separated")
  await settle(.5);await Pointer.drag(surface,level.view,.5)
  check(level.view.preview_progress>.4 and level.state.placed.is_empty(),"shallow real insertion is exploratory "+kind)
  await capture(kind+"-direct-halfway")
  if kind!="tongue_groove":
   # Hold the actual wood at contact before release/automatic companion so
   # the GPU record shows the single thick joint in the local assembly view.
   var start: Vector2=level.view.drag_grab_screen()
   var travel: Vector2=level.view.drag_input_path_screen()*(1.0-level.view.preview_progress)
   await mouse(start,true)
   for step in range(1,13):
    var motion:=InputEventMouseMotion.new();motion.position=start+travel*step/12.0;motion.global_position=motion.position;motion.relative=travel/12.0;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
    surface.push_input(motion,true);await process_frame
   await capture(kind+"-single-stock-in-socket")
   await mouse(start+travel,false);await wait_motion()
   if kind=="three_way_lap":
    check(level.state.starter_top() and level.state.placed.is_empty(),"first stroke seats only the middle of the three-member joint")
    await settle(.5);await Pointer.drag(surface,level.view,1.0);await wait_motion()
   check(level.state.failed and level.state.placed.size()==1,"physically seated wrong family is retained behind the local error dialog "+kind)
   check(level.state.selected=="plank_0a" and level.view.inspected and level.panel.failure_overlay.title.text=="拼装错误","finished wrong joint does not advance or auto-repeat")
   await capture(kind+"-direct-contact")
   await button(level.panel.failure_restart_button);await prepare("plank_0a")
  else:await Pointer.drag(surface,level.view,-.5)
 check(level.view.camera.get_children().filter(func(node):return node is Light3D).is_empty(),"no camera-relative lamp on first joint")
 check(level.view.local_context.get_child_count()>5,"default first view retains hull framing around receiver")
 await capture("plank-context-before")
 var camera_pose: Transform3D=level.view.camera.transform;var camera_size: float=level.view.camera.size
 await button(level.panel.transparent_button)
 check(level.view.transparent and level.view.camera.size<camera_size,"slot detail is an explicit closer view")
 await capture("plank-slot-detail")
 await button(level.panel.transparent_button)
 check(level.view.camera.transform.is_equal_approx(camera_pose) and is_equal_approx(level.view.camera.size,camera_size),"return from detail restores prior framing")
 for dimensions in [Vector2i(960,600),Vector2i(1440,900)]:
  surface.size=dimensions;await settle(.3)
  await button(level.panel.zoom_in_button);await button(level.panel.zoom_reset_button);await settle(.4)
  await Pointer.drag(surface,level.view,.25,true)
  check(level.view.preview_progress>.20 and level.state.placed.is_empty(),"touch shallow insertion remains usable in structural context "+str(dimensions))
  await capture("plank-context-"+str(dimensions.x))
  await Pointer.drag(surface,level.view,-.25)
 await settle(.5);await Pointer.drag(surface,level.view,.5);await capture("plank-context-halfway")
 await Pointer.drag(surface,level.view,1.0);await wait_motion()
 check(level.state.placed.size()==6 and level.state.placed.plank_0b.automatic,"all six real planks complete through independent automatic paths")
 await capture("correct-pair-overview")
 if gpu:check(not root.has_focus(),"GPU host remains unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"First plank direct selection, shallow insertion and completed wrong-type seating before error/restart on a fixed housed rail; detail restoration, two input resolutions and the complete repeated board group."}
 campaign.free();surface.free()
 FileAccess.open("res://tests/evidence/first-join/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FIRST_JOIN ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
