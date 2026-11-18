extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var viewport=SubViewport.new();viewport.size=Vector2i(1200,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var view=load("res://levels/level02/hull_view.gd").new();viewport.add_child(view)
 view.backdrop.hide()
 for node in view.pieces.values():node.show()
 var camera: Camera3D=view.camera
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/rounded-hull")
 for shot in ["overall","side","joint"]:
  camera.h_offset=0;camera.v_offset=0
  camera.size=10.5 if shot!="joint" else 1.0
  camera.position={"overall":Vector3(9,7,10),"side":Vector3(0,2.3,12),"joint":Vector3(-2.4,2.0,3.5)}[shot]
  camera.look_at(Vector3(0,1,0) if shot!="joint" else Vector3(-2.4,.85,1.0))
  if shot=="joint":
   view.pieces.plank_2a.hide();view.pieces.plank_2b.hide()
   view.pieces.plank_1a.position+=Vector3(0,.22,.16)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("res://tests/evidence/rounded-hull/"+shot+".png")
 quit()
