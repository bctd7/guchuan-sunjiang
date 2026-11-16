extends SceneTree
const Current=preload("res://models/ship/hull/ship_geometry.gd")
func signature(root: Node3D) -> Array[String]:
	var result: Array[String]=[]
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		for vertex in mesh.mesh.get_faces():result.append(str(vertex))
	result.sort();return result
func _initialize() -> void:
	var previous=GDScript.new();previous.source_code=FileAccess.get_file_as_string("res://tests/evidence/clarity-zoom/previous_ship_geometry.txt");previous.reload()
	var failures: Array[String]=[];var cases:=0
	for index in 3:
		for offset in [-.1,0.0,.1]:
			var before:=Node3D.new();var after:=Node3D.new();previous.three_member(before,index,previous.material(Color.WHITE),offset);Current.three_member(after,index,Current.material(Color.WHITE),offset)
			if signature(before)!=signature(after):failures.append(str([index,offset]))
			before.free();after.free();cases+=1
	var report={"cases":cases,"failed":failures.size(),"failures":failures,"method":"Sorted actual triangle-vertex multisets before/after winding correction; all three arms and opening offsets -0.1/0/0.1. Does not compare lighting normals."}
	FileAccess.open("res://tests/evidence/clarity-zoom/geometry_equivalence.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("GEOMETRY_EQUIVALENCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
