extends SceneTree
## End-to-end Viewport events: never move or install a real test part through core APIs.
var demo
var passed := 0
var failed := 0
var checkpoints: Array = []

func check(ok: bool,description: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func motion(position: Vector2,relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	root.push_input(event)
	await process_frame

func mouse(position: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)
	await process_frame

func click(position: Vector2) -> void:
	await motion(position)
	await mouse(position,true)
	await mouse(position,false)

func wait_idle() -> bool:
	var deadline := Time.get_ticks_msec()+8000
	while not demo.assembly.moving.is_empty() and Time.get_ticks_msec()<deadline:
		await create_timer(0.02).timeout
	return demo.assembly.moving.is_empty()

func pick_screen(id: String) -> Vector2:
	var part: Node3D = demo.assembly.parts[id]
	var mesh: Mesh = part.get_node("Wood").mesh
	var faces := mesh.get_faces()
	var center: Vector2 = demo.camera.unproject_position(part.global_transform*mesh.get_aabb().get_center())
	var points: Array[Vector2] = []
	for i in range(0,faces.size(),3):
		var world: Vector3 = part.global_transform*((faces[i]+faces[i+1]+faces[i+2])/3.0)
		if demo.camera.is_position_behind(world): continue
		var screen: Vector2 = demo.camera.unproject_position(world)
		if screen.x>380 and screen.x<1420 and screen.y>90 and screen.y<880: points.append(screen)
	points.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(center)<b.distance_squared_to(center))
	for screen in points:
		var origin: Vector3 = demo.camera.project_ray_origin(screen)
		var direction: Vector3 = demo.camera.project_ray_normal(screen)
		var hit: Dictionary = demo.camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*100))
		if not hit.is_empty() and hit.collider == part: return screen
	return Vector2(-1,-1)

func drag(id: String,steps: int,should_install := true) -> bool:
	await physics_frame
	var start := pick_screen(id)
	check(start.x>=0,"visible pick surface: "+id)
	if start.x<0: return false
	await motion(start)
	await mouse(start,true)
	check(demo.interaction.mode=="drag" and demo.interaction.drag_id==id,"real press owns "+id)
	if demo.interaction.mode!="drag": return false
	var entrance: Transform3D = demo.assembly.global_transform*demo.assembly.entrance_pose(id)
	var target: Vector2 = demo.camera.unproject_position(entrance*demo.interaction.grab_local)
	for i in range(1,steps+1):
		await motion(start.lerp(target,float(i)/steps),(target-start)/steps)
	var preview: bool = demo.interaction.capture_latched
	if should_install: check(preview,"legal entrance preview captured: "+id)
	await mouse(target,false)
	var idle: bool = await wait_idle()
	var locked: bool = demo.assembly.states[id]=="locked"
	check(idle and locked==should_install,"release result: "+id+" expected installed="+str(should_install))
	check(demo.interaction.mode=="idle","release relinquishes mouse ownership")
	return locked

func select_in_list(id: String) -> void:
	var index := 0
	for spec in demo.assembly.definition.parts:
		if spec.id==id: break
		index+=1
	await click(demo.part_list.global_position+demo.part_list.get_item_rect(index).get_center())
	check(demo.assembly.selected==id,"UI selection for removal: "+id)

func rotate_button(text_value: String,times: int) -> void:
	for button in demo.find_children("*","Button",true,false):
		if button.text==text_value:
			for i in times: await click(button.get_global_rect().get_center())
			return
	check(false,"rotation button exists: "+text_value)

func carry_to_entry(id: String) -> Vector2:
	await physics_frame
	var start := pick_screen(id)
	await motion(start)
	await mouse(start,true)
	var entrance: Transform3D = demo.assembly.global_transform*demo.assembly.entrance_pose(id)
	var target: Vector2 = demo.camera.unproject_position(entrance*demo.interaction.grab_local)
	for i in range(1,9): await motion(start.lerp(target,float(i)/8),(target-start)/8)
	return target

