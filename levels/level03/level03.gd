extends Node3D
signal progress_changed
## Workbench flow only; state validates, view animates, UI emits player intent.
signal level_completed
signal return_requested
const State = preload("res://levels/level03/level_state.gd")
const View = preload("res://levels/level03/rigging_view.gd")
const LevelPanel = preload("res://levels/level03/level_ui.gd")
const Touch = preload("res://levels/shared/socket_interaction.gd")
const Learning = preload("res://levels/shared/teaching_portal.gd")
var learning: CanvasLayer
var state = State.new()
var view: Node3D
var panel: CanvasLayer
var interaction: Node
var busy := false
var _completion_emitted := false
func _ready() -> void:
	panel = LevelPanel.new()
	add_child(panel)
	view = View.new()
	panel.main_viewport.add_child(view)
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view)
	interaction.socket_requested.connect(_try_socket)
	panel.candidate_chosen.connect(_choose_candidate)
	panel.next_requested.connect(_next)
	panel.inspect_requested.connect(view.toggle_closeup)
	panel.undo_requested.connect(_undo)
	panel.restart_requested.connect(_restart)
	panel.turn_requested.connect(_turn)
	panel.return_requested.connect(_return_to_directory)
	panel.lesson_requested.connect(func():
		if not busy: learning.show_intro())
	state.changed.connect(_refresh)
	state.changed.connect(func(): progress_changed.emit())
	_refresh()
	learning = Learning.new()
	add_child(learning)
	learning.configure(3,view,panel,interaction)

func _choose_candidate(kind: String) -> void:
	if busy: return
	state.choose(kind)
	panel.show_feedback("已选 "+state.Rules.NAMES[kind]+"。观察实际榫头，再点绿色槽口试装。")

func _return_to_directory() -> void:
	if busy: return
	return_requested.emit()

func _refresh() -> void:
	view.sync_state(state)
	panel.refresh(state,busy)
func _try_socket(id: String) -> Dictionary:
	if busy or learning.modal_open(): return {"ok":false,"code":"busy","message":"木件正在装入。"}
	var outcome: Dictionary = state.attempt(id)
	panel.show_feedback(outcome.message,not outcome.ok)
	if outcome.ok:
		busy = true
		view.animate_place(state.selected)
		panel.refresh(state,busy)
		await view.animations[state.selected].finished
		busy = false
		_refresh()
	return outcome
func _next() -> void:
	if busy or not state.placed.has(state.selected): return
	if state.stage_done(): state.next_workbench()
	else: state.next_piece()
	panel.show_feedback("先看候选端部与真实槽口，再选择。")
func _undo() -> void:
	if busy: return
	panel.success_panel.hide()
	_completion_emitted = false
	state.undo()
	panel.show_feedback("已撤回，可重新观察候选并试装。")
func _restart() -> void:
	if busy: return
	panel.success_panel.hide()
	_completion_emitted = false
	state.reset()
	panel.show_feedback("回到桅座抹头；大边预先固定，角腿下方留有装配空间。")
func _turn(degrees: float) -> void:
	if busy: return
	if not state.turn_rudder(degrees): return
	panel.show_feedback("舵角 %+.0f°：圆轴在圆孔内转动，L 穿榫横撑保持固定。" % degrees)
	if state.completed and not _completion_emitted:
		_completion_emitted = true
		panel.success_panel.show()
		level_completed.emit()

# Campaign contract. Reentry keeps this instance and its gameplay state.
func enter() -> void:
	learning.show_intro()

func leave() -> void:
	interaction.cancel()

func is_completed() -> bool:
	return state.completed

func navigation_status() -> Dictionary:
	return {"modal_open": learning.modal_open(), "can_leave": not busy}
