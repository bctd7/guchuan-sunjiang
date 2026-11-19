extends RefCounted
## Shared workshop header, task card and footer. Chapters supply text and actions.
const Controls=preload("res://components/ui/chapter_ui.gd")
const Style=preload("res://components/ui/workshop_ui_style.gd")
static func label(parent: Node,text: String,size: int,weight:=400,muted:=false) -> Label:
	var value=Controls.label(parent,text,size)
	Style.label(value,size,weight,muted)
	return value
static func button(parent: Node,text: String,primary:=false) -> Button:
	var value=Controls.button(parent,text)
	Style.button(value,primary)
	return value
static func build(parent: Control,chapter: int,title: String,caption: String,story: String) -> Dictionary:
	parent.theme=Style.theme()
	var header=Controls.panel(parent,Rect2(20,18,1400,82))
	var header_style=Style.card();header_style.content_margin_top=10;header_style.content_margin_bottom=10
	header.add_theme_stylebox_override("panel",header_style)
	var heading=HBoxContainer.new();heading.add_theme_constant_override("separation",36);header.add_child(heading)
	var titles=VBoxContainer.new();titles.add_theme_constant_override("separation",2);heading.add_child(titles)
	label(titles,"古船榫匠 / 第%s关" % ["一","二","三"][chapter-1],14,500,true)
	var title_label=label(titles,title,28,600)
	var task=VBoxContainer.new();task.size_flags_horizontal=Control.SIZE_EXPAND_FILL;task.add_theme_constant_override("separation",4);heading.add_child(task)
	label(task,"当前任务",14,500,true)
	var task_label=label(task,"",23,500)
	var space=Control.new();space.custom_minimum_size.x=180;space.mouse_filter=Control.MOUSE_FILTER_IGNORE;heading.add_child(space)
	var back=button(parent,"返回关卡目录");back.position=Vector2(1244,34);back.size=Vector2(160,48)
	var side=Controls.panel(parent,Rect2(20,144,Style.TASK_CARD_WIDTH,320))
	side.add_theme_stylebox_override("panel",Style.task_card())
	var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",Style.TASK_CARD_GAP);side.add_child(stack)
	var status=HBoxContainer.new();status.add_theme_constant_override("separation",12);stack.add_child(status)
	var stage=label(status,"当前要安装",14,500,true);stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var step=label(status,"",14,600)
	var selected=VBoxContainer.new();selected.add_theme_constant_override("separation",4);stack.add_child(selected)
	label(selected,caption,14,400,true)
	var piece=label(selected,"",24,600);piece.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var observe=button(stack,"看榫头，挑木料",true);observe.custom_minimum_size.y=60
	var story_button=button(stack,story);story_button.custom_minimum_size.y=52
	var footer=Controls.panel(parent,Rect2(20,770,1400,110));footer.add_theme_stylebox_override("panel",Style.card())
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);footer.add_child(row)
	var words=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",6);row.add_child(words)
	return {"header":header,"title":title_label,"task":task_label,"back":back,"side":side,"stack":stack,"stage":stage,"step":step,"piece":piece,"observe":observe,"story":story_button,"footer":footer,"row":row,"words":words}