func assemble_and_remove(steps: int) -> void:
	var installed: Array[String] = []
	for spec in demo.assembly.definition.parts:
		if spec.get("fixed",false): continue
		if await drag(str(spec.id),steps): installed.append(str(spec.id))
	for i in range(installed.size()-1,-1,-1):
		var id := installed[i]
		await select_in_list(id)
		await click(demo.buttons.remove.get_global_rect().get_center())
		check(await wait_idle() and demo.assembly.states[id]=="free","UI removal completes: "+id)

func run() -> void:
	root.size=Vector2i(1440,900)
	demo=load("res://demo/workshop.tscn").instantiate()
	root.add_child(demo)
	await physics_frame
	await process_frame
	for view in [Vector2(.68,.42),Vector2(-.55,.55),Vector2(1.25,.65)]:
		for i in demo.catalog.size():
			demo.interaction.yaw=view.x
			demo.interaction.pitch=view.y
			demo.load_joint(i)
			demo.assembly.insertion_speed=30.0
			await physics_frame
			await process_frame
			await assemble_and_remove(16)
			# Same actual parked parts, no reset or direct pose calls, fast reassembly.
			await assemble_and_remove(1)
			checkpoints.append({"model":demo.catalog[i].id,"view":[view.x,view.y],"completed":true})
			print("INPUT ROUND ",demo.catalog[i].id," view=",view)
	# A legitimate projected entrance can be blocked by a real solid fixture.
	demo.interaction.yaw=.68
	demo.interaction.pitch=.42
	demo.load_joint(0)
	var box := BoxMesh.new()
	box.size=Vector3(3,3,0.04)
	ResourceSaver.save(box,"user://drag_input_wall.tres")
	var blocked: Dictionary = demo.catalog[0].duplicate(true)
	blocked.parts.append({"id":"wall","name":"physical blocker","mesh":"user://drag_input_wall.tres","fixed":true,"assembled_position":[0,0,2.45],"start_position":[0,0,2.45],"insertion_path":[[0,0,2.45]],"dependencies":[]})
	demo.assembly.load_definition(blocked)
	demo.assembly.select_part("tail")
	await physics_frame
	await drag("tail",1,false)
	check(demo.assembly.occupied.get("tail","")=="","screen overlap cannot install through a wall")
	# A click with no drag must not auto-install nearby source material.
	demo.load_joint(0)
	await physics_frame
	await click(pick_screen("tail"))
	check(demo.assembly.states.tail=="free" and demo.assembly.moving.is_empty(),"click alone only selects")
	# Rotation is applied by the real visible UI, not by changing part poses in tests.
	await rotate_button("Y+",1)
	await drag("tail",16)
	check(demo.assembly.parts.tail.basis.is_equal_approx(Basis.IDENTITY),"15 degree error smoothly aligned")
	demo.load_joint(0)
	await rotate_button("Y+",3)
	await drag("tail",16,false)
	check(demo.status.text.contains("旋转"),"large wrong angle has explicit feedback")
	demo.load_joint(0)
	await carry_to_entry("tail")
	check(demo.interaction.capture_latched,"captured before release over UI")
	await motion(Vector2(50,100))
	await mouse(Vector2(50,100),false)
	check(demo.assembly.states.tail=="free" and demo.interaction.mode=="idle","UI release cancels a captured target")
	demo.load_joint(0)
	await rotate_button("Y+",1)
	var target := await carry_to_entry("tail")
	var safe: Transform3D = demo.assembly.parts.tail.transform
	await mouse(target,false)
	await create_timer(0.03).timeout
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	root.push_input(escape)
	await wait_idle()
	check(demo.assembly.states.tail=="free" and demo.assembly.parts.tail.transform.is_equal_approx(safe),"Escape reverses assisted alignment including orientation")
	var report := {"passed":passed,"failed":failed,"checkpoints":checkpoints,"human_mouse_verified":false}
	var file := FileAccess.open("res://tests/drag_input_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	demo.free()
	print("JOINERY INPUT TESTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
