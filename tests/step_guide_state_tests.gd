extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)
func run() -> void:
	for number in [1,2,3]:
		var level=load("res://levels/level0%d/level0%d.tscn"%[number,number]).instantiate()
		root.add_child(level);await process_frame
		level.learning.start_button.pressed.emit();await process_frame
		var panel=level.panel
		if number==1:
			panel.refresh(level.state,"","",true)
			check(panel.step_guide.target==null,"first busy clears target")
			level.state.failed=true;panel.refresh(level.state,"","",false)
			check(panel.step_guide.target==null,"first failure")
			level.state.failed=false;level.state.completed=true;panel.refresh(level.state,"","",false)
			check(panel.step_guide.target==null,"first success")
		elif number==2:
			panel.refresh(level.state,true,true)
			check(panel.step_guide.target==null,"second busy")
			level.state.failed=true;panel.refresh(level.state,true,false)
			check(panel.step_guide.target==null,"second failure")
			level.state.failed=false;level.state.completed=true;panel.refresh(level.state,true,false)
			check(panel.step_guide.target==null,"second success")
		else:
			panel.refresh(level.state,true)
			check(panel.step_guide.target==null,"third busy")
			level.state.placed.append("blade");panel.refresh(level.state,false)
			check(panel.step_guide.target==panel.left_button,"third helm")
			level.state.completed=true;panel.refresh(level.state,false)
			check(panel.step_guide.target==null,"third success")
		level._restart();await process_frame
		check(panel.undo_button.disabled and panel.undo_button.modulate.a==0,"restart removes undo "+str(number))
		level.free();await process_frame
	print("GUIDE_STATE ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
