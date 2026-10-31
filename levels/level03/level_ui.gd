extends CanvasLayer
signal lesson_requested
var lesson_button: Button
signal candidate_chosen(kind: String)
signal undo_requested
signal restart_requested
signal next_requested
signal inspect_requested
signal turn_requested(degrees: float)
signal return_requested
const Controls = preload("res://levels/shared/chapter_ui.gd")
const Friendly = preload("res://demo/friendly_theme.gd")
const Rules = preload("res://levels/level03/connection_rules.gd")
const Gallery = preload("res://levels/level03/candidate_gallery.gd")
var root: Control
var main_viewport: SubViewport
var gallery: HBoxContainer
var next_button: Button
var undo_button: Button
var restart_button: Button
var inspect_button: Button
var return_button: Button
var left_button: Button
var right_button: Button
var center_button: Button
var feedback_label: Label
var stage_label: Label
var part_label: Label
var hint_label: Label
var progress_label: Label
var angle_label: Label
var success_panel: PanelContainer
var turn_row: HBoxContainer
var candidate_buttons: Dictionary:
	get: return gallery.buttons if is_instance_valid(gallery) else {}
func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Friendly.make_theme(true)
	add_child(root)
	var top := _panel(Rect2(20,18,1400,112))
	var title := VBoxContainer.new()
	top.add_child(title)
	_label(title,"古船榫匠  /  第三关",18)
	_label(title,"帆樯舾装",32)
	_label(title,"三处局部船件 · 桅座固定 → 帆桁承托 → 船尾操舵",18)
	return_button = Button.new()
	return_button.text = "返回关卡目录"
	return_button.position = Vector2(1230,20)
	return_button.size = Vector2(190,52)
	root.add_child(return_button)
	return_button.pressed.connect(func(): return_requested.emit())
	lesson_button=Button.new()
	lesson_button.text="本关榫卯"
	lesson_button.position=Vector2(1230,85)
	lesson_button.size=Vector2(190,48)
	root.add_child(lesson_button)
	lesson_button.pressed.connect(func(): lesson_requested.emit())
	var side := _panel(Rect2(20,146,310,600))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	side.add_child(stack)
	stage_label = _label(stack,"",22)
	part_label = _label(stack,"",24)
	hint_label = _label(stack,"",19)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(270,130)
	_label(stack,"① 先看下方三个真实候选\n② 选型后，点绿色槽口试装\n③ 装好后继续下一件",18)
	inspect_button = _button(stack,"放大 / 返回局部")
	inspect_button.pressed.connect(func(): inspect_requested.emit())
	next_button = _button(stack,"继续安装")
	next_button.pressed.connect(func(): next_requested.emit())
	angle_label = _label(stack,"",19)
	angle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_row = HBoxContainer.new()
	stack.add_child(turn_row)
	left_button = _button(turn_row,"左舵")
	center_button = _button(turn_row,"回正")
	right_button = _button(turn_row,"右舵")
	left_button.pressed.connect(func(): turn_requested.emit(-30))
	center_button.pressed.connect(func(): turn_requested.emit(0))
	right_button.pressed.connect(func(): turn_requested.emit(30))
	var container := SubViewportContainer.new()
	container.position = Vector2(345,190)
	container.size = Vector2(1075,400)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	main_viewport = SubViewport.new()
	main_viewport.size = Vector2i(1075,400)
	main_viewport.own_world_3d = true
	main_viewport.gui_disable_input = true
	main_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(main_viewport)
	var assumption := _label(root,"教学假设 · 局部架空装配，角腿下方留空；尺寸非施工图。",18)
	assumption.position = Vector2(355,149)
	assumption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gallery_panel := _panel(Rect2(345,598,1075,160))
	gallery_panel.add_theme_stylebox_override("panel",Friendly.block(Color("fff8e8"),Color("d4c6a6"),2))
	# Gallery previews are real ship-member end crops. All choices visible first.
	gallery = Gallery.new()
	gallery_panel.add_child(gallery)
	gallery.chosen.connect(func(kind: String): candidate_chosen.emit(kind))
	var footer := _panel(Rect2(20,776,1400,106))
	var row := HBoxContainer.new()
	footer.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	progress_label = _label(words,"",18)
	feedback_label = _label(words,"先看候选端部，再选型；不合槽口的木件不会装入。",21)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	undo_button = _button(row,"撤回一步")
	undo_button.custom_minimum_size.x = 130
	undo_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	undo_button.pressed.connect(func(): undo_requested.emit())
	restart_button = _button(row,"重新搭建")
	restart_button.custom_minimum_size.x = 130
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(func(): restart_requested.emit())
	success_panel = _panel(Rect2(530,245,650,260))
	var victory := VBoxContainer.new()
	success_panel.add_child(victory)
	_label(victory,"第三关完成 · 帆樯与舵架就位",28)
	_label(victory,"粽角锁框，夹头承托，L 穿榫固定横撑。\n圆舵轴和舵叶已通过左右 ±30° 实测。",21)
	_button(victory,"收起卡片 · 继续操舵").pressed.connect(func(): success_panel.hide())
	success_panel.hide()
func refresh(state, busy: bool) -> void:
	lesson_button.disabled=busy
	return_button.disabled=busy
	stage_label.text = "%02d / 03  %s" % [state.stage_idx+1,["桅座三向框","桅顶帆桁夹座","船尾舵架"][state.stage_idx]]
	part_label.text = Rules.SPECS[state.selected].label
	hint_label.text = Rules.SPECS[state.selected].hint
	progress_label.text = "%d / 8 木件装好  ·  舵角范围 ±30°（游戏约定）" % state.placed.size()
	gallery.configure(state.selected)
	gallery.select(state.candidate)
	for b in candidate_buttons.values(): b.disabled = busy or state.placed.has(state.selected)
	undo_button.disabled = busy or state.placed.is_empty()
	restart_button.disabled = busy
	next_button.disabled = busy or not state.placed.has(state.selected) or state.stage_idx == 2 and state.stage_done()
	next_button.text = "下一处船件 →" if state.stage_done() and state.stage_idx < 2 else "继续安装 →"
	var ready: bool = state.placed.has("blade")
	turn_row.visible = state.stage_idx == 2
	for b in [left_button,center_button,right_button]: b.disabled = not ready or busy
	angle_label.visible = state.stage_idx == 2
	angle_label.text = "舵角 %+.0f°\n左舵 %s / 右舵 %s\n仅圆轴与舵叶转动" % [state.rudder_angle,"✓" if state.tested_left else "待测","✓" if state.tested_right else "待测"]
func show_feedback(message: String, error := false) -> void:
	Controls.feedback(feedback_label,message,error)

func _panel(rect: Rect2) -> PanelContainer:
	return Controls.panel(root,rect)

func _label(parent: Node, text: String, font_size: int) -> Label:
	return Controls.label(parent,text,font_size)

func _button(parent: Node, text: String) -> Button:
	return Controls.button(parent,text)
