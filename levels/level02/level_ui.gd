extends CanvasLayer
const ZoomBar=preload("res://levels/shared/inspection_zoom_bar.gd")
## Overview presents the current task; a separate inspection page owns model choices.
const Magnifier=preload("res://levels/shared/model_magnifier.gd")
const Workspace=preload("res://levels/shared/inspection_workspace.gd")
const OpeningGallery=preload("res://levels/level02/opening_gallery.gd")
const OpeningReference=preload("res://levels/level02/opening_reference.gd")
const OpeningMeasure=preload("res://levels/level02/opening_measure_panel.gd")
const ObservationOrbit=preload("res://levels/shared/inspection_orbit.gd")
const Style=preload("res://shared/ui/workshop_ui_style.gd")
const Controls=preload("res://levels/shared/chapter_ui.gd")
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Failure=preload("res://levels/shared/assembly_failure.gd")
const Gallery=preload("res://levels/level02/joint_gallery.gd")
const DragGuide=preload("res://levels/level02/drag_guide.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
signal bulkhead_requested
signal lesson_requested
signal group_selected(index: int)
signal next_piece_requested
signal joint_selected(id: String)
signal opening_selected(id: String)
signal prepare_observation_requested
signal reset_observation_requested
signal layout_selected(id: String)
signal observe_requested
signal overview_requested
signal transparent_requested
signal zoom_requested(factor: float)
signal magnify_requested(source: Control,title: String)
signal undo_requested
signal restart_requested
signal check_requested
signal return_requested
signal continue_requested
var magnifier: Control
var zoom_in_button: Button
var zoom_out_button: Button
var zoom_reset_button: Button
var zoom_label: Label
var root_control: Control
var main_chrome: Control
var workspace: Control
var local_viewport: SubViewport
var observation_orbit: Control
var opening_gallery: Control
var opening_measure: Control
var opening_buttons: Dictionary={}
var prepare_observation_button: Button
var reset_observation_button: Button
var options_panel: VBoxContainer
var current_view: Node3D
var observer_chrome: Control
var main_header: PanelContainer
var main_sidebar: PanelContainer
var main_footer: PanelContainer
var inventory_panel: PanelContainer
var inventory_button: Button
var inventory_close_button: Button
var inventory_open: bool:
	get: return is_instance_valid(inventory_panel) and inventory_panel.visible
var group_buttons: Dictionary={}
var next_piece_button: Button
var joint_buttons: Dictionary={}
var layout_buttons: Dictionary={}
var observe_button: Button
var observer_undo_button: Button
var overview_button: Button
var transparent_button: Button
var undo_button: Button
var restart_button: Button
var check_button: Button
var return_button: Button
var continue_button: Button
var bulkhead_button: Button
var lesson_button: Button
var feedback_label: Label
var observer_instruction: Label
var observer_feedback: Label
var title_label: Label
var header_label: Label
var task_label: Label
var selection_label: Label
var stage_label: Label
var observation_label: Label
var layout_title: Label
var layout_note: Label
var drag_guide: Control
var gallery: Control
var success_panel: PanelContainer
var failure_overlay: ColorRect
var failure_restart_button: Button
var failure_return_button: Button
var _shade: ColorRect
var current
var _inspected := false
func _ready() -> void:
	layer=5
	root_control=Control.new()
	root_control.size=Vector2(1440,900)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_control.theme=Friendly.make_theme(true)
	add_child(root_control)
	drag_guide=DragGuide.new()
	root_control.add_child(drag_guide)
	main_chrome=_surface()
	main_chrome.theme=Style.theme()
	workspace=Workspace.new()
	root_control.add_child(workspace)
	observer_chrome=workspace
	_build_overview()
	_build_observer()
	_build_modals()
	magnifier=Magnifier.new();root_control.add_child(magnifier)
	get_viewport().size_changed.connect(_fit_layout)
	tree_entered.connect(_fit_layout.call_deferred)
	_fit_layout()
	visibility_changed.connect(_sync_local_scene)
func _surface() -> Control:
	var control:=Control.new()
	control.size=Vector2(1440,900)
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_control.add_child(control)
	return control
func _card(parent: Node,rect: Rect2) -> PanelContainer:
	var card=Controls.panel(parent,rect)
	card.add_theme_stylebox_override("panel",Style.card())
	return card
func _label(parent: Node,text: String,size_value:=18,weight:=400,muted:=false) -> Label:
	var label=Controls.label(parent,text,size_value)
	Style.label(label,size_value,weight,muted)
	return label
func _button(parent: Node,text: String,primary:=false) -> Button:
	var button=Controls.button(parent,text)
	Style.button(button,primary)
	return button
func _build_overview() -> void:
	main_header=_card(main_chrome,Rect2(20,18,1400,82))
	var header_style=Style.card();header_style.content_margin_top=10;header_style.content_margin_bottom=10
	main_header.add_theme_stylebox_override("panel",header_style)
	var heading:=HBoxContainer.new()
	heading.add_theme_constant_override("separation",36)
	main_header.add_child(heading)
	var titles:=VBoxContainer.new()
	titles.add_theme_constant_override("separation",2)
	heading.add_child(titles)
	_label(titles,"古船榫匠 / 第二关",14,500,true)
	header_label=_label(titles,"船板合壳",28,600)
	var task:=VBoxContainer.new()
	task.add_theme_constant_override("separation",4)
	task.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(task)
	_label(task,"当前任务",14,500,true)
	task_label=_label(task,"",23,500)
	var navigation_space:=Control.new()
	navigation_space.custom_minimum_size.x=180
	heading.add_child(navigation_space)
	return_button=_button(main_chrome,"‹ 关卡目录")
	return_button.position=Vector2(1244,34)
	return_button.size=Vector2(160,48)
	return_button.pressed.connect(func():return_requested.emit())
	main_sidebar=_card(main_chrome,Rect2(20,144,310,405))
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	main_sidebar.add_child(stack)
	var status:=HBoxContainer.new()
	stack.add_child(status)
	stage_label=_label(status,"当前要安装",14,500,true)
	stage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var selected_words:=VBoxContainer.new();selected_words.add_theme_constant_override("separation",4);stack.add_child(selected_words)
	_label(selected_words,"这组木料",14,400,true)
	selection_label=_label(selected_words,"",24,600)
	var instruction=_label(stack,"先观察开口与槽口，再挑选木料。\n抓住木料，沿箭头推入槽内。",17)
	instruction.add_theme_constant_override("line_spacing",4)
	observe_button=_button(stack,"看榫头，挑木料",true)
	observe_button.custom_minimum_size.y=60
	observe_button.pressed.connect(func():observe_requested.emit())
	bulkhead_button=_button(stack,"水密隔舱小课堂")
	bulkhead_button.custom_minimum_size.y=52
	bulkhead_button.pressed.connect(func():bulkhead_requested.emit())
	var note=_label(stack,"同类木料一次示范，依次补齐。\n扣合撑分别侧推、下压。",16,400,true)
	note.add_theme_constant_override("line_spacing",3)
	main_footer=_card(main_chrome,Rect2(20,770,1400,110))
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	main_footer.add_child(row)
	var words:=VBoxContainer.new()
	words.add_theme_constant_override("separation",6)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(words)
	inventory_button=Button.new()
	inventory_button.flat=true
	for state in ["normal","hover","pressed","hover_pressed"]:inventory_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus:=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.border_color=Color("7b956e");focus.set_border_width_all(2)
	inventory_button.add_theme_stylebox_override("focus",focus)
	inventory_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	inventory_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	inventory_button.add_theme_font_override("font",Style.font(500))
	inventory_button.add_theme_font_size_override("font_size",16)
	inventory_button.add_theme_color_override("font_color",Style.MUTED)
	words.add_child(inventory_button)
	inventory_button.pressed.connect(func():
		inventory_panel.show()
		_shade.show())
	feedback_label=_label(words,"底列船板待安装。",21,500)
	feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	undo_button=_button(row,"撤回上一步")
	undo_button.pressed.connect(func():undo_requested.emit())
	restart_button=_button(row,"重新搭建")
	restart_button.pressed.connect(func():restart_requested.emit())
	check_button=_button(row,"海浪测试",true)
	check_button.pressed.connect(func():check_requested.emit())
	for button in [undo_button,restart_button,check_button]:
		button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size=Vector2(148,56)
	check_button.hide() # The whole-hull trial starts automatically.
func _build_observer() -> void:
	title_label=workspace.title
	observer_instruction=workspace.explanation
	lesson_button=workspace.button(workspace.header,"本关榫卯讲解")
	lesson_button.pressed.connect(func():lesson_requested.emit())
	observer_undo_button=workspace.button(workspace.header,"取回调整")
	observer_undo_button.pressed.connect(func():undo_requested.emit())
	next_piece_button=workspace.button(workspace.header,"接着铺另一块")
	next_piece_button.pressed.connect(func():next_piece_requested.emit())
	overview_button=workspace.button(workspace.header,"返回船架")
	overview_button.pressed.connect(func():overview_requested.emit())
	gallery=Gallery.new();workspace.candidates.add_child(gallery);joint_buttons=gallery.buttons
	gallery.chosen.connect(func(id: String):joint_selected.emit(id))
	gallery.inspect_requested.connect(func(id: String):magnify_requested.emit(gallery.previews[id],Rules.JOINT_NAMES[id]+" · "+Gallery.DETAILS[id]))
	options_panel=workspace.options
	observation_label=workspace.label(options_panel,"三件同型木料，缺口形状不同。",18)
	observation_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	observation_label.hide()
	opening_measure=OpeningMeasure.new();options_panel.add_child(opening_measure)
	opening_gallery=OpeningGallery.new();options_panel.add_child(opening_gallery);opening_buttons=opening_gallery.buttons
	reset_observation_requested.connect(opening_gallery.reset_view)
	opening_gallery.chosen.connect(func(id: String):opening_selected.emit(id))
	opening_gallery.inspect_requested.connect(func(id: String):magnify_requested.emit(opening_gallery.previews[id],"开口候选 · 木料 "+id))
	layout_title=workspace.label(options_panel,"板端位置",18)
	layout_note=workspace.label(options_panel,"",16);layout_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var positions:=HBoxContainer.new();options_panel.add_child(positions)
	positions.hide()
	for id in ["A","B"]:
		var button=workspace.button(positions,"端缝靠左" if id=="A" else "端缝靠右")
		button.toggle_mode=true;button.custom_minimum_size=Vector2(140,44);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		Workspace.neutral_selection(button);layout_buttons[id]=button;button.pressed.connect(func():layout_selected.emit(id))
	local_viewport=SubViewport.new();local_viewport.own_world_3d=true;local_viewport.size=Vector2i(1000,490);local_viewport.gui_disable_input=true;local_viewport.msaa_3d=Viewport.MSAA_4X
	workspace.viewport_container.add_child(local_viewport)
	observation_orbit=ObservationOrbit.new();workspace.stage_surface.add_child(observation_orbit)
	observation_orbit.mouse_filter=Control.MOUSE_FILTER_IGNORE;observation_orbit.set_process_input(false)
	drag_guide.reparent(workspace.stage_surface,false)
	drag_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	observer_feedback=workspace.status
	prepare_observation_button=workspace.button(workspace.actions,"先选榫头")
	prepare_observation_button.pressed.connect(func():prepare_observation_requested.emit())
	transparent_button=workspace.button(workspace.actions,"看槽口");transparent_button.toggle_mode=true
	transparent_button.pressed.connect(func():transparent_requested.emit())
	reset_observation_button=workspace.button(workspace.actions,"重新观察")
	reset_observation_button.pressed.connect(func():reset_observation_requested.emit())
	var zoom_bar:=ZoomBar.new();workspace.stage_surface.add_child(zoom_bar)
	zoom_out_button=zoom_bar.zoom_out;zoom_label=zoom_bar.percentage;zoom_in_button=zoom_bar.zoom_in;zoom_reset_button=zoom_bar.reset_button
	zoom_bar.zoom_requested.connect(func(factor: float):zoom_requested.emit(factor))
	zoom_bar.reset_requested.connect(func():reset_observation_requested.emit())
	workspace.note.text="拖空白处旋转 · 双指、滚轮或按钮缩放 · 候选可放大查看"

func bind_view(view: Node3D) -> void:
	current_view=view
func _build_modals() -> void:
	_shade=ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color=Color(.15,.18,.13,.38)
	root_control.add_child(_shade)
	_shade.hide()
	inventory_panel=_card(root_control,Rect2(350,200,560,422))
	var list:=VBoxContainer.new()
	list.add_theme_constant_override("separation",6)
	inventory_panel.add_child(list)
	var header:=HBoxContainer.new()
	list.add_child(header)
	_label(header,"三组搭建进度",22,600).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inventory_close_button=_button(header,"收起")
	inventory_close_button.pressed.connect(func():
		inventory_panel.hide()
		_shade.hide())
	for index in Rules.GROUPS.size():
		var button=_button(list,Rules.GROUP_LABELS[index])
		button.custom_minimum_size.y=44
		group_buttons[index]=button
		button.pressed.connect(func():
			inventory_panel.hide()
			_shade.hide()
			group_selected.emit(index))
	inventory_panel.hide()
	success_panel=_card(root_control,Rect2(470,245,740,390))
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	success_panel.add_child(v)
	_label(v,"第二关完成 · 船板合壳成功！",28,600)
	_label(v,"三列端缝错开，支撑与隔舱就位。\n海浪拂过，看看你亲手搭好的船壳。",20)
	continue_button=_button(v,"继续 / 返回关卡目录",true)
	continue_button.pressed.connect(func():continue_requested.emit())
	var close=_button(v,"收起卡片 · 欣赏船壳")
	close.pressed.connect(func():success_panel.hide())
	var science=_button(v,"了解水密隔舱")
	science.pressed.connect(func():bulkhead_requested.emit())
	success_panel.hide()
	failure_overlay=Failure.new()
	root_control.add_child(failure_overlay)
	failure_restart_button=failure_overlay.restart_button
	failure_return_button=failure_overlay.return_button
	failure_overlay.restart_requested.connect(func():restart_requested.emit())
	failure_overlay.return_requested.connect(func():return_requested.emit())
func refresh(state,inspected: bool,busy:=false,revealed:=false) -> void:
	current=state
	_inspected=inspected
	main_chrome.visible=not inspected
	observer_chrome.visible=inspected
	_shade.visible=inventory_panel.visible
	var locked: bool=busy or state.failed
	var starter_top: bool=state.starter_top()
	var starter_pending: bool=state.starter_middle_seated(state.selected)
	if state.failed:
		failure_overlay.title.text="榫型不匹配，连接松动" if not state.mismatched_joints().is_empty() else ("槽口位置不合，接合漏水" if not state.mismatched_openings().is_empty() else "板端接缝对齐，试浪漏水")
		var failure: Dictionary=state.failure_result()
		if failure.get("code","")=="assembly_failed":failure_overlay.title.text="组装失败"
		elif failure.get("code","")=="assembly_mismatch":failure_overlay.title.text="拼装错误"
		elif failure.get("code","")=="structure":failure_overlay.title.text="搭扣未扣牢，支撑松动"
		elif failure.get("code","")=="mixed":failure_overlay.title.text="船板漏水，支撑松动"
		failure_overlay.description.text=str(failure.get("message","请重新观察，再试一次。"))
	var row: int=Rules.row_for(state.selected)
	workspace.note.text=("装配船架 · " if row<0 else "")+"拖空白处旋转 · 双指、滚轮或按钮缩放 · 候选可放大查看"
	observation_label.text=("三件同型木料，缺口形状不同。" if row>=0 else "比较接合口的宽、深与上下层次。")+("\n中件侧推后，再装上方木件。" if row==0 and state.joint=="three_way_lap" else ("\n示范一块，其余船板依次装入。" if row>=0 else ("\n隔舱底部沿用同一种缺口。" if state.selected=="cross_upper" else "")))
	var automatic_pending: bool=state.selected not in Rules.MANUAL_IDS and not state.placed.has(state.selected)
	var installed: bool=state.placed.has(state.selected)
	selection_label.text="完整船壳" if state.completed else Rules.GROUP_LABELS[Rules.group_for(state.selected)]
	stage_label.text="本关未通过" if state.failed else ("演示进行中" if busy else ("合壳完成" if state.completed else "当前要安装"))
	task_label.text="重新观察，重新挑战" if state.failed else ("船壳与隔舱已完成" if state.completed else ("从底向舷铺好船板" if row>=0 else "接好支撑与隔舱"))
	var completed_groups:=0
	for index in Rules.GROUPS.size():
		var installed_count:=0
		for id in Rules.GROUPS[index]:
			if state.placed.has(id):installed_count+=1
		if installed_count==Rules.GROUPS[index].size():completed_groups+=1
		group_buttons[index].text=("✓ " if installed_count==Rules.GROUPS[index].size() else "○ ")+Rules.GROUP_LABELS[index]+" · %d/%d 件"%[installed_count,Rules.GROUPS[index].size()]
		group_buttons[index].disabled=locked or state.group_target(index).is_empty()
	inventory_button.text="搭建进度 %d / %d 组 · 展开  ›"%[completed_groups,Rules.GROUPS.size()]
	observe_button.disabled=locked
	observe_button.text="看看这处连接" if installed else "看榫头，挑木料"
	for button in [bulkhead_button,transparent_button,prepare_observation_button,reset_observation_button,inventory_button,return_button,lesson_button,zoom_in_button,zoom_out_button,zoom_reset_button]:button.disabled=locked
	undo_button.disabled=state.failed or (state.placed.is_empty() and not starter_pending)
	observer_undo_button.disabled=undo_button.disabled
	observer_undo_button.text="撤回上一步"
	observer_undo_button.visible=installed or starter_pending
	if starter_pending:observer_undo_button.text="取回中件"
	restart_button.disabled=state.failed
	check_button.disabled=locked or state.placed.size()!=Rules.IDS.size() or state.completed
	for id in joint_buttons:
		joint_buttons[id].disabled=locked or starter_top or installed or automatic_pending or not state.observed.has(state.selected)
		joint_buttons[id].set_pressed_no_signal(state.joint==id)
		joint_buttons[id].modulate=Color.WHITE
	prepare_observation_button.visible=not installed
	prepare_observation_button.text="先选榫头" if state.joint.is_empty() else ("先选木料" if state.opening.is_empty() else "准备试装")
	if not installed and not busy:
		observer_feedback.text="先点上方，挑一个榫头。" if state.joint.is_empty() else ("榫头选好了，再转动右侧木料，选择匹配的开口位置。" if state.opening.is_empty() else "抓住木料沿箭头推入；拖空白处可转动查看。")
	var review: bool=installed and not busy
	title_label.text=("这一处已试装 · " if review else "观察 · ")+Rules.label_for(state.selected)
	observer_instruction.text="接着安装同组木料，或返回船架。" if review else "转动看看槽口的位置，再选一件能接上的木料。"
	if review:
		if state.selected=="cross_upper":observer_instruction.text="两件已试装。转动看看缺口两侧是否贴合，再继续搭建。"
		elif state.selected=="three_middle":observer_instruction.text="中件已从侧面滑入。接着装顶件，看看能否合拢并挡住中件的退出方向。"
		elif state.selected=="three_upper":observer_instruction.text="顶件已落入交叉槽，接下来看看整船能否经得住海浪。"
	if not review:
		if row==0:observer_instruction.text="先观察这件木料的缺口，再沿对应方向试着嵌入。"
		if state.selected=="cross_upper":observer_instruction.text="上下两个缺口相向，把上件向下落入下梁，观察槽肩是否贴合。"
		elif state.selected=="three_middle":observer_instruction.text="第 2 件：从侧面推入，为最后一根木料留出缺口。"
		elif state.selected=="three_upper":observer_instruction.text="第 3 件：向下装入交叉槽，挡住中件的退出方向。"
		elif state.selected=="bulkhead":observer_instruction.text="让底部缺口对准座梁；观察槽肩能否贴合，再继续压入。"
	if starter_top:observer_instruction.text="中件已就位，把上方木件向下嵌入交叉槽，扣住中件。"
	if state.failed:
		title_label.text=failure_overlay.title.text+" · "+Rules.label_for(state.selected)
		observer_instruction.text="本次拼装结束，可重新开始或回到关卡目录。"
	gallery.configure_task(Rules.expected(state.selected))
	gallery.visible=not review
	options_panel.visible=not review and not starter_top
	if is_instance_valid(current_view):
		opening_gallery.configure(current_view,state)
		opening_measure.configure(current_view.receiving_dimensions(state.selected),OpeningReference.build(current_view,state),opening_gallery)
	for id in opening_buttons:opening_buttons[id].disabled=locked or starter_top or installed or automatic_pending or state.joint.is_empty()
	for button in gallery.inspect_buttons.values():button.disabled=locked
	for button in opening_gallery.inspect_buttons.values():button.disabled=locked or state.joint.is_empty()
	if is_instance_valid(current_view):update_zoom(current_view.framing.zoom_factor)
	overview_button.disabled=locked
	overview_button.text="继续搭建" if review and state.next_in_group().is_empty() else "返回船架"
	next_piece_button.visible=not state.failed and not state.next_in_group().is_empty()
	next_piece_button.disabled=locked
	next_piece_button.text="接着铺另一块" if row>=0 else "接着装顶撑"
	transparent_button.visible=inspected
	transparent_button.set_pressed_no_signal(revealed)
	transparent_button.text="返回装配视野" if revealed else "看槽口"
	# The complete board group uses staggered stock; there is no separate
	# per-row choice after the representative has been installed.
	layout_title.visible=false
	layout_note.visible=false
	layout_note.text="上下排短接缝需要错开。" if row>0 else "底列从左侧端缝起铺。"
	_sync_local_scene()
	for id in layout_buttons:
		layout_buttons[id].visible=false
		layout_buttons[id].disabled=locked or installed or row<1 or state.selected.ends_with("b")
		layout_buttons[id].set_pressed_no_signal(state.layout==id)
func feedback(message: String,error:=false) -> void:
	Controls.feedback(feedback_label,message,error)
	Controls.feedback(observer_feedback,message,error)
func _fit_layout() -> void:
	if not is_inside_tree():return
	var viewport_size:=get_viewport().get_visible_rect().size
	var factor:=minf(viewport_size.x/1440.0,viewport_size.y/900.0)
	root_control.scale=Vector2.ONE*factor
	for button in [lesson_button,observer_undo_button,next_piece_button,overview_button,prepare_observation_button,transparent_button,reset_observation_button]:
		button.custom_minimum_size.y=maxf(52,44/factor)
	for button in layout_buttons.values():button.custom_minimum_size.y=maxf(44,44/factor)
	for button in [zoom_in_button,zoom_out_button,zoom_reset_button]:
		button.custom_minimum_size.y=maxf(48,44/factor)
	for button in [zoom_in_button,zoom_out_button]:button.custom_minimum_size.x=maxf(52,44/factor)
	for button in opening_gallery.inspect_buttons.values():button.custom_minimum_size=Vector2(maxf(56,44/factor),44/factor)
	for id in gallery.inspect_buttons:
		gallery.inspect_buttons[id].custom_minimum_size=Vector2(maxf(56,44/factor),44/factor)
		gallery.previews[id].custom_minimum_size.y=maxf(88,164-gallery.inspect_buttons[id].custom_minimum_size.y)
	magnifier.set_display_scale(factor)
	root_control.position=(viewport_size-Vector2(1440,900)*factor)*.5
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:return
	if magnifier.visible:
		if event.is_action_pressed("ui_cancel"):magnifier.close();get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if inventory_open:
			inventory_panel.hide()
			_shade.hide()
		elif _inspected:overview_requested.emit()
		else:return
		get_viewport().set_input_as_handled()

func _sync_local_scene() -> void:
	if is_instance_valid(local_viewport):local_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if _inspected and visible else SubViewport.UPDATE_DISABLED
	if is_instance_valid(observation_orbit):observation_orbit.set_process(_inspected and visible)

func update_zoom(factor: float) -> void:
	zoom_label.text="%d%%"%roundi(100.0/factor)
