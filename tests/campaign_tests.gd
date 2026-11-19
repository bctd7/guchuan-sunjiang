extends SceneTree
const HullNavigation=preload("res://tests/hull_navigation.gd")
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
	level=campaign.current_chapter
	check(campaign.active_level==number and level.is_inside_tree(),"directory enters level "+str(number))
	if level.learning.modal_open():
		check(level.learning.lesson_buttons.size()==3,"chapter entry introduces its three original lessons "+str(number))
		await button(level.learning.start_button)
		await settle(.1)
	check(not campaign.menu.visible and campaign.back_button.is_visible_in_tree(),"level shows navigation "+str(number))
	var navigation_rect: Rect2=campaign.back_button.get_global_rect()
	var header_safe: Rect2=preload("res://components/ui/exhibition_layout.gd").project_rect(Rect2(1200,18,220,86),campaign.get_viewport().get_visible_rect().size)
	check(header_safe.encloses(navigation_rect),"directory return fits header without obscuring task")

func back() -> void:
	var exit_button: Button = campaign.back_button
	if is_instance_valid(level) and level.panel.success_panel.visible:
		var result = level.panel.success_panel
		exit_button = result.return_button if result.return_button.visible else result.restart_button
	await button(exit_button)
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
	check(level.panel.success_panel.restart_button.is_visible_in_tree(),"completed chapter exposes next chapter")
	await snapshot("02-level01-complete")

func smoke_l1() -> void:
	await snapshot("00-directory")
	await enter(1)
	var first=level
	var children: int=level.get_child_count()
	check(level.state.placed.has("keel") and level.view.pieces.keel.visible and level.state.progress_count()==0,"chapter opens with fixed keel and zero player tasks")
	check(level.panel.main_sidebar.find_children("*","BaseButton",true,false)==[level.panel.inspect_button,level.panel.lesson_button] and not level.view.slots.keel.visible,"chapter has no redundant keel selection or target")
	level.interaction.socket_requested.connect(func(_id: String): requests+=1)
	await place_l1("rib_l1")
	check(level.state.progress_count()==1 and requests==1,"first world click generates exactly one request")
	var saved: Dictionary=level.state.placed.duplicate(true)
	var target: Vector2=level.view.socket_screen_position("rib_l1")
	await back()
	check(not is_instance_valid(first),"directory frees old instance")
	await click(target)
	check(requests==1,"old input is stopped")
	for cycle in 2:
		await enter(1)
		check(level.state.progress_count()==0,"reentry starts fresh")
		await back()
	await enter(1)

func place_l2(id: String) -> void:
	if level.state.placed.has(id) and level.state.placed[id].get("automatic",false):return
	await HullNavigation.open_local(root,level,id)
	check(level.view.inspected and level.state.observed.has(id),"chapter two opens actual observed member: "+id)
	check(not level.panel.observe_button.get_global_rect().intersects(campaign.back_button.get_global_rect()),"chapter two observation control clears campaign return")
	await button(level.panel.joint_buttons[level.Rules.expected(id)])
	await button(level.panel.opening_buttons[level.state.Openings.target(id)])
	var target: Vector2=level.view.drag_grab_screen()
	check(level.view.pick_drag_piece(target)==id,"chapter two actual timber is pickable: "+id)
	await settle(.5)
	await HullPointer.drag(root,level.view,1.0)
	var deadline:=Time.get_ticks_msec()+12000
	while level.busy and Time.get_ticks_msec()<deadline: await process_frame
	if level.view.inspected:await button(level.panel.overview_button)
	var automatic_deadline:=Time.get_ticks_msec()+10000
	while level.busy and Time.get_ticks_msec()<automatic_deadline:await process_frame
	await settle(.06) # allow campaign navigation to reflect the local-page return
	check(not level.busy,"chapter two finishes the seating and any automatic work")
	check(level.state.placed.has(id),"chapter two pointer places "+id)

