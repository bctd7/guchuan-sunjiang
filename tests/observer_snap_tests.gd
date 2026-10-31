extends SceneTree
## Isolated acceptance fixture: every pointer goes through Viewport.push_input.
const Surface = preload("res://levels/level01/assembly_drag_surface.gd")
var surface: Control
var part: Node3D
var stage: Control
var camera: Camera3D
var initial := Transform3D(Basis.IDENTITY, Vector3(1.25, 0, 0))
var seated := Transform3D(Basis.IDENTITY, Vector3(-0.75, 0, 0))
var passed := 0
var failures: Array[String] = []
var requests := 0
var selection_prompts := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func mouse(point: Vector2, down: bool, device := 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	event.device = device
	root.push_input(event, true)
	await process_frame

func move(point: Vector2, relative: Vector2, device := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.device = device
	root.push_input(event, true)
	await process_frame

func touch(point: Vector2, down: bool, index := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = down
	event.index = index
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame

func swipe(point: Vector2, relative: Vector2, index := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.relative = relative
	event.index = index
	root.push_input(event, true)
	await process_frame

func start() -> Vector2: return surface.get_global_transform_with_canvas() * surface.drag_start_screen()
func target() -> Vector2: return surface.get_global_transform_with_canvas() * surface.target_screen()

func reset_fixture(enabled := true) -> void:
	surface.cancel()
	part.transform = initial
	surface.configure(camera, Vector3.ZERO, Vector3(0, 0, 8), true)
	surface.configure_assembly(part, seated, Vector3.ZERO, enabled)
	await process_frame

func run() -> void:
	root.size = Vector2i(1000, 700)
	stage = Control.new()
	stage.position = Vector2(90, 70)
	stage.size = Vector2(600, 400)
	root.add_child(stage)
	var container := SubViewportContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	container.stretch_shrink = 2
	container.size = stage.size
	stage.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 600)
	viewport.own_world_3d = true
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	world.add_child(camera)
	part = Node3D.new()
	world.add_child(part)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(0.6, 0.5, 0.5)
	part.add_child(mesh)
	surface = Surface.new()
	stage.add_child(surface)
	surface.assembly_requested.connect(func(): requests += 1)
	surface.selection_required.connect(func(): selection_prompts += 1)
	await process_frame
	await reset_fixture()
	var a := start()
	var b := target()
	var path := b - a
	check(surface.size == stage.size, "sibling overlay fills actual displayed stage")
	check(Vector2(viewport.size).is_equal_approx(stage.size / 2.0), "fixture renders stretched viewport at half overlay resolution")
	check(a.distance_to(b) > 100 and surface.get_global_rect().has_point(a), "projected grab and slot use scaled camera viewport and overlay offset")
	var original_camera := camera.transform
	await mouse(a, true)
	check(surface.assembly_dragging, "real GUI press captures displayed part")
	await mouse(a, false)
	check(requests == 0 and part.transform.is_equal_approx(initial), "click alone restores pose without inserting")
	await mouse(a, true)
	await mouse(b, false)
	check(requests == 0 and part.transform.is_equal_approx(initial), "release position alone cannot impersonate held movement")
	await mouse(a, true)
	await move(a + path * 0.5, path * 0.5)
	check(part.position.distance_to(initial.origin) > 0.5 and surface.drag_progress > 0.45, "held GUI stroke genuinely moves part on insertion path")
	check(camera.transform.is_equal_approx(original_camera), "part drag keeps inspection camera fixed")
	await mouse(a + path * 0.5, false)
	check(requests == 0 and part.transform.is_equal_approx(initial), "release before eighty percent returns original transform")
	await mouse(a, true)
	await move(a + path * 0.85, path * 0.85)
	check(requests == 0, "reaching socket while still held cannot request assembly")
	await mouse(a + path * 0.85, false)
	check(requests == 1 and part.transform.is_equal_approx(initial), "release beyond eighty percent emits once after restoring preview")
	await mouse(b, false)
	check(requests == 1, "duplicate mouse release cannot insert again")
	await mouse(a, true)
	await move(b + Vector2(0, 100), path + Vector2(0, 100))
	await mouse(b + Vector2(0, 100), false)
	check(requests == 1 and part.transform.is_equal_approx(initial), "off-axis release rejects and restores")
	await mouse(a, true)
	await move(b, path)
	await mouse(Vector2(990, 690), false)
	check(requests == 1 and not surface.assembly_dragging and part.transform.is_equal_approx(initial), "outside release cannot reuse successful preview")
	await mouse(a, true)
	await move(b, path)
	surface.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await mouse(b, false)
	check(requests == 1 and part.transform.is_equal_approx(initial), "focus loss immediately restores held candidate")
	await mouse(a, true)
	await move(b, path)
	surface.configure_assembly(part, seated, Vector3.ZERO, true)
	await mouse(b, false)
	check(requests == 1 and part.transform.is_equal_approx(initial), "new candidate configuration cancels pending request")
	await reset_fixture(false)
	a = start()
	b = target()
	await mouse(a, true)
	await move(b, b - a)
	await mouse(b, false)
	check(requests == 1 and part.transform.is_equal_approx(initial), "missing explicit type or length disables assembly")
	check(surface.target_angles == Vector2.ZERO and selection_prompts == 1 and not surface.assembly_dragging, "unselected reference part locks gesture and prompts once without orbit")
	var disabled_blank := stage.position + Vector2(40, 40)
	await mouse(disabled_blank, true)
	await move(disabled_blank + Vector2(55, 25), Vector2(55, 25))
	await mouse(disabled_blank + Vector2(55, 25), false)
	check(surface.target_angles != Vector2.ZERO and selection_prompts == 1 and requests == 1, "unselected reference still permits orbit from actual blank area")
	await reset_fixture()
	var blank := stage.position + Vector2(40, 40)
	await mouse(blank, true)
	await move(blank + Vector2(55, 25), Vector2(55, 25))
	await mouse(blank + Vector2(55, 25), false)
	check(surface.target_angles.x < 0 and surface.target_angles.y < 0 and requests == 1, "blank stage retains bounded orbit gesture")
	await reset_fixture()
	a = start()
	b = target()
	await touch(a, true, 1)
	await swipe(b, b - a, 1)
	check(not part.transform.is_equal_approx(initial), "real touch drag previews real part movement")
	await touch(b, false, 1, true)
	check(requests == 1 and part.transform.is_equal_approx(initial), "canceled touch never assembles and restores")
	await touch(a, true, 2)
	await swipe(b, b - a, 2)
	await touch(b, false, 2)
	check(requests == 2 and part.transform.is_equal_approx(initial), "single touch release requests exactly once")
	await mouse(a, true, InputEvent.DEVICE_ID_EMULATION)
	await move(b, b - a, InputEvent.DEVICE_ID_EMULATION)
	await mouse(b, false, InputEvent.DEVICE_ID_EMULATION)
	check(requests == 2, "synthesized mouse after touch cannot duplicate insertion")
	await touch(a, true, 3)
	await swipe(b, b - a, 3)
	await touch(a + Vector2(15, 15), true, 4)
	check(not surface.assembly_dragging and part.transform.is_equal_approx(initial), "second finger cancels current preview")
	await swipe(b, b - a, 4)
	await touch(b, false, 4)
	await touch(b, false, 3)
	check(requests == 2, "multitouch release cannot request assembly")
	await touch(a, true, 5)
	await swipe(b, b - a, 5)
	surface.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await touch(b, false, 5)
	check(requests == 2 and part.transform.is_equal_approx(initial), "touch focus loss restores preview without insertion")
	await touch(a, true, 6)
	await swipe(b, b - a, 6)
	await touch(b, false, 6)
	check(requests == 3, "rejected or canceled attempts remain reusable for next stroke")
	await touch(a, true, 7)
	await swipe(b, b - a, 7)
	stage.hide()
	await touch(b, false, 7)
	check(requests == 3 and part.transform.is_equal_approx(initial), "hiding observer cancels preview")
	stage.show()
	await reset_fixture()
	a = start()
	b = target()
	await touch(a, true, 8)
	await swipe(b, b - a, 8)
	surface.deactivate()
	await touch(b, false, 8)
	check(requests == 3 and part.transform.is_equal_approx(initial) and not surface.active, "mode exit deactivates and restores candidate")
	await reset_fixture()
	a = start()
	b = target()
	await touch(a, true, 9)
	await swipe(b, b - a, 9)
	await touch(b, false, 9)
	check(requests == 4, "reopen after deactivation accepts a fresh single touch")
	surface.preview_limit=.1
	await touch(a,true,10)
	await swipe(b,b-a,10)
	check(part.transform.is_equal_approx(initial.interpolate_with(seated,.1)),"incompatible preview stops outside mouth while pointer reaches target")
	await touch(b,false,10)
	check(requests==5 and part.transform.is_equal_approx(initial),"blocked candidate still delegates one rejection decision without remaining seated")
	await picking_regressions(mesh, world)
	await unselected_regressions()
	print("OBSERVER SNAP: %d passed, %d failed; real Viewport.push_input GUI events; display=%s" % [passed, failures.size(), DisplayServer.get_name()])
	stage.free()
	quit(0 if failures.is_empty() else 1)

# Picking acceptance is also exercised through the GUI; no direct _gui_input calls.
func picking_regressions(mesh: MeshInstance3D, world: Node3D) -> void:
	await create_timer(0.46).timeout
	surface.preview_limit = 1.0
	var before := requests
	mesh.mesh.size = Vector3(4.4, 0.5, 0.5)
	await reset_fixture()
	var a := start()
	var path := target() - a
	var body: Vector2 = surface.get_global_transform_with_canvas() * surface._project(part.to_global(Vector3(-1.6, 0, 0)))
	check(body.distance_to(a) > 86.0, "long beam fixture exercises actual body outside former shoulder cutoff")
	var original_camera := camera.transform
	await mouse(body, true)
	check(surface.assembly_dragging, "visible long beam body farther than 86 pixels captures part")
	await move(body + path * 0.5 + Vector2(0, 110), path * 0.5 + Vector2(0, 110))
	check(surface.assembly_dragging and not part.transform.is_equal_approx(initial) and camera.transform.is_equal_approx(original_camera), "part press stays part gesture after pointer leaves its visible mesh")
	await mouse(body + path * 0.5 + Vector2(0, 110), false)
	check(requests == before, "wider body picking does not enlarge socket acceptance tolerance")
	await reset_fixture()
	a = start()
	var blank := stage.position + Vector2(40, 40)
	await mouse(blank, true)
	await move(a, a - blank)
	check(not surface.assembly_dragging and part.transform.is_equal_approx(initial) and surface.target_angles != Vector2.ZERO, "blank press stays orbit when pointer crosses visible part")
	await mouse(a, false)
	await reset_fixture()
	a = start()
	body = surface.get_global_transform_with_canvas() * surface._project(part.to_global(Vector3(-1.6, 0, 0)))
	await touch(body, true, 20)
	await swipe(body + path * 0.5 + Vector2(0, 110), path * 0.5 + Vector2(0, 110), 20)
	check(surface.assembly_dragging and surface.target_angles == Vector2.ZERO, "touch long beam body retains part lock outside mesh")
	await touch(body, false, 20, true)
	await reset_fixture()
	a = start()
	await touch(blank, true, 21)
	await swipe(a, a - blank, 21)
	check(not surface.assembly_dragging and part.transform.is_equal_approx(initial) and surface.target_angles != Vector2.ZERO, "touch blank gesture remains orbit across part")
	await touch(a, false, 21)
	mesh.mesh.size = Vector3(0.6, 0.5, 0.5)
	# Four bars enclose a real empty aperture. Its center is also the grab-point
	# marker, proving that neither the marker radius nor an AABB fills the hole.
	mesh.hide()
	var ring := Node3D.new()
	part.add_child(ring)
	for spec in [Vector3(-0.7, 0, 0), Vector3(0.7, 0, 0), Vector3(0, -0.7, 0), Vector3(0, 0.7, 0)]:
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.mesh.size = Vector3(0.2, 1.6, 0.2) if spec.x != 0 else Vector3(1.2, 0.2, 0.2)
		bar.position = spec
		ring.add_child(bar)
	await reset_fixture()
	a = start()
	await touch(a, true, 22)
	check(not surface.assembly_dragging, "real aperture at grab marker remains empty rather than AABB hit")
	await swipe(a + Vector2(20, 0), Vector2(20, 0), 22)
	check(surface.target_angles.x < 0 and part.transform.is_equal_approx(initial), "hole press rotates camera")
	await touch(a, false, 22)
	ring.free()
	mesh.show()
	var receiver := MeshInstance3D.new()
	receiver.mesh = BoxMesh.new()
	receiver.mesh.size = Vector3(0.8, 0.8, 0.3)
	receiver.position = initial.origin + Vector3(0, 0, 0.7)
	world.add_child(receiver)
	await reset_fixture()
	a = start()
	await touch(a, true, 23)
	check(not surface.assembly_dragging, "opaque receiver in front prevents grabbing hidden candidate")
	await touch(a, false, 23)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.24
	receiver.material_override = material
	await reset_fixture()
	a = start()
	await touch(a, true, 24)
	check(surface.assembly_dragging, "transparent cutaway receiver permits grabbing visible candidate behind")
	await touch(a, false, 24, true)
	receiver.free()
	await reset_fixture()
	a = start()
	# A genuine overlay button wins GUI targeting over the inspection surface.
	var button := Button.new()
	button.position = surface.drag_start_screen() - Vector2(30, 20)
	button.size = Vector2(60, 40)
	stage.add_child(button)
	var clicks := [0]
	button.pressed.connect(func(): clicks[0] += 1)
	await process_frame
	await touch(a, true, 25)
	await swipe(a + Vector2(15, 0), Vector2(15, 0), 25)
	check(not surface.assembly_dragging and surface.target_angles == Vector2.ZERO and part.transform.is_equal_approx(initial), "GUI button blocks touch press and drag from underlying scene")
	await touch(a, false, 25)
	await create_timer(0.46).timeout
	await mouse(a, true)
	await mouse(a, false)
	check(clicks[0] > 0 and not surface.assembly_dragging and surface.target_angles == Vector2.ZERO, "GUI button mouse click does not pass through to part or orbit")
	button.free()
	# A flat clockwise triangle explicitly checks material face culling.
	var old_mesh := mesh.mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.4, -0.4, 0), Vector3(0, 0.4, 0), Vector3(0.4, -0.4, 0)])
	var triangle := ArrayMesh.new()
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = triangle
	material = StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.material_override = material
	await reset_fixture()
	a = start()
	await mouse(a, true)
	check(surface.assembly_dragging, "front-facing actual triangle captures with default backface culling")
	await mouse(a, false)
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	await mouse(a, true)
	check(not surface.assembly_dragging, "culled triangle face cannot grab invisible geometry")
	await mouse(a, false)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	await mouse(a, true)
	check(surface.assembly_dragging, "double-sided material exposes triangle for picking")
	await mouse(a, false)
	mesh.material_override = null
	mesh.mesh = old_mesh
	await reset_fixture()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	await process_frame
	a = start()
	await mouse(a, true)
	check(surface.assembly_dragging, "ray picking follows perspective camera and scaled viewport")
	await mouse(a, false)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	await reset_fixture()
	a = start()
	mesh.hide()
	await mouse(a, true)
	check(not surface.assembly_dragging, "hidden candidate mesh cannot claim its former screen pixels")
	await mouse(a, false)
	mesh.show()
	mesh.layers = 2
	camera.cull_mask = 1
	await mouse(a, true)
	check(not surface.assembly_dragging, "camera layer filtering also filters pickable mesh")
	await mouse(a, false)
	mesh.layers = 1
	camera.cull_mask = 1048575
	await mouse(a, true)
	await move(a + Vector2(-30, 0), Vector2(-30, 0))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	await move(a + Vector2(-60, 0), Vector2(-30, 0))
	check(not surface.assembly_dragging and part.transform.is_equal_approx(initial) and surface.target_angles == Vector2.ZERO, "Escape cancels both part movement and subsequent stale pointer motion")
	await mouse(a, false)
	await touch(a, true, 26)
	await touch(a, false, 26, true)
	await mouse(a, true)
	await move(target(), target() - a)
	await mouse(target(), false)
	check(not surface.assembly_dragging and surface.target_angles == Vector2.ZERO, "unmarked generated mouse immediately following touch is also suppressed")
	check(requests == before, "picking and camera regression strokes never emit business requests")


