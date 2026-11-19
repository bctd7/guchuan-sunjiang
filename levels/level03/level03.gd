extends "res://levels/chapter.gd"
## Workbench flow only; state validates, view animates, UI emits player intent.
const State = preload("res://levels/level03/level_state.gd")
const View = preload("res://levels/level03/rigging_view.gd")
const LevelPanel = preload("res://levels/level03/level_ui.gd")
var story: CanvasLayer
var state = State.new()
var view: Node3D
var panel: CanvasLayer
var interaction: Node

func _init() -> void:
	chapter_number = 3

func _build_workbench() -> void:
	panel = LevelPanel.new()
	add_child(panel)
	view = View.new()
	view.screen_surface=panel.main_viewport.get_parent()
	panel.main_viewport.add_child(view)
	interaction = panel.orbit
	panel.candidate_chosen.connect(_choose_candidate)
	panel.next_requested.connect(_next)
	interaction.assembly_requested.connect(_finish_drag)
	panel.undo_requested.connect(_undo)
	panel.restart_requested.connect(_restart)
	panel.turn_requested.connect(_turn)
	panel.setting_requested.connect(func(value: int):
		if not busy:
			state.adjust(value)
			panel.show_feedback("观察木件的方向，按住木件沿箭头拖动，松手试装。"))
	panel.launch_requested.connect(_launch)
	panel.return_requested.connect(_return_to_directory)
	panel.lesson_requested.connect(func():
		if not busy: learning.show_intro())
	story=preload("res://components/ui/story_overlay.gd").new()
	story.content={"name":"RiggingStory","title":"码头边的第一阵风",
		"illustration":preload("res://levels/level03/harbor_departure_illustration.gd"),"paragraphs":[
		"小船匠托起帆桁，师傅却先让她摸一摸桅脚。风吹在帆上，力会顺着横木传给桅杆，再传到船身。她蹲下来，确认桅座的两肩都已经坐实。",
		"挂帆时，布帆的重量把横木往下拉。小船匠从下面托起角撑，让三个方向的木件在角上合拢，再系紧帆索。",
		"到了船尾，她发现两处接头的任务不同：横撑要牢牢固定，圆舵轴却要留在孔里转动。舵叶随轴摆动，船在前进时就能改变方向。",
		"缆绳解开，小船匠先向左、再向右试舵。师傅看着稳住的桅影，终于朝码头挥了挥手。"]}
	add_child(story)
	story.root.visibility_changed.connect(func():
		panel.set_story_open(story.opened)
		request_navigation_update())
	panel.workspace.visibility_changed.connect(request_navigation_update)
	panel.magnifier.visibility_changed.connect(request_navigation_update)
	panel.story_requested.connect(func():
		if not busy:story.show_story(interaction, interaction.cancel))
	state.changed.connect(_refresh)
	state.changed.connect(update_completion)
	_refresh()
	panel.bind_view(view)
	learning.bind_source(view, panel, interaction, view.camera, interaction.cancel)
	panel.return_button.visible = not directory_managed
	panel.success_panel.visibility_changed.connect(request_navigation_update)
	panel.success_panel.bind(self,3,true)
	panel.success_panel.next_requested.connect(func():next_requested.emit())
	preload("res://audio/seating_audio.gd").bind_results(self,panel.success_panel)

func _choose_candidate(kind: String) -> void:
	if busy: return
	state.choose(kind)
	panel.show_feedback("已选 "+state.Rules.NAMES[kind]+"。按住木件沿箭头拖动。")

func _return_to_directory() -> void:
	if busy: return
	return_requested.emit()

func _refresh() -> void:
	interaction.cancel()
	view.sync_state(state)
	panel.refresh(state,busy)
func _finish_drag() -> void:
	var id: String = state.selected
	var released_pose: Transform3D = interaction.accepted_pose
	if busy or learning.modal_open() or story.opened or panel.magnifier.visible or not panel.inspected: return
	var outcome: Dictionary = state.attempt(id)
	panel.show_feedback(outcome.message,not outcome.ok)
	if outcome.code == "wrong_joint" and state.selected == "mast":
		view.show_failed_fit()
		panel.show_feedback("桅脚在方槽里晃动，桅杆歪了。换一只与槽底相合的脚。",true)
	elif outcome.code == "alignment" and state.setting >= 0:
		view.show_failed_fit()
	if outcome.ok:
		busy = true
		view.animate_place(id,released_pose.origin)
		panel.refresh(state,busy)
		await view.animations[state.selected].finished
		busy = false
		_refresh()
func _next() -> void:
	if busy or not state.placed.has(state.selected): return
	if state.stage_done(): state.next_workbench()
	else: state.next_piece()
func _undo() -> void:
	if busy: return
	panel.success_panel.hide()
	view.clear_launch()
	state.undo()
	panel.show_feedback("已撤回。")
func _restart() -> void:
	if busy: return
	panel.success_panel.hide()
	view.clear_launch()
	state.reset()
	panel.set_observed(false)
	panel.show_feedback("从龙骨上的夹头桅座重新搭建。")
func _turn(degrees: float) -> void:
	if busy: return
	if not state.turn_rudder(degrees): return
	panel.show_feedback("舵角 %+.0f°：圆轴在圆孔内转动，L 穿榫横撑保持固定。" % degrees)
	if state.ready_to_launch():
		panel.show_feedback("左右舵都能转动，船已准备下水。")

func _launch() -> void:
	if busy or not state.ready_to_launch() or panel.inspected or story.opened or learning.modal_open(): return
	busy = true
	panel.refresh(state,true)
	panel.show_feedback("解开缆绳，看看福船能否稳稳驶离码头。")
	await view.start_launch().finished
	busy = false
	state.finish_launch()
	panel.success_panel.open()

func _leave_workbench() -> void:
	interaction.cancel()
	story.close()
	panel.set_observed(false)

func is_completed() -> bool:
	return state.completed

func _workbench_modal_open() -> bool:
	return panel.success_panel.visible or story.opened or panel.inspected or panel.magnifier.visible
