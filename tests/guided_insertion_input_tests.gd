extends "res://tests/observer_snap_tests.gd"
func stroke(a: Vector2,b: Vector2,touching:=false,index:=0) -> void:
	if touching:await touch(a,true,index);await swipe(b,b-a,index);await touch(b,false,index)
	else:await mouse(a,true);await move(b,b-a);await mouse(b,false)
func run() -> void:
	root.size=Vector2i(1100,800)
	stage=Control.new();stage.position=Vector2(120,90);stage.size=Vector2(640,440);root.add_child(stage)
	var container:=SubViewportContainer.new();container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.stretch=true;container.stretch_shrink=2;container.size=stage.size;stage.add_child(container)
	var viewport:=SubViewport.new();viewport.own_world_3d=true;container.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true;world.add_child(camera)
	part=Node3D.new();world.add_child(part)
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=Vector3(.6,.5,.5);part.add_child(mesh)
	surface=Surface.new();stage.add_child(surface)
	surface.assembly_requested.connect(func():requests+=1)
	surface.selection_required.connect(func():selection_prompts+=1)
	await process_frame
	await reset_fixture()
	var a:=start();var direction: Vector2=(target()-a).normalized();var count:=requests
	await mouse(a,true);await move(a+direction*60+Vector2(0,50),direction*60+Vector2(0,50))
	check(is_equal_approx(part.position.y,initial.origin.y),"off-axis hand movement never moves wood off its real insertion path")
	check(surface.drag_progress>.2 and surface.drag_progress<.5,"hand movement proportionally advances insertion")
	var partial: Transform3D=part.transform
	await mouse(a+direction*60+Vector2(0,50),false)
	check(requests==count and part.transform==partial and surface.drag_progress>0,"shallow release stays partly inserted instead of recoiling")
	var grip: Vector2=stage.position+surface._project(part.global_position)
	await mouse(grip,true);await move(grip+direction*100,direction*100);await mouse(grip+direction*100,false)
	check(requests==count+1,"re-grab continues the same partial insertion and snaps by depth")
	check(surface.accepted_pose.origin.distance_to(seated.origin)<initial.origin.distance_to(seated.origin)*.3,"accepted animation starts from deep actual dragged pose")
	count=requests
	await reset_fixture();a=start()
	await mouse(a,true);await move(a+direction*100,direction*100);var deep: float=surface.drag_progress
	await move(a+direction*35,-direction*65)
	check(surface.drag_progress<deep and surface.drag_progress>.05,"reversing the same gesture pulls wood back out")
	await move(a-direction*30,-direction*65);await mouse(a-direction*30,false)
	check(requests==count and part.transform==initial,"fully withdrawing restores uninserted wood without trial")
	await reset_fixture();a=start();await stroke(a,a+direction*210+Vector2(0,75))
	check(requests==count+1,"deep release accepts regardless of abstract mouth target or lateral hand offset")
	count=requests
	await reset_fixture();a=start();await stroke(a,a)
	check(requests==count,"click never inserts")
	await stroke(a,a-direction*100)
	check(requests==count and part.transform==initial,"wrong-way movement does not advance")
	await reset_fixture(false);a=start();await stroke(a,a+direction*200)
	check(selection_prompts==1 and requests==count,"unselected stock prompts instead of guessing or orbiting")
	await reset_fixture();a=start()
	await mouse(a,true);await move(a+direction*70,direction*70);surface.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await mouse(a+direction*200,false)
	check(requests==count and part.transform==initial,"focus loss resets partial insertion and prevents stale release")
	await reset_fixture();a=start();await touch(a,true,2);await swipe(a+direction*190,direction*190,2);await touch(a+direction*190,false,2,true)
	check(requests==count and part.transform==initial,"canceled touch does not insert")
	await stroke(a,a+direction*200,true,3)
	check(requests==count+1,"touch follows the same continuous insertion path")
	count=requests
	await reset_fixture();a=start();await touch(a,true,4);await swipe(a+direction*100,direction*100,4);await touch(a,true,5);await touch(a,false,5);await touch(a+direction*200,false,4)
	check(requests==count and part.transform==initial,"multiple fingers cancel the locked part gesture")
	await create_timer(.46).timeout
	await reset_fixture();a=start();var blank:=stage.position+Vector2(30,30)
	await mouse(blank,true);await move(a,a-blank)
	check(not surface.assembly_dragging and surface.target_angles!=Vector2.ZERO,"background press stays orbit when crossing wood")
	await mouse(a,false)
	await reset_fixture();a=start();await mouse(a,true);await move(a+direction*100+Vector2(0,150),direction*100+Vector2(0,150))
	check(surface.assembly_dragging and surface.target_angles==Vector2.ZERO,"part press stays insertion when hand leaves wood")
	surface.cancel();await mouse(a,false)
	stage.position=Vector2(50,110);stage.size=Vector2(800,480);container.size=stage.size;await process_frame
	await reset_fixture();a=start();direction=(target()-a).normalized();count=requests
	await stroke(a,a+direction*210,true,8)
	check(requests==count+1,"offset resized half-resolution viewport preserves touch insertion")
	print("GUIDED_INSERTION_INPUT ",passed," passed; ",failures.size()," failed")
	stage.free();quit(0 if failures.is_empty() else 1)
