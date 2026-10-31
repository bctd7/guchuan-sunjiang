extends SceneTree
const HullPointer=preload("res://tests/hull_pointer.gd")
## Independent campaign acceptance. All actions use Viewport pointer events.
## State properties are read only. This is automated injection, not human hardware.
var campaign: Node
var level: Node
var passed := 0
var failed := 0
var failures: Array[String] = []
var requests := 0
var screenshots: Array[String] = []
var phase := "smoke"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		failures.append(label)
		push_error("FAIL "+label)

func settle(seconds := 0.15) -> void:
	await create_timer(seconds).timeout
	await process_frame

func click(position: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=position
	motion.global_position=position
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=position
		event.global_position=position
		event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await process_frame
	await process_frame

func button(control: Button) -> void:
	var ancestor:=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await process_frame
		ancestor=ancestor.get_parent()
	check(control.is_visible_in_tree() and not control.disabled,"operable GUI: "+control.text)
	await click(control.get_global_rect().get_center())
	await settle(0.06)

func find_button(node: Node, fragment: String) -> Button:
	if node is Button and node.text.contains(fragment): return node
	for child in node.get_children():
		var found:=find_button(child,fragment)
		if found!=null: return found
	return null

func snapshot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path: String="res://tests/evidence/campaign/"+label+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/evidence/campaign"))
	var error: Error=root.get_texture().get_image().save_png(path)
	check(error==OK,"saved actual rendered screenshot: "+label)
	screenshots.append(path)

func enter(number: int) -> void:
	await button(campaign.chapter_buttons[number])
	await settle(0.3)
	level=campaign.instances[number]
	check(campaign.active_level==number and level.is_inside_tree(),"directory enters level "+str(number))
	if level.learning.modal_open():
		check(level.learning.lesson_buttons.size()==3,"chapter entry introduces its three original lessons "+str(number))
		await button(level.learning.start_button)
		await settle(.1)
	check(not campaign.menu.visible and campaign.back_button.is_visible_in_tree(),"level shows navigation "+str(number))
	var navigation_rect: Rect2=campaign.back_button.get_global_rect()
	check(navigation_rect.position.x>=1200 and navigation_rect.end.x<=1420 and navigation_rect.position.y>=18 and navigation_rect.end.y<=104,"directory return fits header without obscuring task")

func back() -> void:
	await button(campaign.back_button)
	check(campaign.active_level==0 and campaign.menu.visible,"directory return shows campaign menu")

func close_l1() -> void:
	if level.inspector.visible:
		var elapsed:=0.0
		while level.inspector.is_animating and not level.inspector.animation_finished and elapsed<5.0:
			await settle(0.1)
			elapsed+=0.1
		await button(level.inspector.close_button)

func place_l1(id: String) -> void:
	check(level.state.selected==id,"current distinct demonstration: "+id)
	await button(level.panel.inspect_button)
	check(level.inspector.visible and not campaign.back_button.is_visible_in_tree(),"one observation entry hides campaign navigation")
	await button(level.inspector.joint_buttons[level.Rules.expected_joint(id)])
	await button(level.inspector.length_buttons["correct"])
	check(level.tenon_length=="correct","campaign explicitly chooses correct length: "+id)
	await button(level.inspector.close_button)
	await click(level.view.socket_screen_position(id))
	await settle(.9)
	await close_l1()
	var elapsed:=0.0
	while level.busy and elapsed<10:
		await settle(.1)
		elapsed+=.1
	check(not level.busy and level.state.placed.has(id),"manual demonstration and automatic group finish: "+id)
	for auto_id in level.Rules.AUTO_GROUPS[id]:
		check(level.state.placed.has(auto_id) and level.state.placed[auto_id].automatic,"automatic repeat remains explicitly marked: "+auto_id)

func finish_l1() -> void:
	for id in level.Rules.REPRESENTATIVE_IDS:
		if not level.state.placed.has(id): await place_l1(id)
	await button(level.panel.check_button)
	await settle(0.2)
	check(level.state.completed,"UI completes first chapter")
	check(campaign.completed.get(1,false),"campaign receives chapter completion")
	check(campaign.next_button.is_visible_in_tree(),"completed chapter exposes next chapter")
	await snapshot("02-level01-complete")
	await button(level.panel.success_close_button)

func smoke_l1() -> void:
	await snapshot("00-directory")
	await enter(1)
	var first=level
	var children: int=level.get_child_count()
	check(level.state.placed.has("keel") and level.view.pieces.keel.visible and level.state.progress_count()==0,"chapter opens with fixed keel and zero player tasks")
	check(level.panel.piece_buttons.is_empty() and level.panel.joint_buttons.is_empty() and not level.view.slots.keel.visible,"chapter has no redundant keel selection or target")
	level.interaction.socket_requested.connect(func(_id: String): requests+=1)
	await place_l1("rib_l1")
	check(level.state.progress_count()==1 and requests==1,"first world click generates exactly one request")
	var saved: Dictionary=level.state.placed.duplicate(true)
	var target: Vector2=level.view.socket_screen_position("rib_l1")
	await back()
	check(not first.is_inside_tree(),"cached level actually leaves SceneTree")
	await click(target)
	check(requests==1 and first.state.placed==saved,"detached level does not consume directory input")
	for cycle in 2:
		await enter(1)
		check(level==first and level.state.placed==saved,"reentry retains same state and instance "+str(cycle))
		check(level.get_child_count()==children,"reentry does not rebuild view, learning or input adapters")
		var before:=requests
		await click(level.view.socket_screen_position("rib_l1"))
		check(requests==before,"completed repeat has no extra interactive target after reentry "+str(cycle))
		check(level.state.progress_count()==1,"duplicate placement remains counted once")
		await back()
	await enter(1)
	await snapshot("01-level01-progress-preserved")

func place_l2(id: String) -> void:
	await button(level.panel.piece_buttons[id])
	await button(level.panel.observe_button)
	check(level.view.inspected and level.state.observed.has(id),"chapter two opens actual observed member: "+id)
	check(not level.panel.observe_button.get_global_rect().intersects(campaign.back_button.get_global_rect()),"chapter two observation control clears campaign return")
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	var row: int=level.Rules.row_for(id)
	if row>0 and id.ends_with("a"):
		await button(level.panel.layout_buttons["B" if row==1 else "A"])
	await button(level.panel.overview_button)
	var target: Vector2=level.view.drag_grab_screen()
	check(level.view.pick_drag_piece(target)==id,"chapter two actual timber is pickable: "+id)
	await settle(.5)
	await HullPointer.drag(root,level.view,1.0)
	var deadline:=Time.get_ticks_msec()+5000
	while level.busy and Time.get_ticks_msec()<deadline: await process_frame
	await settle(.06) # allow campaign navigation to reflect the finished tween
	check(not level.busy and not campaign.back_button.disabled,"chapter two finished motion restores navigation")
	check(level.state.placed.has(id),"chapter two pointer places "+id)

func chapter_two() -> void:
	var first=level
	await place_l2("plank_0a")
	var saved: Dictionary=level.state.placed.duplicate(true)
	var children: int=level.get_child_count()
	await back()
	await enter(2)
	check(level==first and level.state.placed==saved,"chapter two direct reentry preserves exact state")
	check(level.get_child_count()==children,"chapter two direct reentry creates no extra adapters")
	for id in level.Rules.IDS:
		if not level.state.placed.has(id): await place_l2(id)
	check(level.state.layouts[0]=="A" and level.state.layouts[1]=="B" and level.state.layouts[2]=="A","actual GUI chooses alternating board end positions")
	var marks: Array=level.view.seam_lines.get_children()
	check(marks.size()==3,"actual hull has one board-end seam mark per row")
	for row in marks.size():
		var mesh: BoxMesh=marks[row].mesh
		check(mesh.size.x<mesh.size.z*.2 and mesh.size.z>.7 and mesh.size.z<.8,"seam marker spans board width rather than long horizontal edge: "+str(row))
		check(is_equal_approx(marks[row].position.x,level.Rules.seam(level.state.layouts[row])),"seam marker follows actual board end x: "+str(row))
	await button(level.panel.check_button)
	check(level.state.completed and campaign.completed.get(2,false),"chapter two UI inspection synchronizes campaign completion")
	check(campaign.next_button.is_visible_in_tree(),"chapter two completion exposes chapter three action")
	await snapshot("04-level02-completed-end-seams")
	var close:=find_button(level.panel,"查看完成")
	if close!=null: await button(close)
	await snapshot("05-level02-hull-unobstructed")
	await button(level.panel.plan_button)
	await snapshot("06-level02-board-end-map")
	await back()
	check(campaign.chapter_buttons[2].text.begins_with("✓"),"chapter two directory badge records completion")
	await enter(2)
	await button(level.panel.restart_button)
	check(not level.state.completed and not campaign.completed.get(2,true),"chapter two UI reset clears campaign completion")
	check(not campaign.next_button.visible and not campaign.chapter_buttons[2].text.begins_with("✓"),"chapter two reset clears badge and next action")
	if phase=="full":
		for id in level.Rules.IDS: await place_l2(id)
		await button(level.panel.check_button)
		await button(campaign.next_button)
		await settle(0.4)
		level=campaign.instances[3]
		if level.learning.modal_open(): await button(level.learning.start_button)
		check(campaign.active_level==3,"completed chapter two next action enters chapter three")

func maximum_world_y(node: Node3D) -> float:
	var result: float=-INF
	if node is MeshInstance3D:
		var aabb: AABB=node.get_aabb()
		for corner in 8: result=maxf(result,(node.global_transform*aabb.get_endpoint(corner)).y)
	for child in node.get_children():
		if child is Node3D: result=maxf(result,maximum_world_y(child))
	return result

func place_l3(id: String) -> void:
	check(level.state.selected==id,"chapter three actual sequence selects "+id)
	await button(level.panel.candidate_buttons[level.state.Rules.SPECS[id].joint])
	var actual: Vector2=level.panel.main_viewport.get_parent().get_global_rect().position+level.view.camera.unproject_position(level.view.markers[id].global_position)
	check(actual.is_equal_approx(level.view.socket_screen_position(id)),"chapter three world helper agrees with actual SubViewport screen position: "+id)
	check(level.view.pick_socket(actual)==id,"chapter three actual screen target is pickable: "+id)
	await click(actual)
	if id=="rudder":
		check(not level.view.pieces.blade.visible,"wide blade remains detached while shaft enters bearing")
		var shaft: MeshInstance3D=level.view.pieces.rudder.get_node("RoundShaft")
		check(shaft.mesh.top_radius<0.20,"actual round shaft fits independent bearing opening")
		var shoulder: MeshInstance3D=level.view.pieces.rudder.get_node("TopThrustShoulder")
		var safe:=true
		var elapsed:=0.0
		while level.busy and elapsed<3.0:
			var low: float=shoulder.global_position.y-shoulder.mesh.height/2.0
			if low<0.819: safe=false
			await settle(0.04)
			elapsed+=0.04
		check(safe,"wide thrust shoulder stops above bearing throughout vertical shaft insertion")
		await snapshot("08-level03-shaft-before-blade")
	elif id=="blade":
		var safe:=true
		var elapsed:=0.0
		while level.busy and elapsed<3.0:
			if maximum_world_y(level.view.pieces.blade)>=0.50: safe=false
			await settle(0.04)
			elapsed+=0.04
		check(safe,"split blade assembly stays below bearing during lateral installation")
	else:
		await settle(1.15)
	check(level.state.placed.has(id) and not level.busy,"chapter three actual pointer installs "+id)

func chapter_three() -> void:
	await snapshot("07-level03-direct-entry")
	await place_l3("zrail")
	var first=level
	var saved: Array=level.state.placed.duplicate()
	var children: int=level.get_child_count()
	await back()
	await enter(3)
	check(level==first and level.state.placed==saved,"chapter three direct reentry retains exact instance and progress")
	check(level.get_child_count()==children,"chapter three reentry adds no duplicate scene or input")
	await button(level.panel.next_button)
	for id in ["leg","mast","apron","top","lbrace","rudder","blade"]:
		await place_l3(id)
		if id!="blade": await button(level.panel.next_button)
	var fixed: Dictionary={}
	for node in level.view.stages[2].get_children():
		if node is Node3D and node!=level.view.rudder_pivot: fixed[node]=node.global_transform
	var shaft_before: Transform3D=level.view.pieces.rudder.global_transform
	var blade_before: Transform3D=level.view.pieces.blade.global_transform
	await button(level.panel.left_button)
	check(is_equal_approx(level.state.rudder_angle,-30.0) and is_equal_approx(level.view.rudder_pivot.rotation_degrees.y,-30.0),"actual left helm sets shaft and blade to minus thirty degrees")
	check(not level.view.pieces.rudder.global_transform.is_equal_approx(shaft_before) and not level.view.pieces.blade.global_transform.is_equal_approx(blade_before),"both shaft and post-installed blade rotate")
	var static_ok:=true
	for node in fixed:
		if not node.global_transform.is_equal_approx(fixed[node]): static_ok=false
	check(static_ok,"L brace, independent bearing and stern frame remain fixed while shaft rotates")
	await snapshot("09-level03-left-helm")
	await button(level.panel.right_button)
	check(level.state.completed and campaign.completed.get(3,false),"actual right helm completes third chapter and campaign marker")
	check(not campaign.next_button.visible,"last chapter has no out-of-range next chapter action")
	await snapshot("10-level03-complete-right-helm")
	var close:=find_button(level.panel,"收起卡片")
	if close!=null: await button(close)
	await snapshot("11-level03-rudder-unobstructed")
	await back()
	check(campaign.chapter_buttons[3].text.begins_with("✓"),"third chapter directory badge records completion")
	await enter(3)
	await button(level.panel.restart_button)
	check(not level.state.completed and not campaign.completed.get(3,true),"third chapter UI reset synchronizes campaign marker")
	check(not campaign.chapter_buttons[3].text.begins_with("✓"),"third chapter reset clears directory badge")
	await back()
	await snapshot("12-directory-after-resets")

func classroom_navigation() -> void:
	for number in [1,2,3]:
		await enter(number)
		if number==1: await place_l1("rib_l1")
		var saved=level.state.placed.duplicate(true)
		var camera_pose: Transform3D=level.view.camera.transform
		if number==1:
			await button(level.panel.inspect_button)
			await button(level.inspector.lesson_button)
		else:
			await button(level.panel.lesson_button)
		await settle(.2)
		check(level.learning.opened and level.learning.lesson_buttons.size()==3,"chapter revisit opens its three-lesson introduction: "+str(number))
		check(not campaign.navigation.visible,"introduction hides campaign navigation: "+str(number))
		for id in level.learning.lesson_ids:
			await button(level.learning.lesson_buttons[id])
			check(is_instance_valid(level.learning.workshop) and level.learning.workshop.catalog.size()==3,"chapter-scoped original classroom opens through GUI: "+id)
			check(level.learning.workshop.assembly.definition.id==id,"chapter card opens its exact original lesson: "+id)
			check(not campaign.navigation.visible,"classroom hides campaign navigation over lesson return: "+id)
			await snapshot("13-original-classroom-"+str(number)+"-"+id)
			await button(level.learning.back_button)
			check(level.learning.opened and level.learning.workshop==null,"classroom return restores introduction: "+id)
			check(level.state.placed==saved,"each classroom return preserves chapter state: "+id)
		await button(level.learning.start_button)
		await settle(.2)
		check(not level.learning.modal_open() and level.state.placed==saved,"introduction return preserves chapter state: "+str(number))
		check(level.view.visible and level.panel.visible and level.view.camera.transform.is_equal_approx(camera_pose),"source view, panel and camera pose restored: "+str(number))
		check(campaign.back_button.is_visible_in_tree(),"campaign navigation returns after classroom closes: "+str(number))
		await back()

func run() -> void:
	root.size=Vector2i(1440,900)
	campaign=load("res://campaign/campaign.tscn").instantiate()
	root.add_child(campaign)
	await settle(0.4)
	check(campaign.chapter_buttons.size()==3,"directory contains all three direct-entry buttons")
	if phase=="classroom":
		await classroom_navigation()
	elif phase=="visual":
		await enter(3)
		await snapshot("14-level03-candidate-lighting")
		await back()
	elif phase=="level02":
		await enter(2)
		await chapter_two()
	elif phase=="level03":
		await enter(3)
		await chapter_three()
	else:
		await smoke_l1()
	if phase in ["level01","full"]:
		await finish_l1()
		await back()
		check(campaign.completed.get(1,false) and campaign.chapter_buttons[1].text.begins_with("✓"),"directory badge records completed chapter")
		await enter(1)
		await button(level.panel.restart_button)
		check(not level.state.completed and not campaign.completed.get(1,true),"UI reset synchronizes campaign completed marker")
		check(not campaign.next_button.visible and not campaign.chapter_buttons[1].text.begins_with("✓"),"reset removes next action and completed badge")
		await finish_l1()
		if phase=="full":
			await button(campaign.next_button)
			await settle(0.4)
			check(campaign.active_level==2,"next action enters chapter two")
			level=campaign.instances[2]
			if level.learning.modal_open(): await button(level.learning.start_button)
			await back()
			for number in [2,3]:
				await enter(number)
				await snapshot("0%d-level0%d-direct" % [number+1,number])
				await back()
			await enter(2)
			await chapter_two()
			await chapter_three()
	var report: Dictionary={"phase":phase,"passed":passed,"failed":failed,"failures":failures,"screenshots":screenshots,"method":"Actual Godot Viewport mouse events injected by automation; no direct business state mutation; not human hardware input","renderer":DisplayServer.get_name()}
	if phase in ["classroom","visual"] and FileAccess.file_exists("res://tests/campaign_report.json"):
		var previous=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_report.json"))
		if previous is Dictionary and previous.get("phase","")=="full":
			previous["supplementary_"+phase]=report.duplicate(true)
			previous["passed"]+=passed
			previous["failed"]+=failed
			previous["failures"].append_array(failures)
			previous["screenshots"].append_array(screenshots)
			report=previous
	var file:=FileAccess.open("res://tests/campaign_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CAMPAIGN ",JSON.stringify(report))
	campaign.free()
	quit(0 if failed==0 else 1)
