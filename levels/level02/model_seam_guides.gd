extends Node3D
## Two neutral landmarks attached to the actual current/previous board cuts.
## No acceptance rules or screen-space answer diagram lives here.
const G=preload("res://models/ship/hull/ship_geometry.gd")
var markers: Dictionary={}
func _ready() -> void:
	for id in ["current","previous"]:
		var marker:=Node3D.new()
		add_child(marker)
		markers[id]=marker
		var material=G.material(Color("b88435") if id=="current" else Color("3d8288"))
		G.box(marker,Vector3(.035,.025,.63),Vector3.ZERO,material)
func sync(row: int,seam: float,pose: Transform3D,previous_seam: float,previous_pose: Transform3D,show_previous: bool) -> void:
	_set_marker("current",row,seam,pose,true)
	_set_marker("previous",row-1,previous_seam,previous_pose,show_previous)
func _set_marker(id: String,row: int,seam: float,pose: Transform3D,enabled: bool) -> void:
	var marker: Node3D=markers[id]
	marker.visible=enabled
	if not enabled:return
	marker.transform=pose
	marker.position+=pose.basis*Vector3(seam,-.112,row*.78+.39)
