extends "res://tests/observation_repeat_tests.gd"
## Actual game input and GPU frames: cross falls, middle slides, top locks.
const Contact=preload("res://levels/level02/trial_contact.gd")
const Probe=preload("res://tests/stock_clearance.gd")
var frame_count:=0
var frame_folder: String
var trajectories: Dictionary={}
var probe
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var path:="res://tests/evidence/joint-motion/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"actual GPU image "+name);images.append(path)
 # Neutral pass makes the actual interlocking solids visible without grain/color.
 var materials: Dictionary={}
 for mesh in level.view.find_children("*","MeshInstance3D",true,false):
  if not mesh.material_override is StandardMaterial3D or mesh.material_override.albedo_texture==null:continue
  materials[mesh]=mesh.material_override
  var matte:=StandardMaterial3D.new();matte.albedo_color=Color("999999");matte.roughness=1;matte.metallic_specular=0;matte.cull_mode=BaseMaterial3D.CULL_DISABLED
  mesh.material_override=matte
 for i in 2:await process_frame
 RenderingServer.force_draw(false)
 var matte_path:="res://tests/evidence/joint-motion/"+name+"-matte.png"
 check(surface.get_texture().get_image().save_png(matte_path)==OK,"neutral actual interfit geometry "+name);images.append(matte_path)
 for mesh in materials:mesh.material_override=materials[mesh]
 for i in 2:await process_frame
func record_frame() -> void:
 if not gpu:return
 RenderingServer.force_draw(false)
 surface.get_texture().get_image().save_png(frame_folder+"/frame-%04d.png"%frame_count)
 frame_count+=1
func clear_of_real_stock(id: String) -> bool:
 var obstacles: Array=[]
 for node in level.view.fixed.values():obstacles.append_array(Contact.meshes(node,node.transform))
 for previous in level.state.placed:
  if previous!=id:obstacles.append_array(Contact.meshes(level.view.pieces[previous],level.view.pieces[previous].transform))
 for first in Contact.meshes(level.view.pieces[id],level.view.pieces[id].transform):
  for second in obstacles:
   var overlap: AABB=(first.pose*first.mesh.get_aabb()).intersection(second.pose*second.mesh.get_aabb())
   if minf(overlap.size.x,minf(overlap.size.y,overlap.size.z))<=.00002:continue
   if probe.triangles_intersect(first,second):return false
 return true
func record_push(id: String) -> void:
 await settle(.5)
 var start: Vector3=level.view.pieces[id].position
 var origin: Vector2=level.view.drag_grab_screen();var travel: Vector2=level.view.drag_path_screen()
 check(level.view.pick_drag_piece(origin)==id,"real stock is pickable at the visible entry "+id)
 await capture(id+"-before")
 for i in 8:record_frame();await settle(.083)
 await mouse(origin,true)
 var samples: Array=[]
 for step in range(1,25):
  var point:=origin+travel*step/24.0
  var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=travel/24.0;event.button_mask=MOUSE_BUTTON_MASK_LEFT
  surface.push_input(event,true);await process_frame
  var pos: Vector3=level.view.pieces[id].position;samples.append([pos.x,pos.y,pos.z])
  var delta:=pos-start
  check(absf(delta.y)<.0001 and absf(delta.z)<.0001 if id=="three_middle" else absf(delta.x)<.0001 and absf(delta.z)<.0001,"actual movement follows the joint's own entry axis "+id)
  check(clear_of_real_stock(id),"independent actual hull mesh clearance at step "+str(step)+" / "+id)
  if step==12:await capture(id+"-halfway")
  record_frame();await settle(.083)
 await mouse(origin+travel,false);await wait_motion()
 check(level.state.placed.has(id) and not level.state.failed,"real mouse release installs "+id)
 var finish: Vector3=level.view.pieces[id].position
 check(start.x-finish.x>.60 and absf(start.y-finish.y)<.0001 if id=="three_middle" else start.y-finish.y>.60 and absf(start.x-finish.x)<.0001,"side slide and downward drop are different actual motions "+id)
 trajectories[id]={"start":[start.x,start.y,start.z],"finish":[finish.x,finish.y,finish.z],"samples":samples}
 await capture(id+"-seated")
 for i in 14:record_frame();await settle(.083)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 frame_folder="/private/tmp/guchuan-joint-motion-"+str(Time.get_unix_time_from_system()).replace(".","-")
 DirAccess.make_dir_recursive_absolute(frame_folder)
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/joint-motion")
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.3)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 probe=Probe.new()
 for id in ["plank_0a","plank_1a","plank_2a"]:await second_trial(id,"correct")
 await prepare("cross_upper");await record_push("cross_upper");await button(level.panel.overview_button)
 await prepare("three_middle");await record_push("three_middle");await button(level.panel.next_piece_button)
 await prepare("three_upper");await record_push("three_upper");await button(level.panel.overview_button)
 await second_trial("bulkhead","correct")
 check(level.state.completed and not level.state.failed,"distinct joint motions preserve complete hull success")
 await button(level.panel.success_panel.get_child(0).get_child(3))
 await capture("complete-hull-overview")
 if gpu:check(not root.has_focus(),"GPU instance stays unfocused")
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"trajectories":trajectories,"frames":frame_count,"frame_folder":frame_folder,"video_fps":12,"scope":"Actual Viewport mouse input on production geometry. Cross downward, middle horizontal through retained guide, top downward. 24 independent hull-mesh checks per motion, real rendered frames, full correct build."}
 probe.free();campaign.free();surface.free()
 FileAccess.open("res://tests/evidence/joint-motion/"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("JOINT_MOTION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
