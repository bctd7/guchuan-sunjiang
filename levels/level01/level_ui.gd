extends CanvasLayer
## Main page identifies the current task; all candidate selection lives in the inspector.
signal undo_requested
signal restart_requested
signal check_requested
signal lesson_requested
signal inspect_requested
const Controls=preload("res://levels/shared/chapter_ui.gd")
const Friendly=preload("res://demo/friendly_theme.gd")
const Rules=preload("res://levels/level01/connection_rules.gd")
var root: Control
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
	var top=Controls.panel(root,Rect2(20,18,1400,82))
	var heading=HBoxContainer.new()
	heading.add_theme_constant_override("separation",36)
	top.add_child(heading)
	var titles=VBoxContainer.new()
	heading.add_child(titles)
	Controls.label(titles,"古船榫匠 / 第一关",16)
	Controls.label(titles,"龙骨立架",28)
	var task=VBoxContainer.new()
	task.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(task)
	Controls.label(task,"开工吧",16)
	task_title=Controls.label(task,"",23)
	var side=Controls.panel(root,Rect2(20,144,310,405))
	var stack=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	side.add_child(stack)
	stage_label=Controls.label(stack,"",23)
	Controls.label(stack,"这件木料",18)
	selection_label=Controls.label(stack,"",24)
	selection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var instruction=Controls.label(stack,"先到观察页，比一比榫头和槽口。\n选好后抓住木料，沿箭头往槽内推。",18)
	instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	inspect_button=Controls.button(stack,"看榫头，挑木料")
	inspect_button.pressed.connect(func(): inspect_requested.emit())
	lesson_button=Controls.button(stack,"船匠的小故事")
	lesson_button.pressed.connect(func(): lesson_requested.emit())
	var note=Controls.label(stack,"每种连接亲手装一处，其余同类构件会逐件装好。",17)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var footer=Controls.panel(root,Rect2(20,770,1400,110))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	footer.add_child(row)
	var words=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(words)
	count_label=Controls.label(words,"",18)
	feedback_label=Controls.label(words,"龙骨已摆好。先进入观察页，看看船肋怎样接入槽口。",22)
	feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	undo_button=Controls.button(row,"撤回上一组")
	undo_button.pressed.connect(func(): undo_requested.emit())
	restart_button=Controls.button(row,"重新搭建")
	restart_button.pressed.connect(func(): restart_requested.emit())
	check_button=Controls.button(row,"检查稳定")
	check_button.pressed.connect(func(): check_requested.emit())
	for button in [undo_button,restart_button,check_button]:
		button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size=Vector2(128,52)
	guidance=Controls.label(root,"",19)
	guidance.position=Vector2(365,113)
	guidance.add_theme_color_override("font_color",Color("fff4db"))
	guidance.add_theme_color_override("font_shadow_color",Color("302c25"))
	guidance.add_theme_constant_override("shadow_offset_x",1)
	guidance.add_theme_constant_override("shadow_offset_y",2)
	guidance.add_theme_color_override("font_outline_color",Color("403b32"))
	guidance.add_theme_constant_override("outline_size",4)
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

func refresh(state, _joint: String, _length: String, busy := false, checking := false) -> void:
	var step: int=Rules.REPRESENTATIVE_IDS.find(state.selected)
	var task_names={"rib_l1":"先把船肋接上龙骨","bow":"接上龙骨的另一段","beam1":"再用横梁连起两侧船肋"}
	var ready: bool=state.progress_count()==3 and state.pending_group.is_empty()
	task_title.text="检查骨架是否稳固" if ready else str(task_names.get(state.selected,"观察当前连接"))
	stage_label.text="正在检查连接" if checking else ("正在逐件装配" if busy else ("构件已装齐" if ready else "当前要安装"))
	selection_label.text=Rules.SPECS[state.selected].label
	var progress_words: Array[String]=["龙骨已就位"]
	for id in Rules.REPRESENTATIVE_IDS:
		var name: String={"rib_l1":"船肋","bow":"龙骨端接","beam1":"横梁"}[id]
		var suffix: String="正在装配" if state.pending_group==id else ("待连接" if not state.placed.has(id) else ("已接好" if Rules.connection_correct(id,state.placed) else "待调整"))
		progress_words.append(name+suffix)
	count_label.text=" · ".join(progress_words)
	undo_button.disabled=state.placement_order.is_empty()
	inspect_button.disabled=busy
	inspect_button.text="看看这处连接" if state.placed.has(state.selected) else "看榫头，挑木料"
	lesson_button.disabled=busy
	check_button.disabled=busy or state.installed_count()!=Rules.BUILD_IDS.size() or not state.pending_group.is_empty()
	guidance.text="看看连接处有没有松动。" if checking else ("同类木料正依次装入，留意它们的方向。" if busy else "先比一比榫头与槽口，再动手试装。")

func show_feedback(message: String, error := false) -> void:
	Controls.feedback(feedback_label,message,error)
