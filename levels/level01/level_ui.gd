extends CanvasLayer
const StepGuide=preload("res://levels/shared/step_guide.gd")
var step_guide: Control
const ExhibitLayout=preload("res://shared/ui/exhibition_layout.gd")
## Main page identifies the current task; all candidate selection lives in the inspector.
signal undo_requested
signal restart_requested
signal return_requested
signal check_requested
signal lesson_requested
signal inspect_requested
const MainStyle=preload("res://shared/ui/workshop_ui_style.gd")
const Failure=preload("res://levels/shared/assembly_failure.gd")
const Controls=preload("res://levels/shared/chapter_ui.gd")
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Rules=preload("res://levels/level01/connection_rules.gd")
var root: Control
var main_chrome: Control
var main_header: PanelContainer
var main_sidebar: PanelContainer
var main_footer: PanelContainer
var step_label: Label
var stage_label: Label
var task_title: Label
var selection_label: Label
var feedback_label: Label
var count_label: Label
var return_button: Button
var inspect_button: Button
var undo_button: Button
var restart_button: Button
var check_button: Button
var lesson_button: Button
var success_panel: ColorRect
var success_close_button: Button
var failure_overlay: ColorRect
var failure_panel: PanelContainer
var failure_title: Label
var failure_restart_button: Button
var failure_return_button: Button

func _ready() -> void:
	layer=5
	root=Control.new()
	root.size=Vector2(1440,900)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=Friendly.make_theme(true)
	add_child(root)
	main_chrome=Control.new()
	main_chrome.name="MainChrome"
	main_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	main_chrome.theme=MainStyle.theme()
	root.add_child(main_chrome)
	var chrome=preload("res://levels/shared/chapter_chrome.gd").build(main_chrome,1,"龙骨立架","这件木料","船匠的小故事")
	main_header=chrome.header;main_sidebar=chrome.side;main_footer=chrome.footer
	task_title=chrome.task;stage_label=chrome.stage;step_label=chrome.step;selection_label=chrome.piece
	return_button=chrome.back;inspect_button=chrome.observe;lesson_button=chrome.story
	return_button.pressed.connect(func():return_requested.emit())
	inspect_button.pressed.connect(func():inspect_requested.emit())
	lesson_button.pressed.connect(func():lesson_requested.emit())
	var row: HBoxContainer=chrome.row
	var words: VBoxContainer=chrome.words
	count_label=Controls.label(words,"",16)
	MainStyle.label(count_label,16,500,true)
	feedback_label=Controls.label(words,"龙骨已就位。",21)
	MainStyle.label(feedback_label,21,500)
	feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	undo_button=Controls.button(row,"撤回上一组")
	undo_button.pressed.connect(func(): undo_requested.emit())
	restart_button=Controls.button(row,"重新搭建")
	restart_button.pressed.connect(func(): restart_requested.emit())
	check_button=Controls.button(row,"检查稳定")
	check_button.pressed.connect(func(): check_requested.emit())
	for button in [undo_button,restart_button,check_button]:
		button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size=Vector2(148,56)
		MainStyle.button(button,button==check_button)
	success_panel=preload("res://levels/shared/chapter_result.gd").new()
	root.add_child(success_panel)
	success_close_button=success_panel.restart_button
	success_panel.return_requested.connect(func():return_requested.emit())
	failure_overlay=Failure.new()
	root.add_child(failure_overlay)
	failure_panel=failure_overlay.panel
	failure_title=failure_overlay.title
	failure_restart_button=failure_overlay.restart_button
	failure_return_button=failure_overlay.return_button
	failure_overlay.restart_requested.connect(func(): restart_requested.emit())
	failure_overlay.return_requested.connect(func(): return_requested.emit())
	get_viewport().size_changed.connect(_fit_layout)
	tree_entered.connect(_fit_layout.call_deferred)
	_fit_layout()
	step_guide=StepGuide.new();main_chrome.add_child(step_guide)

func refresh(state, _joint: String, _length: String, busy := false, checking := false) -> void:
	var step: int=Rules.REPRESENTATIVE_IDS.find(state.selected)
	step_label.text="示范 %02d / 03" % (step+1)
	var task_names={"rib_l1":"先把船肋接上龙骨","bow":"接上龙骨的另一段","beam1":"再用横梁连起两侧船肋"}
	var ready: bool=state.progress_count()==3 and state.pending_group.is_empty()
	task_title.text="检查骨架是否稳固" if ready else str(task_names.get(state.selected,"观察当前连接"))
	stage_label.text="正在检查连接" if checking else ("正在逐件装配" if busy else ("构件已装齐" if ready else "当前要安装"))
	if state.failed:
		task_title.text="本关未通过，请重新开始"
		stage_label.text="连接出现松动"
	selection_label.text=Rules.SPECS[state.selected].label
	var progress_words: Array[String]=["龙骨已就位"]
	for id in Rules.REPRESENTATIVE_IDS:
		var name: String={"rib_l1":"船肋","bow":"龙骨端接","beam1":"横梁"}[id]
		var suffix: String="正在装配" if state.pending_group==id else ("待连接" if not state.placed.has(id) else ("已接好" if state.completed else "已试装"))
		progress_words.append(name+suffix)
	count_label.text=" · ".join(progress_words)
	undo_button.disabled=busy or state.failed or state.placement_order.is_empty()
	restart_button.disabled=busy or state.failed
	return_button.disabled=busy
	inspect_button.disabled=busy or state.failed
	inspect_button.text="看看这处连接" if state.placed.has(state.selected) else "看榫头，挑木料"
	lesson_button.disabled=busy or state.failed
	check_button.disabled=state.failed or busy or state.installed_count()!=Rules.BUILD_IDS.size() or not state.pending_group.is_empty()
	StepGuide.action(undo_button,not undo_button.disabled)

	if state.failed or state.completed or busy:step_guide.show_target()
	elif ready:step_guide.show_target(check_button)
	else:step_guide.show_target(inspect_button)

func show_failure() -> void:
	failure_overlay.open()

func hide_failure() -> void:
	failure_overlay.hide()

func show_feedback(message: String, error := false) -> void:
	Controls.feedback(feedback_label,message,error)

func _fit_layout() -> void:
	if not is_inside_tree():return
	var viewport_size:=get_viewport().get_visible_rect().size
	var factor:=ExhibitLayout.factor(viewport_size)
	ExhibitLayout.fit(root,viewport_size)
