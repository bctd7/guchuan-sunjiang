extends Node3D
signal progress_changed
## Chapter coordinator: routes intent; state owns all acceptance rules.
signal level_completed
signal return_requested
const State = preload("res://levels/level02/level_state.gd")
const Rules = preload("res://levels/level02/connection_rules.gd")
const View = preload("res://levels/level02/hull_view.gd")
const LevelPanel = preload("res://levels/level02/level_ui.gd")
const Touch = preload("res://levels/level02/hull_drag_interaction.gd")
const BulkheadLesson=preload("res://levels/level02/bulkhead_lesson.gd")
const Learning = preload("res://levels/shared/teaching_portal.gd")
var bulkhead_lesson: CanvasLayer
var learning: CanvasLayer
var state = State.new()
var view: Node3D
var panel: CanvasLayer
var busy := false
var _trial_generation := 0
var _placement_tween: Tween
var interaction: Node

func _ready() -> void:
	view = View.new()
	add_child(view)
	panel = LevelPanel.new()
	add_child(panel)
	view.trial.phase_changed.connect(func(message: String): panel.feedback(message))
	panel.bind_view(view)
	view.configure_workspace(panel.workspace.stage_surface,panel.local_viewport,panel.observation_orbit)
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view,_can_drag)
	interaction.zoom_requested.connect(_zoom_observation)
	panel.zoom_requested.connect(_zoom_observation)
	panel.magnify_requested.connect(_magnify)
	panel.magnifier.closed.connect(_refresh)
	interaction.feedback.connect(func(message: String,error: bool): panel.feedback(message,error))
	interaction.gesture_changed.connect(_gesture_changed)
	interaction.socket_requested.connect(_try_socket)
	panel.group_selected.connect(func(index: int):
		var target: String=state.group_target(index)
		if not target.is_empty():_select_piece(target))
	panel.next_piece_requested.connect(_continue_group)
	panel.observe_requested.connect(_observe)
	panel.overview_requested.connect(_overview)
	panel.transparent_requested.connect(_toggle_transparency)
	panel.joint_selected.connect(_choose_joint)
	panel.opening_selected.connect(func(id: String):
		if not busy and not state.failed:
			interaction.cancel();state.choose_opening(id))
	panel.prepare_observation_requested.connect(func():
		if busy or state.failed:return
		if state.joint.is_empty() or state.opening.is_empty():
			panel.feedback("先选榫头，再选接合口匹配的木料。")
		else:
			interaction.cancel();view.inspect_selected();_refresh();panel.feedback("抓住木料沿箭头试装，松手接合。"))
	panel.reset_observation_requested.connect(func():
		if not busy and not state.failed:
			var depth: float=view.preview_progress
			interaction.cancel();view.inspect_selected();view.set_preview_progress(depth);_refresh())
	panel.layout_selected.connect(func(id: String):
		if not busy and not state.failed:
			interaction.cancel()
			state.choose_layout(id))
	panel.undo_requested.connect(_undo)
	panel.restart_requested.connect(_restart)
	panel.check_requested.connect(_check)
	panel.return_requested.connect(_return_to_directory)
	panel.continue_requested.connect(_return_to_directory)
	panel.bulkhead_requested.connect(func():
		if not busy and not state.failed: bulkhead_lesson.show_lesson(interaction))
	panel.lesson_requested.connect(func():
		if not busy and not state.failed: learning.show_intro())
	state.changed.connect(_refresh)
	state.changed.connect(func(): progress_changed.emit())
	_refresh()
	learning = Learning.new()
	add_child(learning)
	learning.configure(2,view,panel,interaction)
	bulkhead_lesson=BulkheadLesson.new()
	add_child(bulkhead_lesson)

func _zoom_observation(factor: float) -> void:
	if busy or state.failed or interaction.dragging or not view.inspected or panel.magnifier.visible or learning.modal_open() or bulkhead_lesson.opened:return
	view.zoom_observation(factor);panel.update_zoom(view.framing.zoom_factor)
func _magnify(source: Control,title: String) -> void:
	if busy or state.failed or interaction.dragging or not view.inspected:return
	interaction.suspend_gesture()
	panel.magnifier.open(source,title)
	interaction.set_process_input(false);interaction.set_process_unhandled_input(false)

func _select_piece(id: String) -> void:
	if busy or state.failed: return
	interaction.cancel()
	view.inspected = false
	state.select(id)
	_show_overview()

func _observe() -> void:
	if busy or state.failed: return
	interaction.cancel()
	state.observe()
	view.reparent(panel.local_viewport)
	view.camera.make_current()
	view.inspect_selected()
	panel.feedback("看清榫头与槽口，选择候选模型后沿箭头试装。")
	_refresh()

