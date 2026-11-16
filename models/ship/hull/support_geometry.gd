extends RefCounted
## Static internal framing of the teaching hull section, in the same shell coordinates.
## No chapter IDs, progress, installation rules or historical reconstruction claim.
const FIT_CLEARANCE:=.003
const G=preload("res://models/ship/hull/ship_geometry.gd")
static func inner_side(height: float) -> float:
	return .45+(height-.26)/tan(.95)-.09/sin(.95)
static func transverse_prism(host: Node3D,station: float,polygon: PackedVector2Array,width: float,material: Material) -> void:
	var section:=Node3D.new();host.add_child(section)
	section.position.x=station;section.rotation.z=PI/2
	G.prism(section,polygon,-width*.5,width*.5,material)
static func rib(host: Node3D,station: float,material: Material) -> void:
	for sign_value in [-1,1]:
		var polygon:=PackedVector2Array([
			Vector2(.165,sign_value*(inner_side(.165)-FIT_CLEARANCE)),
			Vector2(2.17,sign_value*(inner_side(2.17)-FIT_CLEARANCE)),
			Vector2(2.17,sign_value*(inner_side(2.17)-.12)),
			Vector2(.165,sign_value*(inner_side(.165)-.12))])
		transverse_prism(host,station,polygon,.14,material)
	G.box(host,Vector3(.14,.14,.54),Vector3(station,.235,0),material)
static func support_bay(host: Node3D,station: float,top: float,material: Material) -> void:
	# Two transverse beams meet the inner planking at their tapered ends.
	# The two longitudinal carlings carry the outer portions of the crossing arms.
	for end in [-1,1]:
		var x: float=station+end
		rib(host,x,material)
		var polygon:=PackedVector2Array([
			Vector2(top-.14,-inner_side(top-.14)+.12),
			Vector2(top,-inner_side(top)+.12),
			Vector2(top,inner_side(top)-.12),
			Vector2(top-.14,inner_side(top-.14)-.12)])
		transverse_prism(host,x,polygon,.20,material)
	for side in [-1,1]:
		G.box(host,Vector3(1.8,.14,.14),Vector3(station,top-.07,side*.72),material)
