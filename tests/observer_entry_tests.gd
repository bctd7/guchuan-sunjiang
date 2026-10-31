extends SceneTree
var level: Node3D
var passed:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failures.append(label);push_error(label)
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new()
	move.position=point
	root.push_input(move,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.pressed=down
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event,true)
		await process_frame
	await process_frame
func button(control: Control) -> void:await click(control.get_global_rect().get_center())
func run() -> void:
	root.size=Vector2i(1440,900)
	level=load("res://levels/level01/level01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await button(level.learning.start_button)
	await button(level.panel.inspect_button)
	var inspector=level.inspector
	check(inspector.selected_joint.is_empty() and inspector.selected_length.is_empty(),"no automatic answer")
	await button(inspector.length_buttons.long)
	check(level.tenon_length=="long" and level.joint_type.is_empty(),"length-only choice stays explicit")
	await button(inspector.install_button)
	check(level.state.placed.size()==1 and not inspector.orbit.assembly_enabled,"missing type prompt cannot install or auto-select")
	check(inspector.status.text.contains("A") and inspector.status.text.contains("上方"),"length-only prompt identifies remaining type choice")
	for kind in ["dovetail","through_tenon","blind_tenon"]:
		var card: Button=inspector.joint_buttons[kind]
		await click(card.get_global_rect().position+Vector2(card.size.x*.5,50))
		check(level.joint_type==kind and inspector.selected_joint==kind,"actual preview image click selects "+kind)
		check(card.button_pressed and inspector.selected_length=="long","whole card highlights and preserves wood choice")
	check(inspector.orbit.assembly_enabled,"explicit type and length enable real unchanged drag")
	await button(inspector.length_buttons.correct)
	await button(inspector.close_button)
	await button(level.panel.inspect_button)
	check(inspector.selected_joint=="blind_tenon" and inspector.selected_length=="correct","reopening preserves explicit choices")
	await button(inspector.close_button)
	await button(level.panel.restart_button)
	await button(level.panel.inspect_button)
	check(inspector.selected_joint.is_empty() and inspector.selected_length.is_empty() and not inspector.orbit.assembly_enabled,"reset clears both choices without assembly")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"method":"Actual GUI-dispatched pointer clicks on model image regions and missing-choice button; no direct business callbacks. Separate from native Windows test."}
	FileAccess.open("res://tests/observer_entry_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OBSERVER ENTRY ",JSON.stringify(report))
	level.free()
	quit(0 if failures.is_empty() else 1)
