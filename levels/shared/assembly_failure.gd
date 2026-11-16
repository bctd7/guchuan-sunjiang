extends ColorRect
## Blocking end-of-level failure actions. Gameplay owns validation and reset.
signal restart_requested
signal return_requested
const Controls=preload("res://levels/shared/chapter_ui.gd")
var panel: PanelContainer
var title: Label
var description: Label
var restart_button: Button
var return_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color=Color(0.16,0.12,0.08,0.20)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var center=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel=Controls.panel(center,Rect2(0,0,660,290))
	panel.custom_minimum_size=Vector2(660,290)
	var stack=VBoxContainer.new()
	stack.add_theme_constant_override("separation",24)
	stack.alignment=BoxContainer.ALIGNMENT_CENTER
	panel.add_child(stack)
	title=Controls.label(stack,"拼接有错误哦",32)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	description=Controls.label(stack,"本关未通过，再观察一下榫头和木料，重新试试吧。",20)
	description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var actions=HBoxContainer.new()
	actions.alignment=BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",20)
	stack.add_child(actions)
	restart_button=Controls.button(actions,"重新开始")
	return_button=Controls.button(actions,"回到关卡目录")
	for button in [restart_button,return_button]:
		button.custom_minimum_size=Vector2(240,56)
		button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(func(): restart_requested.emit())
	return_button.pressed.connect(func(): return_requested.emit())
	hide()

func open() -> void:
	show()
	restart_button.grab_focus()