func unselected_regressions() -> void:
	await reset_fixture(false)
	var a := start()
	var b := target()
	var before := requests
	var prompts_before := selection_prompts
	var original_camera := camera.transform
	await touch(a, true, 30)
	await swipe(b, b - a, 30)
	await swipe(b + Vector2(0, 100), Vector2(0, 100), 30)
	check(not surface.assembly_dragging and camera.transform.is_equal_approx(original_camera) and surface.target_angles == Vector2.ZERO and part.transform.is_equal_approx(initial), "unselected touch part gesture stays motionless after crossing into blank")
	await touch(b, false, 30)
	check(requests == before and selection_prompts == prompts_before + 1 and not surface.assembly_enabled, "unselected touch emits one selection prompt and never commits or implicitly selects")
	var blank := stage.position + Vector2(40, 40)
	await touch(blank, true, 31)
	await swipe(a, a - blank, 31)
	await touch(a, false, 31)
	check(surface.target_angles != Vector2.ZERO and requests == before and selection_prompts == prompts_before + 1, "unselected blank touch remains orbit after crossing reference part")
	await reset_fixture(false)
	a = start()
	var button := Button.new()
	button.position = surface.drag_start_screen() - Vector2(30, 20)
	button.size = Vector2(60, 40)
	stage.add_child(button)
	var clicks := [0]
	button.pressed.connect(func(): clicks[0] += 1)
	await process_frame
	await touch(a, true, 32)
	await touch(a, false, 32)
	await create_timer(0.46).timeout
	await mouse(a, true)
	await mouse(a, false)
	check(clicks[0] > 0 and selection_prompts == prompts_before + 1 and surface.target_angles == Vector2.ZERO and requests == before and not surface.assembly_enabled, "unselected reference UI button consumes mouse and touch without prompt or installation")
	button.free()
