extends Node3D
const G = preload("res://models/ship/rigging/ship_geometry.gd")
var ship: Node3D

func _ready() -> void:
	ship = preload("res://models/ship/rigging/finished_ship.gd").new()
	add_child(ship)
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://levels/level03/harbor_water.gdshader")
	G.box(self,Vector3(-80,-.45,-80),Vector3(80,0,80),sea,"HarborWater")
	var timber := G.wood(Color("946e4f"))
	var end_grain := G.wood(Color("796049"))
	var rope := G.wood(Color("c6a47a"))
	for i in 17:
		var x := -6.0+i*.30
		G.box(self,Vector3(x,.24,-3.40),Vector3(x+.29,.34,-1.85),timber,"PierPlank")
	for x in [-5.80,-3.55,-1.30]:
		for z in [-3.28,-1.98]:
			G.cylinder(self,.085,1.35,Vector3(x,.17,z),end_grain,"PierPost")
			for wrap in 3:
				G.ring(self,.08,.103,.0,.028,Vector3(x,.61+wrap*.037,z),rope,0,TAU,"RopeWrap")

func sail_out() -> Tween:
	ship.position = Vector3(-.9,.10,-.5)
	ship.rotation.z = .045
	var motion := create_tween().set_parallel(true)
	motion.tween_property(ship,"position",Vector3(.55,.14,.3),2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(ship,"rotation:z",-.018,1.1).set_trans(Tween.TRANS_SINE)
	motion.chain().tween_property(ship,"rotation:z",0.0,.45)
	return motion
