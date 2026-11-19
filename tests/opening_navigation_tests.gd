extends "res://tests/opening_dimensions_tests.gd"
## Exercise comparison navigation after the initial screenshot: wheel, orbit,
## existing reset, magnifier and return. Uses real viewport input events.
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var folder:="res://tests/evidence/comparison-navigation"
 DirAccess.make_dir_recursive_absolute(folder)
 var path:=folder+"/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"capture "+name);images.append(path)

func wheel(control: Control,direction: MouseButton) -> void:
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
 surface.push_input(motion,true);await process_frame
 var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=direction;event.pressed=true
 surface.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;surface.push_input(event,true)
 await settle(.08)

func whole_model_visible(preview) -> bool:
 var frame:=Rect2(Vector2.ZERO,Vector2(preview.viewport.size)).grow(1)
 for mesh in preview.model_root.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree():continue
  for corner in 8:
   var point: Vector3=mesh.global_transform*mesh.get_aabb().get_endpoint(corner)
   if preview.camera.is_position_behind(point) or not frame.has_point(preview.camera.unproject_position(point)):return false
 return true

func check_navigation(scope: String) -> void:
 var gallery=level.panel.opening_gallery
 var comparison=level.panel.opening_measure
 var choice: String=level.state.opening
 var placed: Dictionary=level.state.placed.duplicate(true)
 var main_size: float=level.view.camera.size
 var starting_size: float=gallery.previews.A.camera.size
 await wheel(gallery.previews.A,MOUSE_BUTTON_WHEEL_DOWN)
 check(gallery.previews.A.camera.size>starting_size,"wheel actually reaches the candidate "+scope)
 for id in ["A","B","C"]:
  check(is_equal_approx(gallery.previews[id].camera.size,gallery.previews.A.camera.size),"wheel preserves equal A/B/C scale "+scope+"/"+id)
 if gpu and comparison.reference.kind not in ["paired","shape"]:
  check(is_equal_approx(comparison.pixel_scale,gallery.previews.A.size.y/gallery.previews.A.camera.size),"receiver follows the displayed candidate scale after wheel "+scope)
 check(is_equal_approx(level.view.camera.size,main_size),"candidate wheel leaves assembly framing alone "+scope)
 await capture(scope+"-scaled")
 for step in 6:await wheel(gallery.previews.C,MOUSE_BUTTON_WHEEL_UP)
 for id in ["A","B","C"]:
  check(is_equal_approx(gallery.previews[id].camera.size,gallery.previews.A.camera.size),"zooming another candidate preserves common scale "+scope+"/"+id)
 if gpu and comparison.reference.kind not in ["paired","shape"]:
  check(is_equal_approx(comparison.pixel_scale,gallery.previews.A.size.y/gallery.previews.A.camera.size),"receiver remains at candidate scale during close inspection "+scope)
 if scope in ["plank_0a-1440","cross_upper-960"]:await capture(scope+"-closeup")
 await drag_region(gallery.previews.B.get_global_rect(),Vector2(34,10),scope.contains("960"))
 check(not gallery.previews.B.camera.basis.is_equal_approx(gallery.marks.B.front),"candidate orbit works "+scope)
 if gallery.measurements.B.kind=="groove":check(gallery.previews.B.camera.far>50,"rotating restores complete board depth "+scope)
 check(level.state.opening==choice and level.state.placed==placed,"wheel and orbit leave choices and assembly alone "+scope)
 await button(level.panel.zoom_reset_button)
 for id in ["A","B","C"]:
  check(is_equal_approx(gallery.previews[id].zoom_factor,1.0) and gallery.previews[id].camera.basis.is_equal_approx(gallery.marks[id].front),"existing reset restores candidate comparison view "+scope+"/"+id)
 await button(gallery.inspect_buttons.B)
 check(level.panel.magnifier.visible and whole_model_visible(level.panel.magnifier.preview),"magnifier initially fits the complete candidate "+scope)
 check(level.panel.magnifier.preview.camera.far>50,"magnifier has no thumbnail depth slice "+scope)
 await capture(scope+"-magnified")
 await button(level.panel.magnifier.close_button)
 check(level.state.opening==choice and level.state.placed==placed,"magnifier return preserves selection and assembly "+scope)
 check_rendered_stock(gallery,scope+"-returned")

func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
 await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
 for target in ["plank_0a","cross_upper","three_middle","three_upper"]:
  for window in [Vector2i(1440,900),Vector2i(960,600)]:
   surface.size=window;await seed_stage(target)
   await check_navigation(target+"-"+str(window.x))
 surface.size=Vector2i(1440,900);await seed_stage("plank_0a")
 for kind in ["cross_lap","three_way_lap"]:
  await button(level.panel.joint_buttons[kind]);await button(level.panel.opening_buttons.C)
  await check_navigation("first-"+kind)
 check(not root.has_focus() if gpu else true,"GPU audit keeps application focus unchanged")
 campaign.free();surface.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"Real wheel/orbit/reset/magnifier/return input for four manual stages and two adapted first joints, including 1440 and 960 widths; comparison scale, full candidate bounds and unchanged assembly."}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/comparison-navigation")
 FileAccess.open("res://tests/evidence/comparison-navigation/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("OPENING_NAVIGATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
