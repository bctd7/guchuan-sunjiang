extends Control
## Live unfolding of accepted boards and the current A/B preview, never an answer image.
const Rules=preload("res://levels/level02/connection_rules.gd")
var rows: Array[Dictionary]=[]
var checked := false
var complete := false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func configure(state) -> void:
	rows.clear()
	checked=state.checked
	complete=state.completed
	for row in 3:
		var selected: bool=Rules.row_for(state.selected)==row and not state.placed.has(state.selected)
		var choice: String=str(state.layouts.get(row,""))
		if selected and not state.layout.is_empty(): choice=state.layout
		var count:=int(state.placed.has("plank_%da"%row))+int(state.placed.has("plank_%db"%row))
		rows.append({"row":row,"layout":choice,"seam":Rules.seam(choice) if not choice.is_empty() else 0.0,"placed":count,"preview":selected,"known":not choice.is_empty()})
	queue_redraw()
func _text(at: Vector2,value: String,font_size:=20,color:=Color("40564b")) -> void:
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	var paper:=StyleBoxFlat.new()
	paper.bg_color=Color("fff8e8")
	paper.border_color=Color("cfbd9b")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(18)
	draw_style_box(paper,Rect2(Vector2.ZERO,size))
	_text(Vector2(24,34),"当前船板展开 · 随 A/B 选择更新",24)
	_text(Vector2(24,64),"实色为已装船板，浅色为未装；金色框为当前排。",18)
	if rows.size()!=3: return
	var width: float=size.x-225
	for row in 3:
		var info: Dictionary=rows[row]
		var rect:=Rect2(26,86+(2-row)*70,width,58)
		var outline:=Color("bc8736") if info.preview else Color("b69c74")
		draw_rect(rect,Color("f1e5d0"))
		if info.known:
			var x: float=rect.position.x+(float(info.seam)+4.0)/8.0*rect.size.x
			for side in 2:
				var board:=Rect2(rect.position.x if side==0 else x,rect.position.y,x-rect.position.x if side==0 else rect.end.x-x,rect.size.y)
				var color:=Color("c5a474") if row%2==0 else Color("af8b5b")
				color.a=1.0 if int(info.placed)>side else .28
				draw_rect(board,color)
			var seam_color:=Color("b74a34") if checked and _aligned(row) else Color("73563b")
			if int(info.placed)==2: draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),seam_color,5)
			else: draw_dashed_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),seam_color,3,6)
		draw_rect(rect,outline,false,3 if info.preview else 1)
		_text(Vector2(rect.end.x+16,rect.position.y+23),["底列","中列","舷列"][row],20)
		_text(Vector2(rect.end.x+16,rect.position.y+49),"排布 "+str(info.layout)+" · %d/2"%int(info.placed) if info.known else "尚未选择",18)
		if row<2: draw_line(Vector2(rect.position.x,rect.position.y-5),Vector2(rect.end.x,rect.position.y-5),Color("428688"),2)
	_text(Vector2(24,size.y-34),"短竖线是板端缝；长横线是企口接边。",19)
	_text(Vector2(24,size.y-9),"已完成整关检测。错误挑战须重新开始。" if checked and not complete else ("端缝错开，继续认识水密隔舱。" if complete else "先完成装配，最后统一进行海浪测试。"),18)
func _aligned(row: int) -> bool:
	for other in [row-1,row+1]:
		if other>=0 and other<3 and rows[row].known and rows[other].known and Rules.aligned(str(rows[row].layout),str(rows[other].layout)): return true
	return false
