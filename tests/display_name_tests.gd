extends SceneTree
var passed := 0
var failed := 0
const NAMES := {"blind_tenon":"半榫","through_tenon":"透榫","dovetail":"燕尾榫","cross_lap":"搭扣榫","tongue_groove":"企口榫","three_way_lap":"扣合榫","zong_corner":"粽角榫","clamp_head":"夹头榫","l_through":"穿榫"}
func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var demo = load("res://components/teaching/classroom/classroom.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	for index in demo.catalog.size():
		demo.picker.select(index)
		demo.load_joint(index)
		await process_frame
		var id := str(demo.catalog[index].id)
		var expected: String = NAMES[id]
		check(demo.catalog[index].name == expected,id+": catalog display name")
		check(demo.picker.get_item_text(index) == expected,id+": selection label")
		check(demo.workshop_panel.picker.get_item_text(index) == expected,id+": unified panel name")
		check(demo.science_entry.text == expected+"受力演示",id+": education entry")
		check(demo.assembly.definition.id == id,id+": internal routing preserved")
		if DisplayServer.get_name() != "headless" and id in ["three_way_lap","l_through"]:
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://.display-names-20261023/"+id+".png") == OK,id+": actual title/menu/entry screenshot")
		demo._open_education()
		check(demo.dynamic_science.opened if id == "dovetail" else demo.force_gallery.opened,id+": correct education route")
		if id != "dovetail":check(demo.force_gallery.joint_id == id,id+": gallery ID preserved")
		if id == "l_through":
			check(str(demo.catalog[index].variant).contains("L型") and str(demo.catalog[index].variant).contains("未加木楔"),"exact L variant fact retained in metadata")
			check(not demo.status.text.contains("L型") and not demo.status.text.contains("L 型"),"part hint avoids prefixed L display")
	demo.free()
	print("DISPLAY NAME UI/ROUTING: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