func _overview() -> void:
	if busy or state.failed: return
	interaction.cancel()
	_show_overview()
	if state.placed.has(state.selected) and not state.next_id().is_empty():state.select(state.next_id())
	_refresh()

func _toggle_transparency() -> void:
	if busy or state.failed or not view.inspected: return
	view.toggle_connection_detail()
	_refresh()

func _continue_group() -> void:
	if busy or state.failed:return
	var next: String=state.next_in_group()
	if next.is_empty():return
	var joint: String=str(state.placed[state.selected].joint)
	var opening: String=str(state.placed[state.selected].opening) if next.begins_with("plank") else ""
	interaction.cancel()
	state.select(next)
	state.observe()
	state.choose_joint(joint)
	if not opening.is_empty():state.choose_opening(opening)
	view.inspect_selected()
	_refresh()
	panel.feedback("同组木料已就位待装，沿箭头继续推入。")

func _choose_joint(id: String) -> void:
	if busy or state.failed: return
	interaction.cancel()
	state.choose_joint(id)
	panel.gallery.choose(id)

func _undo() -> void:
	if state.failed: return
	_cancel_placement()
	panel.success_panel.hide()
	view.inspected = false
	state.undo()
	_show_overview()

func _restart() -> void:
	_cancel_placement()
	panel.success_panel.hide()
	panel.failure_overlay.hide()
	panel.inventory_panel.hide()
	view.inspected = false
	state.reset()
	_show_overview()
	panel.feedback("重新开始：先观察底列企口。")

func _return_to_directory() -> void:
	if busy: return
	return_requested.emit()

func _refresh() -> void:
	if not is_instance_valid(view) or not is_instance_valid(panel): return
	view.sync_state(state)
	panel.refresh(state,view.inspected,busy,view.transparent)
	panel.drag_guide.configure(view,view.inspected and not state.failed and not busy)
	interaction.set_process_input(not state.failed and not panel.magnifier.visible)
	interaction.set_process_unhandled_input(not state.failed and not panel.magnifier.visible)

func _can_drag(id: String) -> Dictionary:
	if state.failed: return Rules.result(false,"failed","本关未通过，请重新开始。")
	if busy or learning.modal_open() or bulkhead_lesson.opened or panel.inventory_open or panel.magnifier.visible: return Rules.result(false,"busy","先返回船壳，等待当前演示结束。")
	if id not in Rules.MANUAL_IDS:return Rules.result(false,"automatic","同组木料会沿用本次选择自动装入。")
	if not view.inspected:return Rules.result(false,"viewing","点击左侧观察按钮，进入局部再动手试装。")
	return state.can_attempt(id)

func _try_socket(id: String) -> Dictionary:
	if not interaction.consume_release(id): return Rules.result(false,"drag_required","按住木料沿箭头推入，松手接合。")
	if state.failed: return Rules.result(false,"failed","本关未通过，请重新开始或回到关卡目录。")
	if busy or learning.modal_open() or bulkhead_lesson.opened: return Rules.result(false,"busy","等待当前木件装入。")
	var decision: Dictionary=state.installation_result(id)
	if not decision.ok:return decision
	decision=_physical_decision(id,decision)
	if decision.mode==State.Assembly.BLOCKED:
		_animate_contact_stop(id,decision.message)
		return Rules.result(false,"assembly_blocked",decision.message)
	var released_pose: Transform3D=view.pieces[id].transform
	var depth: float=view.preview_progress
	var result = state.attempt(id)
	if result.ok:
		view.pieces[id].transform=released_pose
		view.preview_progress=depth
	panel.feedback(result.message,not result.ok)
	if result.ok:
		busy=true
		var generation:=_trial_generation
		view.animate_place(id)
		_placement_tween=view.animations[id]
		_placement_tween.finished.connect(func():
			if generation!=_trial_generation:return
			busy=false
			_placement_tween=null
			_refresh()
			if result.code=="middle_seated":
				state.begin_starter_top(id)
				view.inspect_selected(false);_refresh()
				panel.feedback("中件已就位，把上方木件向下嵌入交叉槽。")
				return
			var settled: Dictionary=state.finish_installation(id)
			if state.failed:
				interaction.cancel();panel.feedback(settled.message,true);panel.failure_overlay.open()
				return
			if Rules.AUTO_GROUPS.has(id):_complete_group(id)
			elif state.placed.size()==Rules.IDS.size(): _check())
		_refresh()
	return result

