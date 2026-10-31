extends Node3D
const BUILD_REVISION="alignment-section-20261028-r6"
## Coordinates three player demonstrations and explicitly labelled automatic repeats.
const State = preload("res://levels/level01/level_state.gd")
const Rules = preload("res://levels/level01/connection_rules.gd")
const Skeleton = preload("res://levels/level01/skeleton_view.gd")
const LevelPanel = preload("res://levels/level01/level_ui.gd")
const Touch = preload("res://levels/shared/socket_interaction.gd")
const Inspector = preload("res://levels/level01/joint_inspector.gd")
const Lengths=preload("res://levels/level01/length_geometry.gd")
const Learning = preload("res://shared/chapter_learning.gd")
const Story=preload("res://levels/level01/shipwright_story.gd")
var story: CanvasLayer
var learning: CanvasLayer
var state = State.new()
var view: Node3D
var panel: CanvasLayer
var interaction: Node
var inspector: CanvasLayer
var joint_type := ""
var tenon_length := ""
var busy := false
var checking_stability:=false
var last_feedback := ""
var _pending_review := ""
var _auto_tween: Tween
var _auto_queue: Array[String]=[]

func _ready() -> void:
	print("LEVEL01_BUILD ",BUILD_REVISION," ",ProjectSettings.globalize_path("res://"))
	view = Skeleton.new()
	add_child(view)
	panel = LevelPanel.new()
	add_child(panel)
	interaction = Touch.new()
	add_child(interaction)
	interaction.configure(view)
	inspector = Inspector.new()
	add_child(inspector)
	inspector.configure(view)
	inspector.joint_chosen.connect(func(id: String):
		joint_type=id
		_refresh())
	inspector.length_chosen.connect(func(id: String):
		tenon_length=id
		_refresh())
	inspector.lesson_requested.connect(_open_lessons)
	inspector.closed.connect(_begin_automatic)
	inspector.install_requested.connect(_install_from_observer)
	inspector.retry_requested.connect(_retry_from_observer)
	interaction.socket_requested.connect(_try_socket)
	panel.undo_requested.connect(_undo)
	panel.restart_requested.connect(_restart)
	panel.check_requested.connect(_check)
	panel.lesson_requested.connect(_open_story)
	panel.inspect_requested.connect(_inspect)
	state.changed.connect(_refresh)
	state.feedback.connect(func(message: String):
		last_feedback=message
		panel.show_feedback(message))
	_refresh()
	learning = Learning.new()
	add_child(learning)
	learning.configure(1,view,panel,interaction)
	story=Story.new()
	add_child(story)

func _inspect() -> void:
	if busy: return
	if state.placed.has(state.selected):
		var fitted: Dictionary=state.placed[state.selected]
		inspector.show_connection(state.selected,str(fitted.length),false,str(fitted.joint),true)
	else:
		inspector.show_connection(state.selected,tenon_length,false,joint_type)

func _try_socket(id: String, from_observer: bool = false, released_pose: Variant = null) -> Dictionary:
	if story.opened or learning.modal_open() or (inspector.visible and not from_observer): return Rules.result(false,"viewing","先返回骨架。")
	if busy: return Rules.result(false,"assembling","正在自动补齐同构木件，请观察动画。")
	if joint_type.is_empty():
		panel.show_feedback("先点“观察并选择榫型”，看清真实榫头与槽口后再试装。",true)
		return Rules.result(false,"joint_unselected","请先观察并选择榫型。")
	if tenon_length.is_empty():
		panel.show_feedback("打开观察页，根据槽口和刻度选择木料 A/B/C，再返回试装。",true)
		return Rules.result(false,"length_unselected","请先观察并选择木料长度。")
	var piece: String=state.selected
	view.prepare_place(piece,tenon_length,joint_type)
	var outcome: Dictionary=state.attempt_place(piece,id,joint_type,tenon_length)
	panel.show_feedback(str(outcome.message),not outcome.ok)
	if outcome.ok:
		busy=true
		_pending_review=piece
		view.animate_place(piece,tenon_length,joint_type)
		_refresh()
		inspector.show_connection(piece,tenon_length,true,joint_type,false,released_pose)
	else:
		view.discard_prepared_place(piece)
		_refresh()
	return outcome

func _install_from_observer() -> void:
	if not inspector.opened or not inspector.observation_mode: return
	var outcome: Dictionary=_try_socket(state.selected,true,inspector.orbit.accepted_pose)
	if not outcome.ok: inspector.reject_install(str(outcome.message))

func _retry_from_observer() -> void:
	if not inspector.opened or inspector.is_animating: return
	_undo()
	_inspect()

