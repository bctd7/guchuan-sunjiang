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
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view,_can_drag)
	interaction.feedback.connect(func(message: String,error: bool): panel.feedback(message,error))
	interaction.gesture_changed.connect(func(): panel.drag_guide.queue_redraw())
	interaction.socket_requested.connect(_try_socket)
	panel.piece_selected.connect(_select_piece)
	panel.observe_requested.connect(_observe)
	panel.overview_requested.connect(_overview)
	panel.transparent_requested.connect(_toggle_transparency)
	panel.plan_requested.connect(_toggle_plan)
	panel.joint_selected.connect(_choose_joint)
	panel.layout_selected.connect(func(id: String):
		if not busy and not state.failed:
			interaction.cancel()
			state.choose_layout(id))
	panel.undo_requested.connect(_undo)
	panel.repair_requested.connect(_repair)
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

func _select_piece(id: String) -> void:
	if busy or state.failed: return
	interaction.cancel()
	panel.diagram.hide()
	view.inspected = false
	state.select(id)
	view.show_overview()

func _observe() -> void:
	if busy or state.failed: return
	interaction.cancel()
	panel.diagram.hide()
	state.observe()
	view.inspect_selected()
	_refresh()

func _overview() -> void:
	if busy or state.failed: return
	interaction.cancel()
	panel.diagram.hide()
	view.show_overview()
	_refresh()

func _toggle_transparency() -> void:
	if busy or state.failed: return
	view.transparent = not view.transparent
	view.sync_state(state)

func _toggle_plan() -> void:
	if busy or state.failed: return
	interaction.cancel()
	panel.diagram.visible = not panel.diagram.visible
	_refresh()

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
	view.show_overview()

func _repair() -> void:
	if state.failed: return
	_cancel_placement()
	panel.success_panel.hide()
	panel.diagram.hide()
	view.inspected = false
	state.repair()
	view.show_overview()
	panel.feedback("已撤回到首个对齐板列。观察下列端缝，重选另一排布。")

func _restart() -> void:
	_cancel_placement()
	panel.success_panel.hide()
	panel.failure_overlay.hide()
	panel.diagram.hide()
	view.inspected = false
	state.reset()
	view.show_overview()
	panel.feedback("重新开始：先观察底列企口。")

func _return_to_directory() -> void:
	if busy: return
	return_requested.emit()

func _refresh() -> void:
	if not is_instance_valid(view) or not is_instance_valid(panel): return
	view.sync_state(state)
	panel.refresh(state,view.inspected,busy)
	panel.drag_guide.configure(view,not state.failed and not busy and not panel.diagram.visible)
	interaction.set_process_input(not state.failed)
	interaction.set_process_unhandled_input(not state.failed)

func _can_drag(id: String) -> Dictionary:
	if state.failed: return Rules.result(false,"failed","本关未通过，请重新开始。")
	if busy or learning.modal_open() or bulkhead_lesson.opened or panel.diagram.visible: return Rules.result(false,"busy","先返回船壳，等待当前演示结束。")
	return state.can_attempt(id)

func _try_socket(id: String) -> Dictionary:
	if not interaction.consume_release(id): return Rules.result(false,"drag_required","按住木料沿箭头推入，松手接合。")
	if state.failed: return Rules.result(false,"failed","本关未通过，请重新开始或回到关卡目录。")
	if busy or learning.modal_open() or bulkhead_lesson.opened: return Rules.result(false,"busy","等待当前木件装入。")
	var released_pose: Transform3D=view.pieces[id].transform
	var depth: float=view.preview_progress
	var result = state.attempt(id)
	if result.ok:
		view.pieces[id].transform=released_pose
		view.preview_progress=depth
	panel.feedback(result.message,not result.ok)
	if result.ok:
		busy=true
		view.animate_place(id)
		_placement_tween=view.animations[id]
		_placement_tween.finished.connect(func():
			busy=false
			_placement_tween=null
			_refresh()
			if state.placed.size()==Rules.IDS.size(): _check())
		_refresh()
	return result

func _check() -> void:
	if state.failed or state.completed or busy or not view.animations.is_empty() or state.placed.size()!=Rules.IDS.size(): return
	panel.diagram.hide()
	view.show_overview()
	busy=true
	interaction.cancel()
	var rows: Array[int]=[]
	for row in [1,2]:
		if Rules.aligned(str(state.layouts[row-1]),str(state.layouts[row])):
			for index in [row-1,row]:
				if not rows.has(index): rows.append(index)
	var generation:=_trial_generation
	var motion: Tween=view.trial.play(rows)
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
	bulkhead_lesson.close()
	interaction.cancel()

func is_completed() -> bool:
	return state.completed

func navigation_status() -> Dictionary:
	return {"modal_open": learning.modal_open() or bulkhead_lesson.opened, "can_leave": not busy}
