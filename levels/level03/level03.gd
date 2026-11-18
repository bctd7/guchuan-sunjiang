extends Node3D
signal next_requested
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
var story: CanvasLayer
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
	view.screen_surface=panel.main_viewport.get_parent()
	panel.main_viewport.add_child(view)
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view)
	interaction.socket_requested.connect(_try_socket)
	panel.candidate_chosen.connect(_choose_candidate)
	panel.next_requested.connect(_next)
	panel.socket_requested.connect(_try_socket)
	panel.undo_requested.connect(_undo)
	panel.restart_requested.connect(_restart)
	panel.turn_requested.connect(_turn)
	panel.return_requested.connect(_return_to_directory)
	panel.lesson_requested.connect(func():
		if not busy: learning.show_intro())
	story=preload("res://levels/shared/story_overlay.gd").new()
	story.content={"name":"RiggingStory","title":"帆与舵的故事（内容待补充）","paragraphs":[
		"第三关小故事占位内容。本页沿用前两关的故事卡片，正式内容和配图将在后续替换。",
		"故事主题：桅杆与帆桁。此处预留船匠故事的开篇段落。",
		"故事主题：船尾的舵。此处预留角色对话和配图说明。",
		"此处预留故事结尾。当前页面用于检查阅读、滚动和返回搭建流程。"]}
	add_child(story)
	panel.story_requested.connect(func():
		if not busy:story.show_story(interaction))
	state.changed.connect(_refresh)
	state.changed.connect(func(): progress_changed.emit())
	_refresh()
	panel.bind_view(view)
	learning = Learning.new()
	add_child(learning)
	learning.configure(3,view,panel,interaction)
	panel.success_panel.bind(self,3,true)
	panel.success_panel.next_requested.connect(func():next_requested.emit())
	preload("res://shared/seating_audio.gd").bind_results(self,panel.success_panel)

func _choose_candidate(kind: String) -> void:
	if busy: return
	state.choose(kind)
	panel.show_feedback("已选 "+state.Rules.NAMES[kind]+"。")

func _return_to_directory() -> void:
	if busy: return
	return_requested.emit()

func _refresh() -> void:
	view.sync_state(state)
	panel.refresh(state,busy)
func _try_socket(id: String) -> Dictionary:
	if busy or learning.modal_open() or story.opened or panel.magnifier.visible or not panel.inspected: return {"ok":false,"code":"busy","message":"当前不能安装。"}
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
	panel.show_feedback("")
func _undo() -> void:
	if busy: return
	panel.success_panel.hide()
	_completion_emitted = false
	state.undo()
	panel.show_feedback("已撤回。")
func _restart() -> void:
	if busy: return
	panel.success_panel.hide()
	_completion_emitted = false
	state.reset()
	panel.set_observed(false)
	panel.show_feedback("回到桅座抹头；大边预先固定，角腿下方留有装配空间。")
func _turn(degrees: float) -> void:
	if busy: return
	if not state.turn_rudder(degrees): return
	panel.show_feedback("舵角 %+.0f°：圆轴在圆孔内转动，L 穿榫横撑保持固定。" % degrees)
	if state.completed and not _completion_emitted:
		_completion_emitted = true
		panel.success_panel.show()
		level_completed.emit()

# Campaign owns lifecycle: directory return discards the chapter instance.
func enter() -> void:
	learning.show_intro()

func leave() -> void:
	interaction.cancel()
	story.close()
	panel.set_observed(false)

func is_completed() -> bool:
	return state.completed

func navigation_status() -> Dictionary:
	return {"modal_open": panel.success_panel.visible or learning.modal_open() or story.opened or panel.inspected or panel.magnifier.visible, "can_leave": not busy, "intro_open": learning.opened}