func _begin_automatic() -> void:
	if _pending_review.is_empty():
		if not joint_type.is_empty() and not tenon_length.is_empty() and not state.placed.has(state.selected):
			panel.show_feedback("已挑好%s的木料%s。回到观察页，按住木料拖向榫槽后松手。"%[Rules.JOINT_LABELS[joint_type],{"long":"A","short":"B","correct":"C"}[tenon_length]])
		return
	var representative:=_pending_review
	_pending_review=""
	if state.pending_group!=representative: return
	view.show_automatic_overview([representative]+Rules.AUTO_GROUPS[representative],str(state.placed[representative].length),str(state.placed[representative].joint))
	panel.show_feedback("手动示范完成。现在自动补齐同构木件，请观察完整骨架。")
	_auto_queue.clear()
	for batch in Rules.AUTO_BATCHES[representative]:
		for id in batch: _auto_queue.append(id)
	# Wait for actual movement, including when the player closes the review early.
	if view.animations.has(representative):
		view.animations[representative].finished.connect(_next_automatic.bind(representative),CONNECT_ONE_SHOT)
	else:
		_next_automatic(representative)

func _next_automatic(representative: String) -> void:
	if not busy or state.pending_group!=representative: return
	if _auto_queue.is_empty():
		_finish_automatic()
		return
	var id: String=_auto_queue.pop_front()
	_place_auto_batch(representative,[id])
	if view.animations.has(id):
		_auto_tween=view.animations[id]
		_auto_tween.finished.connect(_next_automatic.bind(representative),CONNECT_ONE_SHOT)

func _place_auto_batch(representative: String, ids: Array) -> void:
	if state.pending_group!=representative: return
	var names: Array[String]=[]
	for id in ids:
		view.prepare_place(id,str(state.placed[representative].length),str(state.placed[representative].joint))
		var result: Dictionary=state.place_automatic(id)
		if not result.ok:
			_cancel_automatic()
			state.undo()
			panel.show_feedback("自动补齐中断，已取回本组，请重新示范。",true)
			return
		view.animate_place(id,str(state.placed[id].length),str(state.placed[id].joint))
		names.append(Rules.SPECS[id].label)
	panel.show_feedback("自动装配（非手动步骤）："+"、".join(names))

func _finish_automatic() -> void:
	var result: Dictionary=state.finish_automatic()
	busy=false
	_auto_tween=null
	if not result.ok:
		state.undo()
		panel.show_feedback(result.message,true)
	else:
		for id in Rules.REPRESENTATIVE_IDS:
			if not state.placed.has(id):
				state.select_piece(id)
				break
		joint_type=""
		tenon_length=""
		panel.show_feedback("构件已装齐，点“检查稳定”看看连接是否牢靠。" if state.progress_count()==3 else "同类构件已装好。接着观察下一处连接。")
	_refresh()

func _cancel_automatic() -> void:
	checking_stability=false
	_pending_review=""
	_auto_queue.clear()
	if is_instance_valid(_auto_tween): _auto_tween.kill()
	_auto_tween=null
	view.cancel_animations()
	busy=false

func _refresh() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(view): return
	panel.refresh(state,joint_type,tenon_length,busy,checking_stability)
	view.sync_state(state.placed,state.stage(),state.selected)

func _undo() -> void:
	_cancel_automatic()
	inspector.close()
	panel.success_panel.hide()
	state.undo()
	joint_type=""
	tenon_length=""
	_refresh()
	view.show_overview()

func _restart() -> void:
	_cancel_automatic()
	inspector.close()
	panel.success_panel.hide()
	interaction.cancel()
	joint_type=""
	tenon_length=""
	state.reset()
	view.reset_view()

func _check() -> void:
	if busy or not state.pending_group.is_empty() or not view.animations.is_empty() or not view.planned_insertions.is_empty() or state.installed_count()!=Rules.BUILD_IDS.size(): return
	var outcome: Dictionary=state.validate_structure()
	panel.show_feedback(outcome.message,not outcome.ok)
	if outcome.ok:
		view.show_overview(true)
		panel.success_panel.show()
	elif outcome.code in ["unstable_length","unstable_fit"]:
		busy=true
		checking_stability=true
		var motion: Tween=view.show_instability(state.placed)
		panel.refresh(state,joint_type,tenon_length,busy,checking_stability)
		motion.finished.connect(func():
			busy=false
			checking_stability=false
			_refresh())

func _open_story() -> void:
	if busy: return
	story.show_story(interaction)

func _open_lessons() -> void:
	if busy: return
	inspector.close()
	learning.show_intro()
