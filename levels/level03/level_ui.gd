extends CanvasLayer
## Chapter-three adapter: state and actions only; all page framing is shared.
signal lesson_requested
signal story_requested
signal candidate_chosen(kind: String)
signal socket_requested(id: String)
signal undo_requested
signal restart_requested
signal next_requested
signal turn_requested(degrees: float)
signal return_requested
const StepGuide=preload("res://levels/shared/step_guide.gd")
const ExhibitLayout=preload("res://shared/ui/exhibition_layout.gd")
const Chrome=preload("res://levels/shared/chapter_chrome.gd")
const Controls=preload("res://levels/shared/chapter_ui.gd")
const MainStyle=preload("res://shared/ui/workshop_ui_style.gd")
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Rules=preload("res://levels/level03/connection_rules.gd")
const Gallery=preload("res://levels/level03/candidate_gallery.gd")
var root: Control
var main_chrome: Control
var main_header: PanelContainer
var main_sidebar: PanelContainer
var main_footer: PanelContainer
var main_guide: Control
var step_guide: Control
var backdrop: CanvasLayer
var main_viewport: SubViewport
var model_container: SubViewportContainer
var workspace: Control
var magnifier: Control
var gallery: HBoxContainer
var zoom_bar: HBoxContainer
var orbit: Control
var next_button: Button
var undo_button: Button
var restart_button: Button
var inspect_button: Button
var return_button: Button
var lesson_button: Button
var story_button: Button
var overview_button: Button
var closeup_button: Button
var left_button: Button
var right_button: Button
var center_button: Button
var feedback_label: Label
var stage_label: Label
var part_label: Label
var step_label: Label
var task_label: Label
var progress_label: Label
var angle_label: Label
var success_panel: ColorRect
var turn_row: HBoxContainer
var helm_panel: PanelContainer
var inspected := false
var _view: Node3D
var _state
var _busy := false
var _footer_row: HBoxContainer
var _zoom := 1.0
var _base_size := 1.0
var _selected := ""
var candidate_buttons: Dictionary:
	get: return gallery.buttons if is_instance_valid(gallery) else {}

func _ready() -> void:
	layer=5
	root=Control.new();root.size=Vector2(1440,900);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=Friendly.make_theme(true);add_child(root)
	backdrop=preload("res://levels/shared/workshop_backdrop.gd").new();add_child(backdrop)
	main_chrome=Control.new();main_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(main_chrome)
	model_container=SubViewportContainer.new();model_container.stretch=true
	model_container.mouse_filter=Control.MOUSE_FILTER_IGNORE;main_chrome.add_child(model_container)
	model_container.position=Vector2(385,140);model_container.size=Vector2(1035,600)
	main_viewport=SubViewport.new();main_viewport.size=Vector2i(1035,600);main_viewport.own_world_3d=true
	main_viewport.gui_disable_input=true;main_viewport.msaa_3d=Viewport.MSAA_2X
	main_viewport.transparent_bg=true;model_container.add_child(main_viewport)
	var chrome=Chrome.build(main_chrome,3,"帆樯舾装","这件木料","船匠的小故事")
	main_header=chrome.header;main_sidebar=chrome.side;main_footer=chrome.footer
	task_label=chrome.task;stage_label=chrome.stage;step_label=chrome.step;part_label=chrome.piece
	inspect_button=chrome.observe;story_button=chrome.story;return_button=chrome.back
	inspect_button.pressed.connect(func():set_observed(true))
	story_button.pressed.connect(func():story_requested.emit())
	return_button.pressed.connect(func():return_requested.emit())
	_footer_row=chrome.row
	progress_label=Chrome.label(chrome.words,"",16,500,true)
	feedback_label=Chrome.label(chrome.words,"木件尚未安装。",21,500);feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	undo_button=_footer_button("撤回上一步");undo_button.pressed.connect(func():undo_requested.emit())
	restart_button=_footer_button("重新搭建");restart_button.pressed.connect(func():restart_requested.emit())
	next_button=_footer_button("继续搭建",true);next_button.pressed.connect(func():next_requested.emit())
	helm_panel=Controls.panel(main_chrome,Rect2(20,484,MainStyle.TASK_CARD_WIDTH,210))
	helm_panel.add_theme_stylebox_override("panel",MainStyle.task_card())
	var helm_stack=VBoxContainer.new();helm_stack.add_theme_constant_override("separation",20);helm_panel.add_child(helm_stack)
	angle_label=Chrome.label(helm_stack,"",19,500);angle_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	turn_row=HBoxContainer.new();turn_row.add_theme_constant_override("separation",12);helm_stack.add_child(turn_row)
	left_button=Chrome.button(turn_row,"左舵");center_button=Chrome.button(turn_row,"回正");right_button=Chrome.button(turn_row,"右舵")
	for button in [left_button,center_button,right_button]:button.custom_minimum_size.y=60
	left_button.pressed.connect(func():turn_requested.emit(-30))
	center_button.pressed.connect(func():turn_requested.emit(0))
	right_button.pressed.connect(func():turn_requested.emit(30))
	main_guide=StepGuide.new();main_chrome.add_child(main_guide)
	_build_observer()
	magnifier=preload("res://levels/shared/model_magnifier.gd").new();root.add_child(magnifier)
	magnifier.closed.connect(func():orbit.active=inspected and not _busy)
	success_panel=preload("res://levels/shared/chapter_result.gd").new();root.add_child(success_panel)
	success_panel.return_requested.connect(func():return_requested.emit())
	main_guide.blocker=success_panel;step_guide.blocker=magnifier
	get_viewport().size_changed.connect(_fit_layout)
	visibility_changed.connect(_sync_background)
	_fit_layout()

