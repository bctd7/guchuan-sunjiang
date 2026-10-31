extends CanvasLayer
const Failure=preload("res://levels/shared/assembly_failure.gd")
const Controls=preload("res://levels/shared/chapter_ui.gd")
const Friendly=preload("res://shared/ui/friendly_theme.gd")
const Gallery=preload("res://levels/level02/joint_gallery.gd")
const SeamDiagram=preload("res://levels/level02/seam_diagram.gd")
const DragGuide=preload("res://levels/level02/drag_guide.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
signal bulkhead_requested
var bulkhead_button: Button
signal lesson_requested
var lesson_button: Button
signal piece_selected(id: String)
signal joint_selected(id: String)
signal layout_selected(id: String)
signal observe_requested
signal overview_requested
signal transparent_requested
signal plan_requested
signal undo_requested
signal repair_requested
signal restart_requested
signal check_requested
signal return_requested
signal continue_requested
var piece_buttons: Dictionary={}
var joint_buttons: Dictionary={}
var layout_buttons: Dictionary={}
var observe_button: Button
var overview_button: Button
var transparent_button: Button
var plan_button: Button
var undo_button: Button
var repair_button: Button
var restart_button: Button
var check_button: Button
var return_button: Button
var continue_button: Button
var feedback_label: Label
var title_label: Label
var count_label: Label
var observation_label: Label
var diagram: Control
var drag_guide: Control
var success_panel: PanelContainer
var failure_overlay: ColorRect
var failure_restart_button: Button
var failure_return_button: Button
var root_control: Control
var current
var gallery: Control
var header_label: Label
func _ready() -> void:
	root_control=Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root_control.size=Vector2(1440,900)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_control.theme=Friendly.make_theme(true)
	add_child(root_control)
	drag_guide=DragGuide.new()
	root_control.add_child(drag_guide)
	var header=_panel(Rect2(20,15,1190,68))
	header_label=_label_at("02  船板合壳  /  从底向舷 · 端缝错开",Rect2(36,27,1150,45),28)
	return_button=_button_at("关卡目录",Rect2(1230,20,190,52))
	return_button.pressed.connect(func(): return_requested.emit())
	lesson_button=_button_at("本关榫卯",Rect2(1230,100,190,48))
	lesson_button.pressed.connect(func(): lesson_requested.emit())
	bulkhead_button=_button_at("水密隔舱小课堂",Rect2(1210,158,210,48))
	bulkhead_button.pressed.connect(func(): bulkhead_requested.emit())
	var inventory=_panel(Rect2(20,100,300,650))
	var list=VBoxContainer.new()
	inventory.add_child(list)
	list.add_theme_constant_override("separation",3)
	_label(list,"构件  /  依序放置",22)
	count_label=_label(list,"0 / 10",20)
	for id in Rules.IDS:
		var b=Button.new()
		b.text=Rules.label_for(id)
		b.custom_minimum_size=Vector2(260,48)
		list.add_child(b)
		piece_buttons[id]=b
		b.pressed.connect(func(): piece_selected.emit(id))
	undo_button=Button.new()
	undo_button.text="撤回上一件"
	undo_button.custom_minimum_size=Vector2(260,48)
	list.add_child(undo_button)
	undo_button.pressed.connect(func(): undo_requested.emit())
	restart_button=_button_at("重新搭建",Rect2(20,772,142,50))
	restart_button.pressed.connect(func(): restart_requested.emit())
	repair_button=_button_at("修正端缝",Rect2(172,772,148,50))
	repair_button.pressed.connect(func(): repair_requested.emit())
	title_label=_label_at("选择构件 → 观察选材 → 按住木料沿箭头推入",Rect2(350,98,1050,35),22)
	observe_button=_button_at("放大观察槽口",Rect2(350,145,220,50))
	observe_button.pressed.connect(func(): observe_requested.emit())
	overview_button=_button_at("返回船壳",Rect2(582,145,190,50))
	overview_button.pressed.connect(func(): overview_requested.emit())
	transparent_button=_button_at("透视船板",Rect2(784,145,190,50))
	transparent_button.pressed.connect(func(): transparent_requested.emit())
	plan_button=_button_at("端缝展开图",Rect2(986,145,200,50))
	plan_button.pressed.connect(func(): plan_requested.emit())
	var idx=0
	for joint in ["tongue_groove","cross_lap","three_way_lap"]:
		var b=_button_at(Rules.JOINT_NAMES[joint],Rect2(350+idx*145,210,135,48))
		joint_buttons[joint]=b
		b.pressed.connect(func(): joint_selected.emit(joint))
		idx+=1
	for i in 2:
		var id="A" if i==0 else "B"
		var b=_button_at("排布 %s · X=%s" % [id,"−1.40" if i==0 else "+1.40"],Rect2(810+i*295,210,282,47))
		layout_buttons[id]=b
		b.pressed.connect(func(): layout_selected.emit(id))
	gallery=Gallery.new()
	gallery.position=Vector2(350,315)
	root_control.add_child(gallery)
	gallery.hide()
	observation_label=_label_at("",Rect2(350,268,1050,48),20)
	observation_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	observation_label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	diagram=SeamDiagram.new()
	diagram.position=Vector2(350,315)
	diagram.size=Vector2(1050,370)
	diagram.hide()
	root_control.add_child(diagram)
	var foot=_panel(Rect2(340,710,1080,170))
	feedback_label=_label_at("先选择底列尾板，放大查看连续舌槽。",Rect2(365,725,790,58),21)
	feedback_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label_at("木榫不等于水密。装齐后统一试浪；海浪和浅水为教学示意，实际仍须填缝与试验。",Rect2(365,813,1030,42),18)
	check_button=_button_at("装齐后自动试浪",Rect2(1170,731,230,58))
	check_button.pressed.connect(func(): check_requested.emit())
	success_panel=_panel(Rect2(500,310,710,365))
	var v=VBoxContainer.new()
	success_panel.add_child(v)
	_label(v,"船板合壳完成",30)
	var text=_label(v,"三列端缝错开；十字框、三向撑和隔舱就位。\n试浪未见漏水；青色线表示需填缝密封的边缘。\n实际水密须经材料、工艺和实体试验验证。",21)
	# Three explicit short lines avoid the initial zero-width wrap expanding the panel.
	continue_button=Button.new()
	continue_button.text="继续 / 返回关卡目录"
	continue_button.custom_minimum_size.y=50
	v.add_child(continue_button)
	continue_button.pressed.connect(func(): continue_requested.emit())
	var close=Button.new()
	close.text="查看完成船段"
	v.add_child(close)
	close.pressed.connect(func(): success_panel.hide())
	var science=Button.new()
	science.text="了解水密隔舱"
	science.custom_minimum_size.y=48
	v.add_child(science)
	science.pressed.connect(func(): bulkhead_requested.emit())
	success_panel.hide()
	failure_overlay=Failure.new()
	root_control.add_child(failure_overlay)
	failure_restart_button=failure_overlay.restart_button
	failure_return_button=failure_overlay.return_button
	failure_overlay.restart_requested.connect(func(): restart_requested.emit())
	failure_overlay.return_requested.connect(func(): return_requested.emit())
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
func _panel(rect: Rect2) -> PanelContainer:
	return Controls.panel(root_control,rect)

func _label(parent: Node, text: String, font_size: int) -> Label:
	return Controls.label(parent,text,font_size)

func _label_at(text_value: String,rect: Rect2,font: int) -> Label:
	var n=_label(root_control,text_value,font)
	n.position=rect.position
	n.size=rect.size
	return n
func _button_at(text_value: String,rect: Rect2) -> Button:
	var n=Button.new()
	n.text=text_value
	n.position=rect.position
	n.size=rect.size
	root_control.add_child(n)
	return n
func refresh(s,inspected: bool,busy := false) -> void:
	current=s
	diagram.configure(s)
	observation_label.visible=not diagram.visible
	busy=busy or s.failed
	header_label.queue_redraw()
	gallery.visible=inspected and not diagram.visible
	var joint_index=0
	for key in ["tongue_groove","cross_lap","three_way_lap"]:
		joint_buttons[key].position=Vector2(350+joint_index*355,439) if inspected else Vector2(350+joint_index*145,210)
		joint_buttons[key].size=Vector2(330,48) if inspected else Vector2(135,48)
		joint_index+=1
	count_label.text="%d / 10 件%s" % [s.placed.size()," · 已完成" if s.completed else ""]
	for id in piece_buttons:
		piece_buttons[id].text=("✓ " if s.placed.has(id) else "○ ")+Rules.label_for(id)
		piece_buttons[id].disabled=busy
		piece_buttons[id].button_pressed=s.selected==id
		piece_buttons[id].modulate=Color("dbe5cc") if s.selected==id else Color.WHITE
	for id in joint_buttons:
		joint_buttons[id].disabled=busy or not s.observed.has(s.selected)
		joint_buttons[id].modulate=Color("bacbaa") if s.joint==id else Color.WHITE
	for id in layout_buttons:
		layout_buttons[id].disabled=busy or not s.observed.has(s.selected) or Rules.row_for(s.selected)<1 or s.selected.ends_with("b")
		layout_buttons[id].modulate=Color("bacbaa") if s.layout==id else Color.WHITE
	var row=Rules.row_for(s.selected)
	if not s.observed.has(s.selected): observation_label.text="先观察实际船材。候选不会默认选中。"
	elif row>=0:
		observation_label.text="板材沿板列方向侧向送入；中央细舌对应连续直槽。\n%s端缝是短竖边，长水平拼边不是错缝。" % ("底列端缝 X=−1.40。" if row==0 else "与下列端缝比较，再选 A/B。")
	elif s.selected=="cross_upper": observation_label.text="船内十字边框：两材各刻半，上材沿 −Y 落入。观察缺口，再选榫型。"
	elif s.selected.begins_with("three"): observation_label.text="船内三根横撑：0° / +60° / −60°；交点各留底 / 中 / 顶 1/3。\n中撑先于顶撑，从上方落入。观察三层缺口，再选榫型。"
	else: observation_label.text="隔舱最后落入，底轨下半缺口与固定基框上半缺口相合。\n周边仍需填缝、密封；支撑安装时上方须保持开放。"
	overview_button.disabled=not inspected and not diagram.visible
	repair_button.hide() # Final failed runs offer restart or directory return.
	undo_button.disabled=s.failed or s.placed.is_empty()
	for control in [observe_button,transparent_button,plan_button,lesson_button,bulkhead_button,return_button]: control.disabled=busy
	restart_button.disabled=s.failed
	check_button.disabled=busy or s.placed.size()!=Rules.IDS.size()
func feedback(message: String, error := false) -> void:
	Controls.feedback(feedback_label,message,error)

func _fit_layout() -> void:
	var viewport_size:=get_viewport().get_visible_rect().size
	var factor:=minf(viewport_size.x/1440.0,viewport_size.y/900.0)
	root_control.scale=Vector2.ONE*factor
	root_control.position=(viewport_size-Vector2(1440,900)*factor)*.5