func chapter_two() -> void:
	var first=level
	await place_l2("plank_0a")
	var children: int=level.get_child_count()
	await back()
	await enter(2)
	check(not is_instance_valid(first) and level.state.placed.is_empty(),"chapter two direct reentry starts fresh")
	check(level.get_child_count()==children,"chapter two direct reentry creates no extra adapters")
	for id in level.Rules.MANUAL_IDS:
		if id==level.Rules.MANUAL_IDS.back():
			await button(level.panel.inventory_button)
			check(level.panel.group_buttons.size()==3 and level.Rules.GROUPS.size()==3,"inventory displays three construction groups")
			await snapshot("06-level02-three-groups")
			await button(level.panel.inventory_close_button)
		await place_l2(id)
	check(level.state.layouts[0]=="A" and level.state.layouts[1]=="B" and level.state.layouts[2]=="A","actual GUI chooses alternating board end positions")
	var marks: Array=level.view.seam_lines.get_children()
	check(marks.size()==3,"actual hull has one board-end seam mark per row")
	for row in marks.size():
		var bounds: AABB=marks[row].get_aabb()
		check(bounds.size.x<bounds.size.z*.2 and bounds.size.z>.7 and bounds.size.z<.8,"seam marker spans board width rather than long horizontal edge: "+str(row))
		check(is_equal_approx(bounds.get_center().x,level.Rules.seam(level.state.layouts[row])),"seam marker follows actual board end x: "+str(row))
	check(level.state.placed.size()==10,"three display groups retain ten placed members")
	check(level.state.completed and campaign.completed.get(2,false),"chapter two UI inspection synchronizes campaign completion")
	check(level.panel.success_panel.restart_button.is_visible_in_tree(),"chapter two completion exposes chapter three action")
	await snapshot("04-level02-completed-end-seams")
	await back()
	check(not campaign.chapter_buttons[2].text.begins_with("✓"),"chapter two directory resets the completed round")
	await enter(2)
	await button(level.panel.restart_button)
	check(not level.state.completed and not campaign.completed.get(2,true),"chapter two UI reset clears campaign completion")
	check(not campaign.next_button.visible and not campaign.chapter_buttons[2].text.begins_with("✓"),"chapter two reset clears badge and next action")
	if phase=="full":
		for id in level.Rules.MANUAL_IDS: await place_l2(id)
		await button(level.panel.success_panel.restart_button)
		await settle(0.4)
		level=campaign.current_chapter
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
	if not level.panel.inspected: await button(level.panel.inspect_button)
	await button(level.panel.candidate_buttons[level.state.Rules.SPECS[id].joint])
	if level.state.Rules.SETTINGS.has(id):
		await button(level.panel.setting_buttons[level.state.Rules.SETTINGS[id].correct])
	await HullPointer.drag_assembly(root,level.panel.orbit)
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
	await place_l3("apron")
	await button(level.panel.overview_button)
	var first=level
	var children: int=level.get_child_count()
	await back()
	await enter(3)
	check(not is_instance_valid(first) and level.state.placed.is_empty(),"chapter three reentry starts fresh")
	await place_l3("apron")
	check(level.get_child_count()==children,"chapter three reentry adds no duplicate scene or input")
	await button(level.panel.next_button)
	for id in level.state.Rules.ORDER.slice(1):
		await place_l3(id)
		if id!="blade": await button(level.panel.next_button)
	await button(level.panel.overview_button)
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
	check(not campaign.completed.get(3,false),"trial required after right helm")
	await button(level.panel.launch_button)
	await settle(3.3)
	check(level.state.completed and campaign.completed.get(3,false),"harbor trial completes third chapter and campaign marker")
	check(not campaign.next_button.visible,"last chapter has no out-of-range next chapter action")
	await snapshot("10-level03-complete-right-helm")
	await back()
	check(not campaign.chapter_buttons[3].text.begins_with("✓"),"chapter three directory resets the completed round")
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
		if number==2:await HullNavigation.open_local(root,level,level.state.selected)
		if number==3:await button(level.panel.inspect_button)
		var saved=level.state.placed.duplicate(true)
		var camera_pose: Transform3D=level.view.camera.transform
		if number==1:
			await button(level.panel.inspect_button)
			await button(level.inspector.lesson_button)
		else:
			await button(level.panel.lesson_button)
		await settle(.2)
		check(level.learning.opened and level.learning.lesson_buttons.size()==3,"chapter revisit opens its three-lesson introduction: "+str(number))
		check(campaign.back_button.is_visible_in_tree(),"introduction offers directory return: "+str(number))
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
		if number==2:
			check(level.view.inspected and not campaign.navigation.visible,"second chapter classroom returns to its exact local workspace")
			await button(level.panel.overview_button)
		elif number==1:
			check(level.inspector.opened and level.inspector.visible, "first chapter classroom returns to its observation")
			await button(level.inspector.close_button)
		else:
			check(level.panel.inspected, "third chapter classroom returns to its observation")
			await button(level.panel.overview_button)
		check(campaign.back_button.is_visible_in_tree(),"campaign navigation returns after classroom closes: "+str(number))
		await back()

func run() -> void:
	root.size=Vector2i(1440,900)
	campaign=load("res://app/campaign/campaign.tscn").instantiate()
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
		check(not campaign.completed.get(1,false) and not campaign.chapter_buttons[1].text.begins_with("✓"),"directory badge records completed chapter")
		await enter(1)
		await button(level.panel.restart_button)
		check(not level.state.completed and not campaign.completed.get(1,true),"UI reset synchronizes campaign completed marker")
		check(not campaign.next_button.visible and not campaign.chapter_buttons[1].text.begins_with("✓"),"reset removes next action and completed badge")
		await finish_l1()
		if phase=="full":
			await button(level.panel.success_panel.restart_button)
			await settle(0.4)
			check(campaign.active_level==2,"next action enters chapter two")
			level=campaign.current_chapter
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
	var file:=FileAccess.open("res://tests/campaign_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://tests/campaign_"+phase+"_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMPAIGN ",JSON.stringify(report))
	campaign.free()
	await stop_music()
	quit(0 if failed==0 else 1)

func stop_music() -> void:
	root.get_node("GameAudio").music.stop()
	# Allow the audio server to release its stream playback before SceneTree quits.
	await create_timer(.2).timeout