func _footer_button(text: String,primary:=false) -> Button:
	var button=Chrome.button(_footer_row,text,primary)
	button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;button.custom_minimum_size=Vector2(148,56)
	return button

func _build_observer() -> void:
	workspace=preload("res://levels/shared/inspection_workspace.gd").new();root.add_child(workspace)
	workspace.options.get_parent().hide()
	lesson_button=workspace.button(workspace.header,"本关榫卯讲解")
	lesson_button.pressed.connect(func():lesson_requested.emit())
	overview_button=workspace.button(workspace.header,"返回船架")
	overview_button.pressed.connect(func():set_observed(false))
	gallery=Gallery.new();workspace.candidates.add_child(gallery)
	gallery.chosen.connect(func(kind: String):candidate_chosen.emit(kind))
	gallery.inspect_requested.connect(func(kind: String):
		if _busy:return
		orbit.suspend_gesture();orbit.active=false
		magnifier.open(gallery.previews[kind],Rules.NAMES[kind]))
	zoom_bar=preload("res://levels/shared/inspection_zoom_bar.gd").new();workspace.stage_surface.add_child(zoom_bar)
	workspace.mount_camera_tools(zoom_bar)
	zoom_bar.zoom_requested.connect(_change_zoom);zoom_bar.reset_requested.connect(_reset_camera)
	closeup_button=workspace.button(workspace.actions,"看接合处")
	closeup_button.pressed.connect(func():
		if is_instance_valid(_view):_view.toggle_closeup();_configure_camera())
	orbit=preload("res://levels/shared/selectable_orbit.gd").new();workspace.stage_surface.add_child(orbit)
	orbit.zoom_requested.connect(_change_zoom)
	orbit.tapped.connect(func(point: Vector2):
		if not _busy and inspected and is_instance_valid(_view):
			var id: String=_view.pick_socket(point)
			if not id.is_empty():socket_requested.emit(id))
	step_guide=StepGuide.new();workspace.add_child(step_guide)
	workspace.hide()

func bind_view(view: Node3D) -> void:
	_view=view
	_view.screen_surface=model_container
	_configure_camera()

func set_observed(value: bool) -> void:
	if _busy or inspected==value:return
	inspected=value
	if value:
		main_viewport.reparent(workspace.viewport_container)
		_view.screen_surface=workspace.viewport_container
		main_viewport.transparent_bg=false
		next_button.reparent(workspace.actions)
	else:
		orbit.suspend_gesture();orbit.deactivate()
		main_viewport.reparent(model_container)
		_view.screen_surface=model_container
		main_viewport.transparent_bg=true
		next_button.reparent(_footer_row)
	main_chrome.visible=not value;workspace.visible=value
	_sync_background();_fit_layout()
	if is_instance_valid(_view):_view.cutaway=false;_view.focus_current();_configure_camera()
	if _state!=null:refresh(_state,_busy)

