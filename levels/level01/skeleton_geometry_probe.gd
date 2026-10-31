extends SceneTree
## Independent rendering/target diagnostic for the level's view-only geometry.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440,900)
	var view = load("res://levels/level01/skeleton_view.gd").new()
	root.add_child(view)
	await process_frame
	check_generated_geometry(view)
	var placed: Dictionary = {}
	for id in view.IDS: placed[id] = {"length":"correct"}
	view.sync_state(placed,"complete","")
	for frame in 5: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/evidence/level01-skeleton-overview.png")
	view.show_overview(true)
	for frame in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/evidence/level01-skeleton-plan.png")
	view.show_overview()
	view.sync_state({"keel":{"length":"correct"}},"ribs","rib_l1")
	for id in view.Rules.REPRESENTATIVE_IDS:
		view.sync_state({"keel":{"length":"correct"}},view.Rules.stage_for(id),id)
		var point: Vector2 = view.socket_screen_position(id)
		assert(view.pick_socket(point) == id, "Socket collision: " + id)
		assert(point.x > 330 and point.x < 1440 and point.y > 130 and point.y < 770, "Socket outside playable area: " + id + " " + str(point))
		print("SOCKET ", id, " ", point)
	view.focus_socket("rib_r1")
	for frame in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/evidence/level01-skeleton-blind-slot.png")
	print("SKELETON_GEOMETRY_PROBE PASS: 11 physical parts, three representative targets; automatic repeats have no target")
	quit()

func check_generated_geometry(view: Node3D) -> void:
	var keel_faces := faces(view.pieces.keel)
	for station in [-2.7,0.0,2.7]:
		for side in [-1.0,1.0]:
			assert(hits(keel_faces,Vector3(side*.54,.38,station),Vector3(side*.11,.38,station)) == 0,"Blind mortise must be genuinely empty")
		assert(hits(keel_faces,Vector3(.12,.38,station),Vector3(-.12,.38,station)) >= 2,"Opposing mortises need solid central web")
		assert(hits(keel_faces,Vector3(.30,.38,station),Vector3(.30,.70,station)) > 0,"Mortise needs roof")
		assert(hits(keel_faces,Vector3(.30,.38,station),Vector3(.30,.10,station)) > 0,"Mortise needs floor")
	for index in range(1,4):
		var left := vertex_keys(faces(view.pieces["rib_l%d" % index]),true)
		var right := vertex_keys(faces(view.pieces["rib_r%d" % index]),false)
		assert(left == right,"Ribs must mirror actual generated geometry")
		var rib_faces := faces(view.pieces["rib_r%d" % index])
		var station: float = [-2.7,0.0,2.7][index-1]
		# Shoulder has material throughout the tenon's vertical range.
		for height in [.26,.38,.50]:
			assert(hits(rib_faces,Vector3(.56,height,station-.5),Vector3(.56,height,station+.5)) > 0,"Root shoulder must contain the tenon's full height")
	for index in [1,3]:
		var station: float = -2.7 if index == 1 else 2.7
		var receivers: PackedVector3Array = faces(view.pieces["rib_l%d" % index])
		receivers.append_array(faces(view.pieces["rib_r%d" % index]))
		assert(hits(receivers,Vector3(-3.2,2.34,station),Vector3(3.2,2.34,station)) == 0,"Through mortises must be open along X")
		assert(hits(receivers,Vector3(-3.2,2.34,station+.205),Vector3(3.2,2.34,station+.205)) > 0,"Through hole requires intact side walls")
		for vertex in faces(view.pieces["beam%d" % index]):
			assert(hits(receivers,vertex+Vector3(6.6,0,0),vertex,true) == 0,"Uniform beam must pass through both holes")
	for id in ["bow","stern"]:
		var direction := -1.0 if id == "bow" else 1.0
		for vertex in faces(view.pieces[id]):
			assert(hits(keel_faces,vertex+Vector3(0,0,direction*1.8),vertex,true) == 0,"Dovetail must slide through the open end without crossing solid wood")
	for id in ["rib_l1","rib_r1"]:
		for variant in ["correct"]:
			view.apply_length_geometry(view.pieces[id],id,variant)
			var tenon: MeshInstance3D = view.pieces[id].find_child("RootTenon",true,false)
			var vertices := faces(tenon)
			var min_x := INF
			var max_x := -INF
			for vertex in vertices:
				min_x = minf(min_x,vertex.x)
				max_x = maxf(max_x,vertex.x)
			assert(is_equal_approx(max_x-min_x,{"short":.27,"long":.62,"correct":.42}[variant]),"Length variant must change the generated tenon mesh")
			assert(is_equal_approx(-min_x if id == "rib_l1" else max_x,.55),"The shoulder end must remain fixed when changing tenon length")
			var preview_tenon: MeshInstance3D = view.ghosts[id].find_child("RootTenon",true,false)
			assert(is_equal_approx(preview_tenon.mesh.get_aabb().size.x,.42),"Changing one tenon must not resize its ghost")
	print("GENERATED_GEOMETRY PASS: six blind slots, intact center, mirrored ribs, root shoulders, two through paths, two end-slide paths")

func faces(node: Node3D, parent_transform: Transform3D = Transform3D.IDENTITY) -> PackedVector3Array:
	var result := PackedVector3Array()
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		for vertex in node.mesh.get_faces(): result.append(transform*vertex)
	for child in node.get_children():
		if child is Node3D: result.append_array(faces(child,transform))
	return result

func hits(triangles: PackedVector3Array, start: Vector3, finish: Vector3, ignore_endpoints: bool = false) -> int:
	var count := 0
	for index in range(0,triangles.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,triangles[index],triangles[index+1],triangles[index+2])
		if hit == null: continue
		if ignore_endpoints and ((hit as Vector3).distance_to(start) < .0001 or (hit as Vector3).distance_to(finish) < .0001): continue
		count += 1
	return count

func vertex_keys(vertices: PackedVector3Array, mirror: bool) -> Array[String]:
	var unique: Dictionary = {}
	for vertex in vertices:
		if mirror: vertex.x = -vertex.x
		unique["%d,%d,%d" % [roundi(vertex.x*10000),roundi(vertex.y*10000),roundi(vertex.z*10000)]] = true
	var result: Array[String] = []
	for key in unique: result.append(key)
	result.sort()
	return result
