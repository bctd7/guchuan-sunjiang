extends Control
## Measured reference and candidates. Each row shares the same ruler scale.
const Lengths=preload("res://models/ship/keel/length_geometry.gd")
var piece_id:="rib_l1"
var selected_length:=""
var pixel_scale:=300.0
var _font: Font
var background:=StyleBoxFlat.new()
func _ready() -> void:
	background.bg_color=Color("f2e7cf")
	background.set_corner_radius_all(10)
	custom_minimum_size=Vector2(330,156)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_font=get_theme_default_font()
	resized.connect(queue_redraw)
func configure(id: String,length: String="") -> void:
	selected_length=length
	if piece_id!=id:
		piece_id=id
		queue_redraw()
func _draw() -> void:
	if _font==null: return
	var ink:=Color("405343")
	var wood:=Color("c5a377")
	var edge:=Color("8f7557")
	var opening:=Color("fff8e8")
	draw_style_box(background,Rect2(Vector2.ZERO,size))
	var beam:=piece_id.begins_with("beam")
	var dovetail:=piece_id in ["bow","stern"]
	var limit: float=8.0 if beam else (1.4 if dovetail else .70)
	var start:=78.0
	pixel_scale=(size.x-start-20)/limit
	draw_string(_font,Vector2(12,21),tr("先看看槽口有多深"),HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	draw_string(_font,Vector2(12,40),tr("100格=1模型单位 · 目标槽口的尺寸"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	draw_line(Vector2(start,55),Vector2(start+limit*pixel_scale,55),ink,1)
	var step:=100 if beam else (20 if dovetail else 10)
	for tick in range(0,roundi(limit*100)+1,step):
		var x: float=start+tick*.01*pixel_scale
		draw_line(Vector2(x,49),Vector2(x,56),ink,1)
		draw_string(_font,Vector2(x-6,71),tr(str(tick)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	var reference: float=Lengths.reference_span(piece_id)
	var center: float=start+limit*pixel_scale/2
	var target_label: String="定位" if beam else ("槽95格" if dovetail else "槽45格")
	draw_string(_font,Vector2(12,96),tr(target_label),HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	if beam:
		for sign_value in [-1,1]:
			var x: float=center+(sign_value*2.78-.19)*pixel_scale
			draw_rect(Rect2(x,80,.38*pixel_scale,25),wood)
			draw_line(Vector2(x,92),Vector2(x+.38*pixel_scale,92),opening,4)
		draw_line(Vector2(center-reference/2*pixel_scale,108),Vector2(center+reference/2*pixel_scale,108),edge,1)
	else:
		draw_rect(Rect2(start,78,reference*pixel_scale+10,30),wood)
		draw_rect(Rect2(start,87,reference*pixel_scale,12),opening)
		if not dovetail: draw_line(Vector2(start+reference*pixel_scale,87),Vector2(start+reference*pixel_scale,99),edge,2)
		else: draw_line(Vector2(start+reference*pixel_scale+10,87),Vector2(start+reference*pixel_scale+10,99),opening,3)
	var caption: String="盲槽深45格；孔底留3格，肩部应贴合。"
	if dovetail: caption="滑槽承托95格；端部留2格，肩部应贴合。"
	if beam: caption="定位总长632格；木销应贴近船肋外侧。"
	draw_string(_font,Vector2(12,131),tr(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	draw_string(_font,Vector2(12,150),tr("下方三件木料按相同比例展示，点选后试装。"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
