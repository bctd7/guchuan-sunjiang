extends RefCounted
## Fixed seat rail and keyed first-row planks. No State, UI or lighting dependency.
const G=preload("res://models/ship/hull/ship_geometry.gd")
const CENTERS=[-1.55,1.05]
const SOCKET_WIDTH:=.284
const KEY_WIDTH:=.276
const ANGLE:=-.95

static func section(host: Node3D,polygon: PackedVector2Array,left: float,right: float,material: Material) -> void:
	if right-left<.00001 or polygon.size()<3:return
	G.Shell.loft(host,polygon,left,right,material)

static func clip_height(polygon: PackedVector2Array,above: bool) -> PackedVector2Array:
	# Section coordinates are local Y/Z. The seat is horizontal at world Y=.26.
	var result:=PackedVector2Array()
	for index in polygon.size():
		var a:=polygon[index];var b:=polygon[(index+1)%polygon.size()]
		var da:=cos(ANGLE)*a.x-sin(ANGLE)*a.y
		var db:=cos(ANGLE)*b.x-sin(ANGLE)*b.y
		var inside_a: bool=da>=0 if above else da<=0
		var inside_b: bool=db>=0 if above else db<=0
		if inside_a:result.append(a)
		if inside_a!=inside_b:result.append(a.lerp(b,da/(da-db)))
	return result

static func rail(host: Node3D,material: Material) -> void:
	host.set_meta("wood_axis",Vector3.RIGHT)
	host.set_meta("receiving_dimensions",{"kind":"tongue","width":G.TONGUE_WIDTH,"depth":G.TONGUE_DEPTH,"offset":0.0,"stock":G.PLANK_THICKNESS})
	var sections: Array[PackedVector2Array]=[
		PackedVector2Array([Vector2(-.09,-.20),Vector2(.09,-.20),Vector2(.09,0),Vector2(-.09,0)]),
		PackedVector2Array([Vector2(-G.TONGUE_WIDTH*.5,0),Vector2(G.TONGUE_WIDTH*.5,0),Vector2(G.TONGUE_WIDTH*.5,G.TONGUE_DEPTH),Vector2(-G.TONGUE_WIDTH*.5,G.TONGUE_DEPTH)])]
	sections[1]=G.rounded_tip(sections[1],.018,[2,3])
	for polygon in sections:
		var start: float=-4.0
		for center in CENTERS:
			section(host,polygon,start,center-SOCKET_WIDTH*.5,material)
			section(host,clip_height(polygon,false),center-SOCKET_WIDTH*.5,center+SOCKET_WIDTH*.5,material)
			start=center+SOCKET_WIDTH*.5
		section(host,polygon,start,4.0,material)

static func plank_keys(host: Node3D,left: float,right: float,offset: float,material: Material,centers: Array=CENTERS) -> void:
	# The correct first board fills the fixed housing with integral keys. They
	# enter from above along the existing plank path, never appear on release.
	var body:=PackedVector2Array([Vector2(-.09,-.20),Vector2(.09,-.20),Vector2(.09,0),Vector2(-.09,0)])
	var tongue:=PackedVector2Array([Vector2(-.03,0),Vector2(.04,0),Vector2(.04,.09),Vector2(-.03,.09)])
	tongue=G.rounded_tip(tongue,.018,[2,3])
	for center in centers:
		if center<left or center>right:continue
		for polygon in [body,tongue]:
			var key:=clip_height(polygon,true)
			for i in key.size():key[i].x=clampf(key[i].x+offset,-.09,.09)
			section(host,key,center-KEY_WIDTH*.5,center+KEY_WIDTH*.5,material)

static func cross_stock(host: Node3D,material: Material,option: String) -> void:
	host.set_meta("wood_axis",Vector3.BACK)
	var half:=.09
	var top:=.19 # Add thickness above the mating floor; do not scale the pocket.
	var floor: float=-.060 if option=="A" else 0.0
	var mouth: float=.58 if option=="B" else .364
	host.set_meta("mating_dimensions",{"kind":"notch","width":mouth,"depth":half+floor,"offset":0.0,"stock":top+half})
	# Carved continuous profile with small eased outer and notch edges. These
	# are actual faces, not a normal-map line or a superimposed slot marker.
	var bevel:=.008
	var polygon:=PackedVector2Array([
		Vector2(top,-.6+bevel),Vector2(top-bevel,-.6),
		Vector2(-half+bevel,-.6),Vector2(-half,-.6+bevel),
		Vector2(-half,-mouth*.5-bevel),Vector2(-half+bevel,-mouth*.5),
		Vector2(floor-bevel,-mouth*.5),Vector2(floor,-mouth*.5+bevel),
		Vector2(floor,mouth*.5-bevel),Vector2(floor-bevel,mouth*.5),
		Vector2(-half+bevel,mouth*.5),Vector2(-half,mouth*.5+bevel),
		Vector2(-half,.6-bevel),Vector2(-half+bevel,.6),
		Vector2(top-bevel,.6),Vector2(top,.6-bevel)])
	section(host,polygon,-.14,.14,material)
