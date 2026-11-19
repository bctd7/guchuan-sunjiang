extends "res://tests/three_group_tests.gd"
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var folder:="res://tests/evidence/unified-fit"
 DirAccess.make_dir_recursive_absolute(folder)
 var path:=folder+"/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"capture "+name);images.append(path)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://app/campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
 await button(campaign.chapter_buttons[2]);level=campaign.current_chapter;await button(level.learning.start_button)
 var combinations: Array=[]
 for plank in ["A","B","C"]:
  for frame in ["A","B","C"]:
   level._restart()
   await install("plank_0a",plank)
   check(not level.state.failed and level.state.placed.size()==6,"six real boards retain and continue with opening "+plank)
   var retained: Dictionary={}
   for id in level.Rules.GROUPS[0]:retained[id]=mesh_signature(level.view.pieces[id])
   await install("cross_upper",frame)
   check(not level.state.failed and level.state.placed.size()==8,"both cross frame and bulkhead can continue "+plank+"/"+frame)
   check(level.state.placed.bulkhead.opening==frame and level.state.placed.bulkhead.demonstrated_by=="cross_upper","automatic panel retains the chosen wrong cut")
   for id in retained:check(mesh_signature(level.view.pieces[id])==retained[id],"later structure preserves earlier real board shape and pose "+id)
   await install("three_middle")
   check(not level.state.failed and level.state.placed.size()==9,"seatable mistakes still allow the next joint")
   if plank!="B" or frame!="C":await capture("continued-"+plank+"-"+frame)
   await install("three_upper")
   var correct: bool=plank=="B" and frame=="C"
   check(level.state.placed.size()==10 and level.state.checked,"all ten real parts reach the wave trial before this verdict")
   check(level.state.completed==correct and level.state.failed==not correct,"wrong but continuable construction is judged only by the final trial "+plank+"/"+frame)
   for id in level.Rules.GROUPS[0]:check(level.state.placed[id].opening==plank,"no repeated plank silently becomes the correct answer")
   if not correct:check(level.state.failure_result().code in ["opening","mixed","structure"],"wave failure is not disguised as an early installation failure")
   combinations.append({"plank":plank,"frame":frame,"placed":level.state.placed.size(),"wave_checked":level.state.checked,"completed":level.state.completed})
 if gpu:check(not root.has_focus(),"no-focus GPU run")
 campaign.free();surface.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"combinations":combinations,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"All nine plank/cross option combinations, all four manual drags and six automatic members through real UI. Exact choices and earlier meshes retained; physically continuable errors reach full-hull wave trial."}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/unified-fit")
 FileAccess.open("res://tests/evidence/unified-fit/continuation-"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CONTINUATION_MATRIX ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