func _sync_background() -> void:
	if is_instance_valid(backdrop):backdrop.visible=visible and not inspected

func _configure_camera() -> void:
	if not is_instance_valid(_view):return
	_zoom=1.0;_base_size=_view.camera.size
	orbit.configure(_view.camera,_view.focus_center,_view.camera.position-_view.focus_center,true)
	orbit.active=inspected and not _busy
	zoom_bar.update_zoom(_zoom)

func _change_zoom(factor: float) -> void:
	if _busy or not inspected:return
	_zoom=clampf(_zoom*factor,.3,1.6)
	_view.camera.size=_base_size*_zoom;zoom_bar.update_zoom(_zoom)

func _reset_camera() -> void:
	if _busy or not is_instance_valid(_view):return
	_view.cutaway=false;_view.focus_current();_configure_camera()

func refresh(state,busy: bool) -> void:
	_state=state;_busy=busy
	var installed: bool=state.placed.has(state.selected)
	var ready: bool=state.placed.has("blade")
	stage_label.text="构件已装好" if installed else "当前要安装"
	step_label.text="%02d / 03" % (state.stage_idx+1)
	task_label.text=["接好桅座与桅杆","装好帆桁支撑","装好船尾舵架"][state.stage_idx]
	part_label.text=Rules.SPECS[state.selected].label
	progress_label.text="搭建进度 %d / 8 件" % state.placed.size()
	workspace.title.text=("这一处已试装 · " if installed else "观察 · ")+Rules.SPECS[state.selected].label
	gallery.configure(state.selected);gallery.select(state.candidate);gallery.visible=not installed
	for button in candidate_buttons.values():button.disabled=busy or installed
	for button in gallery.inspect_buttons.values():button.disabled=busy
	for button in [lesson_button,story_button,return_button,overview_button,inspect_button,restart_button,closeup_button,zoom_bar.reset_button,zoom_bar.zoom_in,zoom_bar.zoom_out]:button.disabled=busy
	undo_button.disabled=busy or state.placed.is_empty()
	next_button.disabled=busy or not installed or state.stage_idx==2 and state.stage_done()
	next_button.text="下一处船件" if state.stage_done() and state.stage_idx<2 else "继续搭建"
	StepGuide.action(next_button,not next_button.disabled);next_button.visible=not next_button.disabled
	StepGuide.action(undo_button,not undo_button.disabled)
	helm_panel.visible=ready and not inspected
	angle_label.text="舵角 %+.0f°\n左舵 %s / 右舵 %s" % [state.rudder_angle,"✓" if state.tested_left else "待测","✓" if state.tested_right else "待测"]
	for button in [left_button,center_button,right_button]:button.disabled=busy or not ready
	if ready:overview_button.text="返回船架操舵"
	else:overview_button.text="返回船架"
	if is_instance_valid(_view):
		if _selected!=state.selected:
			_selected=state.selected;_view.focus_current();_configure_camera()
		elif inspected:
			orbit._apply_camera();_view.camera.size=_base_size*_zoom
	orbit.active=inspected and not busy and not magnifier.visible
	main_guide.show_target(null);step_guide.show_target(null)
	if not busy and not state.completed:
		if not inspected:
			main_guide.show_target((left_button if not state.tested_left else right_button) if ready else (next_button if installed else inspect_button))
		elif ready:step_guide.show_target(overview_button)
		elif installed:step_guide.show_target(next_button)
		elif state.candidate.is_empty():step_guide.show_target(gallery)
		else:
			var id: String=state.selected
			step_guide.point_provider=func():return _view.socket_screen_position(id)

func show_feedback(message: String,error:=false) -> void:
	Controls.feedback(feedback_label,message,error)
	Controls.feedback(workspace.status,message,error)

func _unhandled_key_input(event: InputEvent) -> void:
	if inspected and not _busy and not magnifier.visible and event.is_action_pressed("ui_cancel"):
		set_observed(false);get_viewport().set_input_as_handled()

func _fit_layout() -> void:
	if not is_inside_tree():return
	ExhibitLayout.fit(root,get_viewport().get_visible_rect().size)
	if is_instance_valid(workspace):workspace.fit_screen(true)
