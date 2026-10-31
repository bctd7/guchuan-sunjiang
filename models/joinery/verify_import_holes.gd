extends SceneTree
func count_hits(path: String, origin: Vector3, end: Vector3) -> int:
	var mesh: Mesh = load(path)
	var vertices := mesh.get_faces()
	var hits := 0
	for i in range(0, vertices.size(), 3):
		if Geometry3D.segment_intersects_triangle(origin, end, vertices[i], vertices[i+1], vertices[i+2]) != null:
			hits += 1
	return hits
func _initialize() -> void:
	var through_clear := count_hits("res://models/joinery/assets/through_tenon_post.obj", Vector3(-2,0,0), Vector3(2,0,0))
	var through_wood := count_hits("res://models/joinery/assets/through_tenon_post.obj", Vector3(-2,0.8,0), Vector3(2,0.8,0))
	var blind_wall := count_hits("res://models/joinery/assets/blind_tenon_post.obj", Vector3(-2,0,0), Vector3(2,0,0))
	var l_small_clear := count_hits("res://models/joinery/assets/l_through_post.obj", Vector3(-2,-0.18,0), Vector3(2,-0.18,0))
	var l_shoulder := count_hits("res://models/joinery/assets/l_through_post.obj", Vector3(-2,0.15,0), Vector3(2,0.15,0))
	var passed := through_clear == 0 and through_wood >= 2 and blind_wall >= 2 and l_small_clear == 0 and l_shoulder >= 2
	var report := {"passed":passed, "through_center_hits":through_clear, "through_wood_hits":through_wood, "blind_wall_hits":blind_wall, "l_small_exit_hits":l_small_clear, "l_shoulder_hits":l_shoulder}
	var f := FileAccess.open("res://models/joinery/godot_hole_regression.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print("GODOT IMPORT HOLE REGRESSION: ", report)
	quit(0 if passed else 1)
