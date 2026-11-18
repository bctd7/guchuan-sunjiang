extends SceneTree
const G=preload("res://models/ship/hull/ship_geometry.gd")
func _initialize():call_deferred("run")
func run():
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var viewport=SubViewport.new();viewport.size=Vector2i(1200,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.3;camera.position=Vector3(2,1.8,-2);camera.look_at(Vector3(0,0,.7));camera.current=true
 var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.5
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.15,.18,.21);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
 var fixed=Node3D.new();world.add_child(fixed);G.plank(fixed,-.6,.6,0,G.material(Color(.5,.29,.12)))
 var moving=Node3D.new();world.add_child(moving);G.plank(moving,-.6,.6,1,G.material(Color(.72,.48,.24)))
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/deck-round")
 for state in ["separated","halfway","assembled","close"]:
  moving.position.z={"separated":.28,"halfway":.045,"assembled":0.0,"close":.16}[state]
  if state=="close":camera.size=.6;camera.position=Vector3(1.2,.6,.1);camera.look_at(Vector3(.48,0,.78))
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("res://tests/evidence/deck-round/"+state+".png")
 quit()
