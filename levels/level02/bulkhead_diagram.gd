extends Control
## Illustration of limited flooding: one damaged compartment, not an unsinkability claim.
var time := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(280,160)
func _process(delta: float) -> void:
	time+=delta
	queue_redraw()
func _draw() -> void:
	var shell:=Rect2(18,20,size.x-36,120)
	draw_rect(shell,Color("e7c99c"))
	draw_rect(shell,Color("98764f"),false,5)
	var partition:=shell.position.x+shell.size.x*.43
	draw_rect(Rect2(shell.position.x+4,shell.position.y+68,partition-shell.position.x-8,48),Color("83b3b4"))
	draw_rect(Rect2(partition-5,shell.position.y,10,shell.size.y),Color("8f6d45"))
	draw_line(Vector2(partition-7,shell.end.y-6),Vector2(partition+7,shell.end.y-6),Color("3b8b89"),6)
	for i in 3:
		var x: float=shell.position.x+18+i*18
		var y: float=shell.position.y+fposmod(time*55+i*20,65)
		draw_circle(Vector2(x,y),4,Color("4f989e"))
	draw_string(get_theme_default_font(),Vector2(shell.position.x+12,shell.end.y+28),"局部进水",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("40574c"))
	draw_string(get_theme_default_font(),Vector2(partition+17,shell.end.y+28),"隔板限制扩散",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("40574c"))
