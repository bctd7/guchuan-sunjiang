extends SceneTree
const G=preload("res://models/ship/hull/ship_geometry.gd")
var passed:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if ok:passed+=1
	else:failures.append(message);push_error(message)
func _initialize() -> void:
	var node:=Node3D.new();root.add_child(node)
	for index in 3:G.three_member(node,index,G.material(Color.WHITE),.1)
	for mesh in node.get_children():
		var arrays=mesh.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
		var bounds: AABB=mesh.mesh.get_aabb()
		for i in vertices.size():
			if absf(normals[i].y)>.99:
				check(normals[i].y>0 if is_equal_approx(vertices[i].y,bounds.end.y) else normals[i].y<0,"extruded timber cut faces have outward lighting normals")
	node.free();print("HULL_WOOD_NORMALS ",passed," passed / ",failures.size()," failed");quit(0 if failures.is_empty() else 1)
