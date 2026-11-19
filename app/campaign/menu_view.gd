extends Control
## Directory presentation only. Campaign retains every navigation callback and state.
const Fonts = preload("res://components/ui/chinese_fonts.gd")
const ART = preload("res://assets/images/menu/ship_stages.png")
const CANVAS = Vector2(1600,900)
const INK = Color("254e36")
const PAPER = Color("faf3e3")
var buttons: Dictionary = {}
var status: Label
var replay_button: Button

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=CANVAS

func build(chapters: Array, enter: Callable, replay: Callable) -> void:
	label_at(self,"古船榫匠",Vector2(58,24),Vector2(420,82),64,700)
	label_at(self,"一榫一卯，造一艘福船",Vector2(62,115),Vector2(600,38),25,400)
	var descriptions=["识榫对槽，搭起船的骨架","铺板合舱，让船身稳稳浮起","立桅装舵，为远航做好准备"]
	for index in chapters.size():
		var card:=Panel.new()
		card.position=Vector2(56+index*504,200)
		card.size=Vector2(480,602)
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var normal:=panel_style(PAPER,Color("bbae8d"),1,18)
		normal.shadow_color=Color(0.25,0.21,0.12,0.08)
		normal.shadow_size=10
		normal.shadow_offset=Vector2(0,5)
		card.add_theme_stylebox_override("panel",normal)
		add_child(card)
		var art:=TextureRect.new()
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		var atlas:=AtlasTexture.new()
		atlas.atlas=ART
		var cell:=float(ART.get_width())/3.0
		atlas.region=Rect2(index*cell,0,cell,ART.get_height())
		atlas.filter_clip=true
		art.texture=atlas
		art.position=Vector2(12,12)
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size=Vector2(456,366)
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
		art.set_deferred("size",Vector2(456,366))
		var pieces: PackedStringArray=chapters[index].title.split(" · ")
		label_at(card,"%02d  |  %s"%[index+1,pieces[0]],Vector2(30,370),Vector2(420,38),23,500)
		label_at(card,pieces[1],Vector2(28,410),Vector2(424,64),45,700)
		label_at(card,descriptions[index],Vector2(30,482),Vector2(420,36),22,400)
		var button:=Button.new()
		button.text="进入关卡  →"
		button.tooltip_text=chapters[index].title
		button.position=Vector2(30,533)
		button.size=Vector2(420,54)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font",Fonts.font(500))
		button.add_theme_font_size_override("font_size",25)
		for state in ["normal","hover","pressed","hover_pressed"]:
			var filled: bool=state!="normal"
			var fill:=INK if filled else PAPER
			if state=="pressed" or state=="hover_pressed":fill=Color("193d29")
			button.add_theme_stylebox_override(state,panel_style(fill,INK,1,9))
			var color_name: String="font_color" if state=="normal" else "font_"+state+"_color"
			button.add_theme_color_override(color_name,PAPER if filled else INK)
		button.add_theme_color_override("font_focus_color",INK)
		button.add_theme_stylebox_override("focus",panel_style(Color.TRANSPARENT,Color("b58b49"),3,9))
		button.pressed.connect(enter.bind(index+1))
		card.add_child(button)
		buttons[index+1]=button
		var highlight:=normal.duplicate() as StyleBoxFlat
		highlight.border_color=INK
		highlight.set_border_width_all(2)
		button.mouse_entered.connect(func():card.add_theme_stylebox_override("panel",highlight))
		button.mouse_exited.connect(func():card.add_theme_stylebox_override("panel",normal))
		button.focus_entered.connect(func():card.add_theme_stylebox_override("panel",highlight))
		button.focus_exited.connect(func():card.add_theme_stylebox_override("panel",normal))
	status=label_at(self,"",Vector2(56,825),Vector2(1180,38),20,500)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color",Color("923e30"))
	replay_button=Button.new()
	replay_button.text="▷  重播欢迎片"
	replay_button.position=Vector2(1290,825)
	replay_button.size=Vector2(254,48)
	replay_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	replay_button.add_theme_font_override("font",Fonts.font(400))
	replay_button.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed"]:
		replay_button.add_theme_stylebox_override(state,panel_style(Color.TRANSPARENT if state=="normal" else Color("eae8d5"),Color("a6af97"),1,9))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		replay_button.add_theme_color_override(state,INK)
	replay_button.add_theme_stylebox_override("focus",panel_style(Color.TRANSPARENT,INK,2,9))
	replay_button.pressed.connect(replay)
	add_child(replay_button)

func fit(dimensions: Vector2) -> void:
	var factor:=minf(dimensions.x/CANVAS.x,dimensions.y/CANVAS.y)
	scale=Vector2.ONE*factor
	position=(dimensions-CANVAS*factor)*0.5

func label_at(parent: Node, text: String, pos: Vector2, bounds: Vector2, font_size: int, weight: int) -> Label:
	var label:=Label.new()
	label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text=text
	label.position=pos
	label.size=bounds
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",Fonts.font(weight))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	parent.add_child(label)
	return label

func panel_style(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _draw() -> void:
	draw_line(Vector2(56,174),Vector2(1544,174),Color("83957d"),1.0,true)
	# Quiet drafting marks and wave contours frame the cards without adding copy.
	var faint:=Color(0.48,0.47,0.34,0.08)
	for x in range(560,1140,32):
		draw_line(Vector2(x,40),Vector2(x,142),faint,1.0,true)
	for y in range(50,145,24):
		draw_line(Vector2(560,y),Vector2(1130,y),faint,1.0,true)
	for row in range(9):
		var points:=PackedVector2Array()
		for x in range(0,1601,5):
			var edge:=pow(absf(float(x)-800.0)/800.0,2.0)
			points.append(Vector2(x,902-row*5-edge*(22+12*sin(float(x)/80.0+row*0.12))))
		draw_polyline(points,Color(0.29,0.41,0.32,0.13),1.0,true)
