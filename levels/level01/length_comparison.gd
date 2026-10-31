extends Control
const Fonts = preload("res://shared/chinese_fonts.gd")
## A neutral section comparison in the same unit scale as the actual ship meshes.
## Every candidate starts at the same shoulder line; no answer markings are drawn.
const SLOT_DEPTH := 0.45
const UNIT_TICKS := 100
const GAP := 0.03
const LENGTHS := {"long":0.62,"short":0.27,"correct":0.42}
const CANDIDATES := {"long":"A","short":"B","correct":"C"}
var selected_length := ""
var pixel_scale := 300.0
var baseline_x := 92.0
var scale_caption := "100格 = 1模型单位"
var gap_caption := "槽底预留3格间隙，榫肩贴合。"
var _font: Font

func _ready() -> void:
	custom_minimum_size=Vector2(330,282)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_font=Fonts.font()
	resized.connect(queue_redraw)

func select_length(id: String) -> void:
	selected_length=id
	queue_redraw()

func _draw() -> void:
	if _font == null: return
	pixel_scale=minf(310.0,(size.x-baseline_x-32.0)/.70)
	var ink:=Color("405343")
	var wood:=Color("c5a377")
	var edge:=Color("8f7557")
	var opening:=Color("fff8e8")
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	draw_string(_font,Vector2(18,25),"半榫长度对照 · 同一比例",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
	draw_string(_font,Vector2(18,46),scale_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	draw_line(Vector2(baseline_x,65),Vector2(baseline_x+.7*pixel_scale,65),ink,1.0)
	for tick in range(0,71,5):
		var x: float=baseline_x+float(tick)/UNIT_TICKS*pixel_scale
		var major: bool=tick%10==0
		draw_line(Vector2(x,65),Vector2(x,58 if major else 61),ink,1.0)
		if major: draw_string(_font,Vector2(x-6,79),str(tick),HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)
	var first_y:=104.0
	var last_y:=225.0
	draw_dashed_line(Vector2(baseline_x,first_y-27),Vector2(baseline_x,last_y+24),Color("8c9c96"),1.2,5.0)
	var bottom_x:=baseline_x+SLOT_DEPTH*pixel_scale
	draw_dashed_line(Vector2(bottom_x,first_y+20),Vector2(bottom_x,last_y+24),Color("afa38d"),1.0,5.0)
	draw_string(_font,Vector2(16,first_y+5),"槽深45格",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	# Slot opens at the shoulder baseline and ends at a solid wall.
	draw_rect(Rect2(baseline_x,first_y-21,SLOT_DEPTH*pixel_scale+19,42),wood)
	draw_rect(Rect2(baseline_x,first_y-10,SLOT_DEPTH*pixel_scale,20),opening)
	draw_line(Vector2(baseline_x,first_y-10),Vector2(bottom_x,first_y-10),edge,1.5)
	draw_line(Vector2(bottom_x,first_y-10),Vector2(bottom_x,first_y+10),edge,2)
	draw_line(Vector2(bottom_x,first_y+10),Vector2(baseline_x,first_y+10),edge,1.5)
	draw_string(_font,Vector2(bottom_x+20,first_y+5),"底壁",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	var index:=0
	for id in LENGTHS:
		var y:=145.0+index*40.0
		if id == selected_length:
			draw_rect(Rect2(12,y-19,size.x-24,38),Color("647e88"),false,2.0)
		draw_string(_font,Vector2(18,y+5),"%s %d格" % [CANDIDATES[id],roundi(LENGTHS[id]*UNIT_TICKS)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
		draw_rect(Rect2(baseline_x-15,y-17,15,34),wood)
		draw_rect(Rect2(baseline_x,y-9,LENGTHS[id]*pixel_scale,18),wood)
		draw_rect(Rect2(baseline_x,y-9,LENGTHS[id]*pixel_scale,18),edge,false,1.1)
		index+=1
	draw_string(_font,Vector2(18,269),gap_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)

func _background() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("f4ecd9")
	style.border_color=Color("d6c7a7")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style
