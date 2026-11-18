extends RefCounted
## Static internal framing of the teaching hull section, in the same shell coordinates.
## No chapter IDs, progress, installation rules or historical reconstruction claim.
const FIT_CLEARANCE:=.003
const G=preload("res://models/ship/hull/ship_geometry.gd")
static func inner_side(height: float,station:=0.0) -> float:
	var low: float=-.4;var high: float=2.5
	var pose:=Transform3D(Basis(Vector3.RIGHT,-.95),Vector3(0,.26,.45))
	for i in 24:
		var mid: float=(low+high)*.5
		var p: Vector3=pose*G.Shell.point(Vector3(station,.09,mid))
		if p.y<height:low=mid
		else:high=mid
	return (pose*G.Shell.point(Vector3(station,.09,(low+high)*.5))).z
static func transverse_prism(host: Node3D,station: float,polygon: PackedVector2Array,width: float,material: Material) -> void:
	var section:=Node3D.new();host.add_child(section)
	section.position.x=station;section.rotation.z=PI/2
	G.prism(section,polygon,-width*.5,width*.5,material)
static func rib(host: Node3D,station: float,material: Material) -> void:
	for side in [-1,1]:
		var frame:=Node3D.new();host.add_child(frame)
		frame.position=Vector3(0,.26,side*.45)
		frame.rotation.x=-.95*side
		frame.scale.z=side
		G.Shell.loft(frame,PackedVector2Array([Vector2(.094,-.12),Vector2(.214,-.12),Vector2(.214,2.34),Vector2(.094,2.34)]),station-.07,station+.07,material)
	G.box(host,Vector3(.14,.14,.54-2*sin(.95)*G.Shell.sweep(station)),Vector3(station,.235+cos(.95)*G.Shell.sweep(station),0),material)
static func support_bay(host: Node3D,station: float,top: float,material: Material) -> void:
	# Two transverse beams meet the inner planking at their tapered ends.
	# The two longitudinal carlings carry the outer portions of the crossing arms.
	for end in [-1,1]:
		var x: float=station+end
		rib(host,x,material)
		var polygon:=PackedVector2Array([
			Vector2(top-.14,-inner_side(top-.14,x)+.12),
			Vector2(top,-inner_side(top,x)+.12),
			Vector2(top,inner_side(top,x)-.12),
			Vector2(top-.14,inner_side(top-.14,x)-.12)])
		transverse_prism(host,x,polygon,.20,material)
	for side in [-1,1]:
		G.box(host,Vector3(1.8,.14,.14),Vector3(station,top-.07,side*.72),material)
