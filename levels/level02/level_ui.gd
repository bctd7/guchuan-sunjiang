extends CanvasLayer
const StepGuide=preload("res://components/ui/step_guide.gd")
var step_guide: Control
var main_guide: Control
const ExhibitLayout=preload("res://components/ui/exhibition_layout.gd")
const ZoomBar=preload("res://components/preview/inspection_zoom_bar.gd")
## Overview presents the current task; a separate inspection page owns model choices.
const Magnifier=preload("res://components/preview/model_magnifier.gd")
const Workspace=preload("res://components/ui/inspection_workspace.gd")
const OpeningGallery=preload("res://levels/level02/opening_gallery.gd")
const OpeningReference=preload("res://levels/level02/opening_reference.gd")
const OpeningMeasure=preload("res://components/ui/measurements/opening_measure_panel.gd")
const ObservationOrbit=preload("res://components/preview/inspection_orbit.gd")
const Style=preload("res://components/ui/workshop_ui_style.gd")
const Controls=preload("res://components/ui/chapter_ui.gd")
const Friendly=preload("res://components/ui/friendly_theme.gd")
const ChapterResult=preload("res://components/ui/chapter_result.gd")
const Gallery=preload("res://levels/level02/joint_gallery.gd")
const DragGuide=preload("res://levels/level02/drag_guide.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
signal bulkhead_requested
signal lesson_requested
signal group_selected(index: int)
signal next_piece_requested
signal joint_selected(id: String)
signal opening_selected(id: String)
signal camera_reset_requested
signal reset_observation_requested
signal observe_requested
signal overview_requested
signal transparent_requested
signal zoom_requested(factor: float)
signal magnify_requested(source: Control,title: String)
signal undo_requested
signal restart_requested
signal check_requested
signal return_requested
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
var _measurement_key: Array = []
var opening_buttons: Dictionary={}
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
var observe_button: Button
var observer_undo_button: Button
var overview_button: Button
var transparent_button: Button
var undo_button: Button
var restart_button: Button
var check_button: Button
var return_button: Button
var bulkhead_button: Button
var lesson_button: Button
var feedback_label: Label
var title_label: Label
var header_label: Label
var task_label: Label
var selection_label: Label
var stage_label: Label
var drag_guide: Control
var gallery: Control
var success_panel: ColorRect
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
	step_guide.blocker = magnifier
	drag_guide.guidance_blocker = magnifier
	magnifier.visibility_changed.connect(_sync_local_scene)
	success_panel.visibility_changed.connect(_sync_local_scene)
	failure_overlay.visibility_changed.connect(_sync_local_scene)
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
	var chrome=preload("res://components/ui/chapter_chrome.gd").build(main_chrome,2,"船板合壳","这组木料","水密隔舱小课堂")
	main_header=chrome.header;main_sidebar=chrome.side;main_footer=chrome.footer
	header_label=chrome.title;task_label=chrome.task;stage_label=chrome.stage;selection_label=chrome.piece
	return_button=chrome.back;observe_button=chrome.observe;bulkhead_button=chrome.story
	return_button.pressed.connect(func():return_requested.emit())
	observe_button.pressed.connect(func():observe_requested.emit())
	bulkhead_button.pressed.connect(func():bulkhead_requested.emit())
	var row: HBoxContainer=chrome.row
	var words: VBoxContainer=chrome.words
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
	row.add_child(inventory_button)
	inventory_button.custom_minimum_size=Vector2(210,50)
	inventory_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	Style.button(inventory_button)
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
	step_guide=StepGuide.new();workspace.add_child(step_guide)
	main_guide=StepGuide.new();main_chrome.add_child(main_guide)
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
	opening_measure=OpeningMeasure.new();options_panel.add_child(opening_measure)
	opening_gallery=OpeningGallery.new();options_panel.add_child(opening_gallery);opening_buttons=opening_gallery.buttons
	opening_measure.bind_gallery(opening_gallery)
	reset_observation_requested.connect(opening_gallery.reset_view)
	opening_gallery.chosen.connect(func(id: String):opening_selected.emit(id))
	opening_gallery.inspect_requested.connect(func(id: String):magnify_requested.emit(opening_gallery.previews[id],"开口候选 · 木料 "+id))
	local_viewport=SubViewport.new();local_viewport.own_world_3d=true;local_viewport.size=Vector2i(1000,490);local_viewport.gui_disable_input=true;local_viewport.msaa_3d=Viewport.MSAA_4X
	workspace.viewport_container.add_child(local_viewport)
	observation_orbit=ObservationOrbit.new();workspace.stage_surface.add_child(observation_orbit)
	observation_orbit.mouse_filter=Control.MOUSE_FILTER_IGNORE;observation_orbit.set_process_input(false)
	drag_guide.reparent(workspace.stage_surface,false)
	drag_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transparent_button=workspace.button(workspace.actions,"看槽口");transparent_button.toggle_mode=true
	transparent_button.pressed.connect(func():transparent_requested.emit())
	reset_observation_button=workspace.button(workspace.actions,"重新观察")
	reset_observation_button.pressed.connect(func():reset_observation_requested.emit())
	var zoom_bar:=ZoomBar.new();workspace.stage_surface.add_child(zoom_bar)
	workspace.mount_camera_tools(zoom_bar)
	zoom_out_button=zoom_bar.zoom_out;zoom_label=zoom_bar.percentage;zoom_in_button=zoom_bar.zoom_in;zoom_reset_button=zoom_bar.reset_button
	zoom_bar.zoom_requested.connect(func(factor: float):zoom_requested.emit(factor))
	zoom_bar.reset_requested.connect(func():camera_reset_requested.emit())
	camera_reset_requested.connect(opening_gallery.reset_view)

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
	success_panel=ChapterResult.new()
	root_control.add_child(success_panel)
	success_panel.return_requested.connect(func():return_requested.emit())
	failure_overlay=ChapterResult.new()
	root_control.add_child(failure_overlay)
	failure_restart_button=failure_overlay.restart_button
	failure_return_button=failure_overlay.return_button
	failure_overlay.restart_requested.connect(func():restart_requested.emit())
	failure_overlay.return_requested.connect(func():return_requested.emit())
func refresh(state,inspected: bool,busy:=false,revealed:=false) -> void:
	current=state
	_inspected=inspected
	if inspected and joint_buttons.is_empty():
		gallery.build_cards()
		opening_gallery.build_cards()
		_fit_layout()
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
	for button in [bulkhead_button,transparent_button,reset_observation_button,inventory_button,return_button,lesson_button,zoom_in_button,zoom_out_button,zoom_reset_button]:button.disabled=locked
	undo_button.disabled=locked or (state.placed.is_empty() and not starter_pending)
	observer_undo_button.disabled=undo_button.disabled
	observer_undo_button.text="撤回上一步"
	observer_undo_button.visible=installed or starter_pending
	if starter_pending:observer_undo_button.text="取回中件"
	restart_button.disabled=locked
	check_button.disabled=locked or state.placed.size()!=Rules.IDS.size() or state.completed
	for id in joint_buttons:
		joint_buttons[id].disabled=locked or starter_top or installed or automatic_pending or not state.observed.has(state.selected)
		joint_buttons[id].set_pressed_no_signal(state.joint==id)
		joint_buttons[id].modulate=Color.WHITE
	if not installed and not busy:workspace.show_feedback("")
	var review: bool=installed and not busy
	title_label.text=("这一处已试装 · " if review else "观察 · ")+Rules.label_for(state.selected)
	if state.failed:
		title_label.text=failure_overlay.title.text+" · "+Rules.label_for(state.selected)
	gallery.visible=not review
	options_panel.visible=not review and not starter_top
	if inspected and is_instance_valid(current_view):
		opening_gallery.configure(current_view,state)
		var dimensions: Dictionary = current_view.receiving_dimensions(state.selected)
		var key := [state.selected, current_view.opening_geometry_id(state.selected), dimensions]
		if state.selected == "three_upper":
			key.append(state.placed.get("three_middle"))
		if key != _measurement_key:
			_measurement_key = key
			opening_measure.configure(dimensions, OpeningReference.build(current_view,state))
	for id in opening_buttons:opening_buttons[id].disabled=locked or starter_top or installed or automatic_pending or state.joint.is_empty()
	for button in gallery.inspect_buttons.values():button.disabled=locked
	for button in opening_gallery.inspect_buttons.values():button.disabled=locked or state.joint.is_empty()
	if is_instance_valid(current_view):update_zoom(current_view.framing.zoom_factor)
	overview_button.disabled=locked
	overview_button.text="继续搭建" if review and state.next_in_group().is_empty() else "返回船架"
	next_piece_button.visible=true
	next_piece_button.disabled=locked
	next_piece_button.text="接着铺另一块" if row>=0 else "接着装顶撑"
	transparent_button.visible=inspected
	transparent_button.set_pressed_no_signal(revealed)
	transparent_button.text="返回装配视野" if revealed else "看槽口"
	_sync_local_scene()
	var area: Control
	if not state.failed and not state.completed and not busy:
		if installed:area=next_piece_button if not state.next_in_group().is_empty() else overview_button
		elif not starter_top:
			if state.joint.is_empty():area=gallery
			elif state.opening.is_empty():area=opening_gallery
	drag_guide.selection_ready=not locked and not installed and not state.completed and (starter_top or (not state.joint.is_empty() and not state.opening.is_empty()))
	var candidates: Array = joint_buttons.values() if area == gallery else opening_buttons.values() if area == opening_gallery else []
	step_guide.show_target(area, candidates)
	if not inspected:
		main_guide.show_target(null if locked or state.completed else observe_button)
	StepGuide.action(next_piece_button,installed and not locked and not state.next_in_group().is_empty())
	next_piece_button.visible=next_piece_button.modulate.a>0
	StepGuide.action(undo_button,not undo_button.disabled)
	StepGuide.action(observer_undo_button,not observer_undo_button.disabled and not busy)

func feedback(message: String,error:=false) -> void:
	Controls.feedback(feedback_label,message,error)
	workspace.show_feedback(message,error)
func _fit_layout() -> void:
	if not is_inside_tree():return
	var viewport_size:=get_viewport().get_visible_rect().size
	var factor:=ExhibitLayout.factor(viewport_size)
	ExhibitLayout.fit(root_control,viewport_size)
	workspace.fit_screen(true)
	for button in [lesson_button,observer_undo_button,next_piece_button,overview_button,transparent_button,reset_observation_button]:
		button.custom_minimum_size.y=maxf(60,60/factor)
	for button in [zoom_in_button,zoom_out_button,zoom_reset_button]:
		button.custom_minimum_size.y=maxf(60,60/factor)
	for button in [zoom_in_button,zoom_out_button]:button.custom_minimum_size.x=maxf(60,60/factor)
	for button in opening_gallery.inspect_buttons.values():button.custom_minimum_size=Vector2(maxf(56,60/factor),60/factor)
	for card in gallery.buttons.values():
		card.fit_inspect_button(factor)
	workspace.layout_camera_tools(factor)
	magnifier.set_display_scale(factor)
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
	var active := _inspected and visible and not (magnifier.visible or success_panel.visible or failure_overlay.visible)
	local_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
	observation_orbit.set_process(active)
	drag_guide.set_process(active and drag_guide.enabled)
	for preview in gallery.previews.values() + opening_gallery.previews.values():
		preview.set_suspended(not active)

func update_zoom(factor: float) -> void:
	zoom_label.text="%d%%"%roundi(100.0/factor)
