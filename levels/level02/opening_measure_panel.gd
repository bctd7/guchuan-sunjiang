extends Control
## Use the candidates' actual face-on camera scale for the receiving profile.
const D=preload("res://levels/level02/opening_dimensions.gd")
const MEASURE_HEIGHT := 172.0
const CAPTION_FONT_SIZE := 13
const SUBTITLE_BASELINE := 42.0
const TEXT_GAP := 8.0
var dimensions: Dictionary={}
var reference: Dictionary={}
var gallery: Control
var pixel_scale:=300.0
var ruler_start:=78.0
var target_rectangles: Array[Rect2]=[]
var reference_caption:=""
var _preview: SubViewportContainer
var _diagram:=Rect2()
var _ink:=Color("405343")
var _front:=Basis.IDENTITY
var _center:=Vector3.ZERO
var background:=StyleBoxFlat.new()
func _ready() -> void:
	background.bg_color=Color("f2e7cf")
	background.set_corner_radius_all(10)
	custom_minimum_size=Vector2(330,MEASURE_HEIGHT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func configure(data: Dictionary,reference_data: Dictionary,candidates: Control=null) -> void:
	dimensions=data.duplicate(true);reference=reference_data.duplicate(true);gallery=candidates
	custom_minimum_size.y=104 if reference.kind in ["paired","shape"] else MEASURE_HEIGHT
	queue_redraw()
func _process(_delta: float) -> void:
	if is_visible_in_tree():queue_redraw()
func _point(value: Vector3) -> Vector2:
	var local:=_front.inverse()*(value-_center)
	return _diagram.get_center()+Vector2(local.x,-local.y)*pixel_scale
func _box(a: Vector3,b: Vector3) -> void:
	var p:=_point(a);var q:=_point(b)
	var rect:=Rect2(p.min(q),(q-p).abs())
	target_rectangles.append(rect)
	var clipped:=rect.intersection(_diagram)
	if clipped.has_area():
		draw_rect(clipped,Color("c5a377"));draw_rect(clipped,Color("8f7557"),false,1)
func _measure(a: Vector3,b: Vector3) -> void:
	var p:=_point(a);var q:=_point(b);var side: Vector2=(q-p).normalized().orthogonal()*3
	var region:=_diagram.grow(-1)
	if not region.intersects(Rect2(p.min(q),(q-p).abs()).grow(.1)):return
	draw_line(p.clamp(region.position,region.end),q.clamp(region.position,region.end),_ink,1.5,true)
	for point in [p,q]:
		if region.has_point(point):draw_line((point-side).clamp(region.position,region.end),(point+side).clamp(region.position,region.end),_ink,1.5,true)
func _draw() -> void:
	if reference.is_empty() or not is_instance_valid(gallery):return
	var font:=get_theme_default_font()
	draw_style_box(background,Rect2(Vector2.ZERO,size));target_rectangles.clear()
	if reference.kind in ["paired","shape"]:
		draw_string(font,Vector2(12,23),tr("看看两边的接合形状"),HORIZONTAL_ALIGNMENT_LEFT,-1,18,_ink)
		draw_string(font,Vector2(12,53),tr(reference.subtitle),HORIZONTAL_ALIGNMENT_LEFT,-1,15,_ink)
		draw_string(font,Vector2(12,84),tr(reference.caption),HORIZONTAL_ALIGNMENT_LEFT,-1,15,_ink)
		return
	_preview=gallery.previews.A
	var to_local:=get_global_transform_with_canvas().affine_inverse()
	var note_baseline := size.y - TEXT_GAP - font.get_descent(CAPTION_FONT_SIZE)
	var diagram_top := SUBTITLE_BASELINE + font.get_descent(CAPTION_FONT_SIZE) + TEXT_GAP
	var diagram_bottom := note_baseline - font.get_ascent(CAPTION_FONT_SIZE) - TEXT_GAP
	var preview_x := (to_local * _preview.get_global_transform_with_canvas().origin).x
	_diagram = Rect2(preview_x, diagram_top, _preview.size.x, diagram_bottom - diagram_top)
	_front=gallery.marks.A.front;_center=gallery.marks.A.center
	pixel_scale=_preview.size.y/_preview.camera.size
	var caption_x: float=(to_local*gallery.caption_labels.A.get_global_transform_with_canvas().origin).x
	var d: Dictionary=gallery.measurements.A
	var title:="先看看要接住的木料"
	var note:="缺口的宽和深，都要能容纳这段木料。"
	if reference.kind=="tongue":
		title="先看看槽口要对到多高";note="从木料下边，量到凸条或槽口的中间。"
		var half: float=reference.stock*.5
		var center: float=reference.value-half
		_box(Vector3(.3,-half,.05),Vector3(.3,half,.29))
		_box(Vector3(.3,center-reference.width*.5,-.04),Vector3(.3,center+reference.width*.5,.05))
		_measure(Vector3(.3,-half,-.065),Vector3(.3,center,-.065))
		reference_caption="%s格\n凸条高度"%D.number(reference.value)
	elif reference.kind=="layers":
		title="对照两根已装木料";note=reference.note
		var side: Vector3=_front.x
		var region := _diagram
		var crop:=PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
		for section in reference.get("sections",[]):
			var polygon:=PackedVector2Array()
			for point in section:polygon.append(_point(side*point.x+Vector3.UP*point.y))
			for clipped in Geometry2D.intersect_polygons(polygon,crop):draw_colored_polygon(clipped,Color("c5a377"))
		# The rectangles record measured spans for layout QA; the visible profile
		# above comes from the installed meshes, including a wrong middle.
		var a:=_point(-side*reference.value*.5);var b:=_point(side*reference.value*.5)
		target_rectangles.append(Rect2(a.min(b),Vector2(absf(b.x-a.x),1)))
		reference_caption="宽%s格\n交叉接合"%D.number(reference.value)
	elif d.kind=="upper_channel":
		title="先看看最后一根木料";note="缺口要能接住它，位置也要对到中间。"
		var normal:=Vector3(sin(PI/3),0,cos(PI/3))
		_box(-normal*reference.value*.5+Vector3(0,.04,0),normal*reference.value*.5+Vector3(0,.12,0))
		_measure(-normal*reference.value*.5+Vector3(0,.155,0),normal*reference.value*.5+Vector3(0,.155,0))
		reference_caption="宽%s格\n从中间落下"%D.number(reference.value)
	else:
		var bottom: float=-.09 if d.stock>.25 else -.12
		var depth: float=reference.get("depth",dimensions.get("depth",.12))
		_box(Vector3(.14,bottom,-reference.value*.5),Vector3(.14,bottom+depth,reference.value*.5))
		_measure(Vector3(.14,bottom-.025,-reference.value*.5),Vector3(.14,bottom-.025,reference.value*.5))
		_measure(Vector3(.14,bottom,0),Vector3(.14,bottom+depth,0))
		var rounded: bool=reference.get("source","")=="starter_cross_section"
		reference_caption="宽约%d格\n深约%d格"%[roundi(reference.value*100),roundi(depth*100)] if rounded else "宽%s格\n深%s格"%[D.number(reference.value),D.number(depth)]
	draw_string(font,Vector2(12,22),tr(title),HORIZONTAL_ALIGNMENT_LEFT,-1,18,_ink)
	draw_string(font,Vector2(12,SUBTITLE_BASELINE),tr("正面按相同比例对照 · 单位：格"),HORIZONTAL_ALIGNMENT_LEFT,-1,CAPTION_FONT_SIZE,_ink)
	var lines:=reference_caption.split("\n")
	for index in lines.size():draw_string(font,Vector2(caption_x,83+index*25),tr(lines[index]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,_ink)
	draw_string(font,Vector2(12,note_baseline),tr(note),HORIZONTAL_ALIGNMENT_LEFT,-1,CAPTION_FONT_SIZE,_ink)
