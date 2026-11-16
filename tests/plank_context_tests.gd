extends "res://tests/observation_repeat_tests.gd"
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var path:="res://tests/evidence/plank-context/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"GPU context "+name);images.append(path)
func run():
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/plank-context")
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 await second_trial("plank_0a","correct")
 check(level.state.placed.size()==6 and level.state.next_id()=="cross_upper","all repeated rows form one completed board group")
 await Navigation.open_local(surface,level,"plank_2b");await settle(.3)
 check(level.view.local_context.visible and level.view.local_context.get_child_count()>10,"completed board review retains real hull framing")
 for id in level.Rules.GROUPS[0]:check(level.view.pieces[id].visible,"review displays actual installed board "+id)
 check(level.view.model_seams.find_children("*","Label3D",true,false).is_empty(),"plank joints have no floating captions")
 var prefix: Dictionary=level.state.placed.duplicate(true)
 for dimensions in [Vector2i(960,600),Vector2i(1440,900)]:
  surface.size=dimensions;await settle(.2)
  var frame:=workspace_rect().grow(1)
  check(level.view.inspection_focus_corners().all(func(p):return frame.has_point(level.view.project_point(p))),"completed group and hull reference fit "+str(dimensions))
  check(level.state.placed==prefix and level.view.preview_id.is_empty(),"review does not create another manual assembly")
  await capture("board-group-review-"+str(dimensions.x))
 await button(level.panel.overview_button);await button(level.panel.undo_button)
 check(level.state.placed.is_empty() and not level.view.pieces.plank_0b.visible and not level.view.pieces.plank_1a.visible,"withdrawn group does not leave phantom installed boards")
 if gpu:check(not root.has_focus(),"GPU host remains unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"Real UI after one representative drag: review of all six installed boards retains actual hull framing at two sizes, no floating labels or extra manual rows; group undo removes all installed boards."}
 campaign.free();surface.free()
 FileAccess.open("res://tests/evidence/plank-context/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PLANK_CONTEXT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
