extends CanvasLayer
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
var guidance: Label
var feedback_label: Label
var count_label: Label
var inspect_button: Button
var undo_button: Button
var restart_button: Button
var check_button: Button
var lesson_button: Button
var success_panel: PanelContainer
var success_close_button: Button
var failure_overlay: ColorRect
var failure_panel: PanelContainer
var failure_title: Label
var failure_restart_button: Button
var failure_return_button: Button
# Compatibility inventories intentionally empty: no duplicated selectors.
var piece_buttons: Dictionary={}
var joint_buttons: Dictionary={}
var length_buttons: Dictionary={}

func _ready() -> void:
	layer=5
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=Friendly.make_theme(true)
	add_child(root)
	main_chrome=Control.new()
	main_chrome.name="MainChrome"
	main_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	main_chrome.theme=MainStyle.theme()
	root.add_child(main_chrome)
	var top=Controls.panel(main_chrome,Rect2(20,18,1400,82))
	main_header=top
	var header_style=MainStyle.card()
	header_style.content_margin_top=10
	header_style.content_margin_bottom=10
	top.add_theme_stylebox_override("panel",header_style)
	var heading=HBoxContainer.new()
	heading.add_theme_constant_override("separation",36)
	top.add_child(heading)
	var titles=VBoxContainer.new()
	heading.add_child(titles)
	titles.add_theme_constant_override("separation",2)
	var chapter=Controls.label(titles,"古船榫匠 / 第一关",14)
	MainStyle.label(chapter,14,500,true)
	var level_title=Controls.label(titles,"龙骨立架",28)
	MainStyle.label(level_title,28,600)
	var task=VBoxContainer.new()
	task.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(task)
	task.add_theme_constant_override("separation",4)
	var task_caption=Controls.label(task,"当前任务",14)
	MainStyle.label(task_caption,14,500,true)
	task_title=Controls.label(task,"",23)
	MainStyle.label(task_title,23,500)
	var navigation_space=Control.new()
	navigation_space.custom_minimum_size.x=180
	navigation_space.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(navigation_space)
	var side=Controls.panel(main_chrome,Rect2(20,144,310,405))
	main_sidebar=side
	side.add_theme_stylebox_override("panel",MainStyle.card())
	var stack=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	side.add_child(stack)
	var status_row=HBoxContainer.new()
	status_row.add_theme_constant_override("separation",12)
	stack.add_child(status_row)
	stage_label=Controls.label(status_row,"",14)
	stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	MainStyle.label(stage_label,14,500,true)
	step_label=Controls.label(status_row,"",14)
	MainStyle.label(step_label,14,600)
	var selected_words=VBoxContainer.new()
	selected_words.add_theme_constant_override("separation",4)
	stack.add_child(selected_words)
	var piece_caption=Controls.label(selected_words,"这件木料",14)
	MainStyle.label(piece_caption,14,400,true)
	selection_label=Controls.label(selected_words,"",24)
	MainStyle.label(selection_label,24,600)
	selection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var instruction=Controls.label(stack,"先观察榫头与槽口，再挑选木料。\n抓住木料，沿箭头推入槽内。",17)
	instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_constant_override("line_spacing",4)
	MainStyle.label(instruction,17)
	inspect_button=Controls.button(stack,"看榫头，挑木料")
	inspect_button.custom_minimum_size.y=60
	MainStyle.button(inspect_button,true)
	inspect_button.pressed.connect(func(): inspect_requested.emit())
	lesson_button=Controls.button(stack,"船匠的小故事")
	lesson_button.custom_minimum_size.y=52
	MainStyle.button(lesson_button)
	lesson_button.pressed.connect(func(): lesson_requested.emit())
	var note=Controls.label(stack,"每种连接亲手装一次，其余同类木料会逐件补齐。",16)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_constant_override("line_spacing",3)
	MainStyle.label(note,16,400,true)
	var footer=Controls.panel(main_chrome,Rect2(20,770,1400,110))
	main_footer=footer
	footer.add_theme_stylebox_override("panel",MainStyle.card())
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	footer.add_child(row)
	var words=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_theme_constant_override("separation",6)
	count_label=Controls.label(words,"",16)
	MainStyle.label(count_label,16,500,true)
	feedback_label=Controls.label(words,"龙骨已摆好。先进入观察页，看看船肋怎样接入槽口。",21)
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
	guidance=Controls.label(main_chrome,"",18)
	guidance.position=Vector2(365,112)
	MainStyle.label(guidance,18,500)
	var hint_style=MainStyle.card(12)
	hint_style.bg_color=Color(.99,.98,.94,.96)
	hint_style.set_corner_radius_all(9)
	hint_style.content_margin_top=6
	hint_style.content_margin_bottom=6
	hint_style.shadow_size=3
	hint_style.shadow_offset=Vector2(0,2)
	guidance.add_theme_stylebox_override("normal",hint_style)
	guidance.mouse_filter=Control.MOUSE_FILTER_IGNORE
	success_panel=Controls.panel(root,Rect2(470,245,710,380))
	var success=VBoxContainer.new()
	success.add_theme_constant_override("separation",18)
	success_panel.add_child(success)
	Controls.label(success,"第一关完成 · 龙骨立架成功！",30)
	Controls.label(success,"你完成了三种不同示范；七件同构木件自动补齐。\n固定龙骨与完整左右骨架已正确咬合。",23)
	Controls.label(success,"小小船匠知识",21)
	var facts=Controls.label(success,"半榫进入有底盲槽，透榫穿过通孔并露出背面。\n燕尾沿开放端滑入，宽头窄颈限制脱开方向。\n本关连接布置为教学设计，并非古船历史复原。",19)
	facts.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	success_close_button=Controls.button(success,"收起卡片 · 欣赏骨架")
	success_close_button.pressed.connect(func(): success_panel.hide())
	success_panel.hide()
	failure_overlay=Failure.new()
	root.add_child(failure_overlay)
	failure_panel=failure_overlay.panel
	failure_title=failure_overlay.title
	failure_restart_button=failure_overlay.restart_button
	failure_return_button=failure_overlay.return_button
	failure_overlay.restart_requested.connect(func(): restart_requested.emit())
	failure_overlay.return_requested.connect(func(): return_requested.emit())

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
	undo_button.disabled=state.failed or state.placement_order.is_empty()
	restart_button.disabled=state.failed
	inspect_button.disabled=busy or state.failed
	inspect_button.text="看看这处连接" if state.placed.has(state.selected) else "看榫头，挑木料"
	lesson_button.disabled=busy or state.failed
	check_button.disabled=state.failed or busy or state.installed_count()!=Rules.BUILD_IDS.size() or not state.pending_group.is_empty()
	guidance.text="看看连接处有没有松动。" if checking else ("同类木料正依次装入，留意它们的方向。" if busy else "先比一比榫头与槽口，再动手试装。")
	if state.failed: guidance.text="榫型或木料不合适，重新开始再试一次吧。"

func show_failure() -> void:
	failure_overlay.open()

func hide_failure() -> void:
	failure_overlay.hide()

func show_feedback(message: String, error := false) -> void:
	Controls.feedback(feedback_label,message,error)
