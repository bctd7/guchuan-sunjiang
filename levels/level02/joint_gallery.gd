extends Control
## Three real ship-material candidate previews; assembled from current G solids.
const G=preload("res://models/ship/hull/ship_geometry.gd")
const TYPES=["tongue_groove","cross_lap","three_way_lap"]
var movers: Dictionary={}
var offsets: Dictionary={}
var tweens: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in TYPES.size():
		var id=TYPES[i]
		var c=SubViewportContainer.new()
		c.position=Vector2(i*355,0)
		c.size=Vector2(330,120)
		c.stretch=true
		c.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var vp=SubViewport.new()
		vp.size=Vector2i(330,120)
		vp.own_world_3d=true
		vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		c.add_child(vp)
		var root=Node3D.new()
		vp.add_child(root)
		var envnode=WorldEnvironment.new()
		var env=Environment.new()
		env.background_mode=Environment.BG_COLOR
		env.background_color=Color("eee3cf")
		env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color=Color("fff5df")
		env.ambient_light_energy=.3
		envnode.environment=env
		root.add_child(envnode)
		var sun=DirectionalLight3D.new()
		sun.rotation_degrees=Vector3(-40,-30,0)
		sun.light_energy=.65
		root.add_child(sun)
		var a=G.material(Color("b89569"))
		var b=G.material(Color("dcc29b"))
		var moving=Node3D.new()
		root.add_child(moving)
		var offset=Vector3(0,.55,0)
		if id=="cross_lap":
			G.cross_member(root,false,a,1.75)
			G.cross_member(moving,true,b,1.75)
		elif id=="tongue_groove":
			G.plank(root,-1,1,0,a)
			G.plank(moving,-1,1,1,b)
			offset=Vector3(0,0,.35)
		else:
			G.three_member(root,0,a)
			var mid=Node3D.new()
			root.add_child(mid)
			G.three_member(mid,1,b)
			mid.position.y=0.0
			G.three_member(moving,2,G.material(Color("9e805d")))
			offset=Vector3(0,.70,0)
		moving.position=offset
		movers[id]=moving
		offsets[id]=offset
		var cam=Camera3D.new()
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL
		cam.size=2.3
		cam.position=Vector3(0,6,2.5) if id=="three_way_lap" else Vector3(2.3,3,4)
		root.add_child(cam)
		cam.look_at(Vector3(0,.18,.7 if id=="tongue_groove" else 0))
		cam.current=true
func choose(id: String) -> void:
	for key in tweens:
		if is_instance_valid(tweens[key]): tweens[key].kill()
	tweens.clear()
	for key in movers: movers[key].position=offsets[key]
	if not movers.has(id): return
	var tween=create_tween().set_loops()
	tween.tween_property(movers[id],"position",Vector3.ZERO,1.1)
	tween.tween_interval(.35)
	tween.tween_property(movers[id],"position",offsets[id],1.1)
	tween.tween_interval(.35)
	tweens[id]=tween
