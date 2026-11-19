extends RefCounted
const Fonts = preload("res://components/ui/chinese_fonts.gd")
## Shared chapter/workshop chrome only; story and lesson overlays own their themes.
const INK=Color("304c3f")
const MUTED=Color("6c7769")
const PAPER=Color("fffbf3")
const TASK_CARD_WIDTH := 340
const TASK_CARD_GAP := 20

static func task_card() -> StyleBoxFlat:
	var value=card(26)
	value.content_margin_top=26
	value.content_margin_bottom=26
	return value

static func font(weight: int=400) -> Font:
	return Fonts.font(weight)

static func theme() -> Theme:
	var value=Theme.new()
	value.default_font=font()
	value.default_font_size=18
	value.set_color("font_color","Label",INK)
	return value

static func card(padding:=20) -> StyleBoxFlat:
	var value=StyleBoxFlat.new()
	value.bg_color=PAPER
	value.border_color=Color("d8ceba")
	value.set_border_width_all(1)
	value.set_corner_radius_all(18)
	value.content_margin_left=padding
	value.content_margin_right=padding
	value.content_margin_top=16
	value.content_margin_bottom=16
	value.shadow_color=Color(.10,.15,.10,.12)
	value.shadow_size=12
	value.shadow_offset=Vector2(0,4)
	return value

static func label(value: Label,size: int,weight:=400,muted:=false) -> void:
	value.add_theme_font_override("font",font(weight))
	value.add_theme_font_size_override("font_size",size)
	value.add_theme_color_override("font_color",MUTED if muted else INK)

static func button(value: Button,primary:=false) -> void:
	value.add_theme_font_override("font",font(600 if primary else 500))
	value.add_theme_font_size_override("font_size",20 if primary else 18)
	var colors={
		"normal":[Color("365e4d"),Color("294b3e")] if primary else [Color("f6f0e3"),Color("c7bda7")],
		"hover":[Color("416e5b"),Color("315541")] if primary else [Color("fffbf3"),Color("a5b29a")],
		"pressed":[Color("2d5142"),Color("244437")] if primary else [Color("e9eedf"),Color("98aa8f")],
		"disabled":[Color("e9e7de"),Color("d4d4c8")]
	}
	for state in colors:
		var box=StyleBoxFlat.new()
		box.bg_color=colors[state][0]
		box.border_color=colors[state][1]
		box.set_border_width_all(1)
		box.border_width_bottom=1 if state in ["pressed","disabled"] else 3
		box.set_corner_radius_all(12)
		box.content_margin_left=14
		box.content_margin_right=14
		box.content_margin_top=10
		box.content_margin_bottom=10
		box.shadow_color=Color(.12,.18,.10,.08)
		box.shadow_size=3 if state=="normal" else 0
		box.shadow_offset=Vector2(0,2)
		value.add_theme_stylebox_override(state,box)
	value.add_theme_stylebox_override("hover_pressed",value.get_theme_stylebox("pressed").duplicate())
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		value.add_theme_color_override(state,Color("fffaf0") if primary else INK)
	value.add_theme_color_override("font_disabled_color",Color("7d8578"))
	var focus=StyleBoxFlat.new()
	focus.bg_color=Color(0,0,0,0)
	focus.border_color=Color("b58d4f")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(12)
	value.add_theme_stylebox_override("focus",focus)
