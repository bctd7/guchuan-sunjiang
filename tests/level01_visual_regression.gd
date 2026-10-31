extends SceneTree
## Render-only fixture: own SubViewport, NO_FOCUS host, offscreen launch required.
const OUTPUT := "res://tests/evidence/latest-level01/"
const OLD_GEOMETRY := "C:/Users/27902/Documents/Codex/2026-10-27/task/evidence/before-fixed-keel/levels/level01/ship_geometry.gd"
var level: Node3D
var surface: SubViewport
var passed := 0
var failures: Array[String]=[]
var images: Array[String]=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1
	else:
		failures.append(message)
		push_error(message)
func collect_boxes(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh:
		boxes.append(node.global_transform*node.mesh.get_aabb())
	for child in node.get_children(): collect_boxes(child,boxes)
func inside(boxes: Array[AABB], point: Vector3) -> bool:
	for box in boxes:
		if box.has_point(point): return true
	return false
func verify_union() -> void:
	var old=load(OLD_GEOMETRY).new(level.view._wood,level.view._wood_light,level.view._endgrain)
	var host:=Node3D.new()
	surface.add_child(host)
	old.build(host,"keel")
	var before: Array[AABB]=[]
	var after: Array[AABB]=[]
	collect_boxes(host,before)
	collect_boxes(level.view.pieces.keel,after)
	var coordinates: Array=[[],[],[]]
	for box in before+after:
		for axis in 3:
			for value in [box.position[axis],box.end[axis]]:
				var key=snappedf(value,.00001)
				if not key in coordinates[axis]: coordinates[axis].append(key)
	for values in coordinates: values.sort()
	var cells:=0
	var differences:=0
	for x in coordinates[0].size()-1:
		for y in coordinates[1].size()-1:
			for z in coordinates[2].size()-1:
				var point:=Vector3((coordinates[0][x]+coordinates[0][x+1])/2,(coordinates[1][y]+coordinates[1][y+1])/2,(coordinates[2][z]+coordinates[2][z+1])/2)
				cells+=1
				if inside(before,point)!=inside(after,point): differences+=1
	check(differences==0,"keel box solid union unchanged across all "+str(cells)+" boundary cells")
	var lid_count:=0
	for box in after:
		if is_equal_approx(box.end.y,.72) and box.has_point(Vector3(0,.719,0)): lid_count+=1
	check(lid_count==1,"central strip has one exposed top surface, no coplanar overlapping web")
	print("KEEL_UNION_CELLS ",cells," differences=",differences," top_surface_owners=",lid_count)
	host.free()
func verify_tenons() -> void:
	for id in level.Rules.RIB_IDS:
		var tip: MeshInstance3D=level.view.pieces[id].find_child("RootTenon",true,false)
		var material: StandardMaterial3D=tip.material_override
		check(tip.mesh is BoxMesh and tip.mesh.get_faces().size()==36,"closed six-sided solid tenon: "+id)
		check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a==1,"opaque actual tenon material: "+id)
		check(material.albedo_color.get_luminance()<level.view._wood_light.albedo_color.get_luminance(),"deeper tenon tone than rib stock: "+id)
		var boundary: float=absf(tip.position.x)-tip.mesh.size.x/2
		check(is_equal_approx(boundary-.10,.03),"real blind bottom clearance stays 0.03, no penetration: "+id)
		check(tip.position.y-tip.mesh.size.y/2>.22 and tip.position.y+tip.mesh.size.y/2<.54,"tenon stays inside actual vertical slot clearance: "+id)
	var beam: MeshInstance3D=level.view.pieces.beam1.get_child(0)
	check(beam.mesh.get_aabb().size.x/2>2.78+.38/2,"actual through beam protrudes beyond outer rib surface")
func capture(label: String) -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels=surface.get_texture().get_image()
	check(not pixels.is_empty() and pixels.get_width()==1440 and pixels.get_height()==900,"rendered image has expected dimensions: "+label)
	var file:=OUTPUT+label+".png"
	check(pixels.save_png(file)==OK,"saved real renderer pixels: "+label)
	images.append(file)
