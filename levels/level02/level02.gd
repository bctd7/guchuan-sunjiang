extends Node3D
## Chapter coordinator: routes intent; state owns all acceptance rules.
signal level_completed
signal return_requested
const State = preload("res://levels/level02/level_state.gd")
const Rules = preload("res://levels/level02/connection_rules.gd")
const View = preload("res://levels/level02/hull_view.gd")
const LevelPanel = preload("res://levels/level02/level_ui.gd")
const Touch = preload("res://levels/shared/socket_interaction.gd")
const Learning = preload("res://shared/chapter_learning.gd")
var learning: CanvasLayer
var state = State.new()
var view: Node3D
var panel: CanvasLayer
var busy := false
var _placement_tween: Tween
var interaction: Node

func _ready() -> void:
	view = View.new()
	add_child(view)
	panel = LevelPanel.new()
	add_child(panel)
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view)
	interaction.socket_requested.connect(_try_socket)
	panel.piece_selected.connect(_select_piece)
	panel.observe_requested.connect(_observe)
	panel.overview_requested.connect(_overview)
	panel.transparent_requested.connect(_toggle_transparency)
	panel.plan_requested.connect(_toggle_plan)
	panel.joint_selected.connect(_choose_joint)
	panel.layout_selected.connect(func(id: String):
		if not busy: state.choose_layout(id))
	panel.undo_requested.connect(_undo)
	panel.repair_requested.connect(_repair)
	panel.restart_requested.connect(_restart)
	panel.check_requested.connect(_check)
	panel.return_requested.connect(_return_to_directory)
	panel.continue_requested.connect(_return_to_directory)
	panel.lesson_requested.connect(func():
		if not busy: learning.show_intro())
	state.changed.connect(_refresh)
	_refresh()
	learning = Learning.new()
	add_child(learning)
	learning.configure(2,view,panel,interaction)

func _select_piece(id: String) -> void:
	if busy: return
	panel.diagram.hide()
	view.inspected = false
	state.select(id)
	view.show_overview()

func _observe() -> void:
	if busy: return
	panel.diagram.hide()
	state.observe()
	view.inspect_selected()
	_refresh()

func _overview() -> void:
	if busy: return
	panel.diagram.hide()
	view.show_overview()
	_refresh()

func _toggle_transparency() -> void:
	if busy: return
	view.transparent = not view.transparent
	view.sync_state(state)

func _toggle_plan() -> void:
	if busy: return
	panel.diagram.visible = not panel.diagram.visible
	_refresh()

func _choose_joint(id: String) -> void:
	if busy: return
	state.choose_joint(id)
	panel.gallery.choose(id)

func _undo() -> void:
	_cancel_placement()
	panel.success_panel.hide()
	view.inspected = false
	state.undo()
	view.show_overview()

func _repair() -> void:
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

func _try_socket(id: String) -> Dictionary:
	if busy or learning.modal_open(): return Rules.result(false,"busy","等待当前木件装入。")
	if view.inspected or panel.diagram.visible:
		return Rules.result(false,"viewing","先返回船壳。")
	var result = state.attempt(id)
	panel.feedback(result.message,not result.ok)
	if result.ok:
		busy=true
		view.animate_place(id)
		_placement_tween=view.animations[id]
		_placement_tween.finished.connect(func():
			busy=false
			_placement_tween=null
			_refresh())
		_refresh()
	return result

func _check() -> void:
	if busy or not view.animations.is_empty() or state.placed.size()!=Rules.IDS.size(): return
	panel.diagram.hide()
	view.show_overview()
	var result = state.validate()
	panel.feedback(result.message,not result.ok)
	if result.ok:
		panel.success_panel.show()
		level_completed.emit()

func _cancel_placement() -> void:
	if is_instance_valid(_placement_tween): _placement_tween.kill()
	_placement_tween=null
	view.cancel_animations()
	busy=false