func _physical_decision(id: String,decision: Dictionary) -> Dictionary:
	# The same check serves manual and repeated stock. An incorrect answer is
	# not itself an obstruction: test the actual retained members and their path.
	if not view.installation_receiver_present(id):
		return State.Assembly.outcome(State.Assembly.BLOCKED,"下方木料没有延续至此的接合边，下一块无法嵌合落座。")
	if not view.installation_path_clear(id):
		return State.Assembly.outcome(State.Assembly.BLOCKED,"已有木料挡住装入路径，无法继续完成装配。")
	if not view.installation_closes_joint(id):
		return State.Assembly.outcome(State.Assembly.BLOCKED,"顶件碰到下方槽肩，无法落入交叉槽，三件不能扣合。")
	return decision

func _animate_contact_stop(id: String,message: String) -> void:
	# Only a committed release enters this path. Shallow exploration is neutral;
	# an impossible committed assembly ends after visible contact, in every group.
	busy=true
	var generation:=_trial_generation
	view.animate_place(id)
	_placement_tween=view.animations[id]
	panel.feedback("木料到达接合处，正在检查能否落座。")
	_placement_tween.finished.connect(func():
		if generation!=_trial_generation:return
		busy=false;_placement_tween=null
		state.fail_installation(id,message)
		interaction.cancel();panel.feedback(message,true);panel.failure_overlay.open())
	_refresh()

func _gesture_changed() -> void:
	panel.drag_guide.queue_redraw()

func _complete_group(representative: String) -> void:
	# Only homologous cuts repeat. Each member still owns its real mesh, path,
	# accepted choice and cancellable seating animation.
	var id: String=state.next_automatic(representative)
	if id.is_empty():
		busy=false;_placement_tween=null
		if not state.next_id().is_empty():state.select(state.next_id())
		panel.feedback("本组已装入，继续下一组。")
		_refresh()
		if state.next_id().is_empty():_check()
		return
	busy=true;_show_overview()
	var generation:=_trial_generation
	var prepared: Dictionary=state.prepare_automatic(representative)
	if not prepared.ok:
		busy=false;panel.feedback(prepared.message,true);_refresh();return
	var decision: Dictionary=_physical_decision(id,State.Assembly.assess(id,state.joint,state.opening))
	if decision.mode==State.Assembly.BLOCKED:
		# Keep an impossible repeated fit visible at its own contact, rather than
		# hiding it in the completed group or forcing it through installed wood.
		busy=false;_observe()
		_animate_contact_stop(id,decision.message)
		return
	var result: Dictionary=state.place_automatic(representative)
	if not result.ok:
		busy=false;panel.feedback(result.message,true);_refresh();return
	view.pieces[id].transform=view.poses[id]
	view.pieces[id].position+=view.preview_offset(id)
	view.preview_progress=0.0;view.animate_place(id)
	_placement_tween=view.animations[id]
	panel.feedback(result.message);_refresh()
	_placement_tween.finished.connect(func():
		if generation!=_trial_generation:return
		_complete_group(representative))

func _check() -> void:
	if state.failed or state.completed or busy or not view.animations.is_empty() or state.placed.size()!=Rules.IDS.size(): return
	_show_overview()
	busy=true
	interaction.cancel()
	var rows: Array[int]=state.leaking_rows()
	var generation:=_trial_generation
	var presentation=view.trial_presentation(rows,state.connection_issues(),state.mismatched_joints())
	var motion: Tween=view.trial.play(presentation)
	view.animations["sea_trial"]=motion
	motion.finished.connect(func():
		if generation!=_trial_generation: return
		view.animations.erase("sea_trial")
		busy=false
		_finish_trial())
	_refresh()

func _finish_trial() -> void:
	var result = state.validate()
	panel.feedback(result.message,not result.ok)
	if result.ok:
		panel.success_panel.show()
		level_completed.emit()
	elif state.failed:
		interaction.cancel()
		panel.success_panel.hide()
		panel.failure_overlay.open()

func _cancel_placement() -> void:
	_trial_generation+=1
	interaction.cancel()
	if is_instance_valid(_placement_tween): _placement_tween.kill()
	_placement_tween=null
	view.cancel_animations()
	busy=false

# Campaign contract. Reentry keeps this instance and its gameplay state.
func enter() -> void:
	learning.show_intro()

func leave() -> void:
	panel.magnifier.close()
	bulkhead_lesson.close()
	interaction.cancel()

func is_completed() -> bool:
	return state.completed

func navigation_status() -> Dictionary:
	return {"modal_open": learning.modal_open() or bulkhead_lesson.opened or view.inspected or panel.inventory_open or panel.magnifier.visible, "can_leave": not busy}

func _show_overview() -> void:
	panel.observation_orbit.deactivate()
	if view.get_parent()!=self:view.reparent(self)
	view.show_overview()
	view.camera.make_current()