func angle(yaw: float, pitch: float) -> void:
	level.inspector.orbit.angles=Vector2(deg_to_rad(yaw),deg_to_rad(pitch))
	level.inspector.orbit.target_angles=level.inspector.orbit.angles
	level.inspector.orbit._apply_camera()
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Actual render fixture requires the no-focus offscreen GPU runner.")
		quit(2)
		return
	check(root.get_flag(Window.FLAG_NO_FOCUS),"host window created with no-focus flag")
	check(not root.has_focus(),"renderer does not hold desktop keyboard focus")
	if not root.get_flag(Window.FLAG_NO_FOCUS):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	surface=SubViewport.new()
	surface.size=Vector2i(1440,900)
	surface.own_world_3d=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	level=load("res://levels/level01/level01.tscn").instantiate()
	surface.add_child(level)
	level.learning.start_button.pressed.emit()
	await process_frame
	verify_union()
	verify_tenons()
	await capture("01-fixed-keel-single-entry")
	level.inspector.show_connection("rib_l1","correct",false,"")
	check(not level.inspector.animated_piece.find_child("RootTenon",true,false).visible,"initial observation shows no implied selected tenon")
	await capture("02-no-default-no-lengths")
	level.inspector.show_connection("rib_l1","correct",false,"blind_tenon")
	var tip: MeshInstance3D=level.inspector.animated_piece.find_child("RootTenon",true,false)
	var new_material=tip.material_override
	tip.material_override=level.view._wood.duplicate()
	await capture("03-before-tenon-tone")
	tip.material_override=new_material
	await capture("04-opaque-deeper-tenon")
	for pose in [Vector2(-30,-18),Vector2(-15,12),Vector2(0,0),Vector2(15,-12),Vector2(30,18)]:
		angle(pose.x,pose.y)
		await capture("05-keel-angle-"+str(pose.x)+"-"+str(pose.y))
	level.inspector.xray_button.set_pressed(true)
	check(tip.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"active tenon remains opaque in cutaway")
	check(level.inspector.pieces.keel.find_child("BlindSlotWeb",true,false).material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"real blind bottom stays opaque in cutaway")
	await capture("06-blind-bottom-cutaway")
	level.inspector.close()
	level.inspector.show_connection("beam1","correct",false,"through_tenon")
	level.inspector.xray_button.set_pressed(true)
	await capture("07-through-hole-exits")
	level.inspector.show_connection("beam1","correct",true,"through_tenon")
	await create_timer(2.4).timeout
	level.inspector.xray_button.set_pressed(true)
	check(level.inspector.animation_finished,"actual through member reaches its seated pose")
	await capture("08-through-seated-both-exits")
	# Render-only detail of the real far exit, without changing ship geometry.
	level.inspector.orbit.configure(level.inspector.camera,Vector3(-2.78,2.34,-2.7),Vector3(-4,2.4,5),true)
	level.inspector.camera.size=2.2
	await capture("09-through-real-back-exit-detail")
	level.inspector.close()
	# Expected final-frame rendering; gameplay is separately tested via GUI events.
	for representative in level.Rules.REPRESENTATIVE_IDS:
		level.state.attempt_place(representative,representative,level.Rules.expected_joint(representative))
		for id in level.Rules.AUTO_GROUPS[representative]: level.state.place_automatic(id)
		level.state.finish_automatic()
	level.state.validate_structure()
	level.view.show_overview(true)
	level.panel.success_panel.hide()
	check(level.state.placed.size()==11 and level.state.automatic_count()==7,"final rendered skeleton retains all eleven real members")
	await capture("10-complete-unobstructed-symmetry")
	check(not root.has_focus(),"render host still does not hold desktop keyboard focus")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"window_position":str(root.position),"method":"Actual GPU rendering into a dedicated offscreen SubViewport; hidden NO_FOCUS host. No desktop input."}
	FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LEVEL01 VISUAL ",JSON.stringify(report))
	surface.free()
	quit(0 if failures.is_empty() else 1)
