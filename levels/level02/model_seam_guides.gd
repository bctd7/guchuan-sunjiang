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
	var signature:=Vector2(seam,row)
	if marker.get_meta("curve_signature",Vector2.INF)==signature:return
	marker.set_meta("curve_signature",signature)
	for child in marker.get_children():marker.remove_child(child);child.queue_free()
	var material=G.material(Color("b88435") if id=="current" else Color("3d8288"))
	G.Shell.loft(marker,PackedVector2Array([Vector2(-.125,row*.78+.075),Vector2(-.100,row*.78+.075),Vector2(-.100,row*.78+.705),Vector2(-.125,row*.78+.705)]),seam-.0175,seam+.0175,material)
