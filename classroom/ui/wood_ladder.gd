extends VBoxContainer
## Decorative rails are drawn behind the ordinary controls and share their scroll.
## No overlay, input handler or additional focus target is introduced.
var first_step: Control
var last_step: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sort_children.connect(queue_redraw)
	resized.connect(queue_redraw)

func connect_steps(first: Control, last: Control) -> void:
	first_step = first
	last_step = last
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(first_step) or not is_instance_valid(last_step): return
	var inverse := get_global_transform().affine_inverse()
	var top := (inverse * first_step.global_position).y + 12.0
	var bottom := (inverse * last_step.global_position).y + last_step.size.y + 5.0
	var left := (inverse * first_step.global_position).x + 26.0
	var right := left + first_step.size.x - 52.0
	for x in [left,right]:
		# Original eight-pixel rails; only the lighting and fine grain change.
		draw_line(Vector2(x+1,top+3),Vector2(x+1,bottom+3),Color(.28,.18,.08,.16),10.0,true)
		draw_line(Vector2(x,top),Vector2(x,bottom),Color("c9aa80"),8.0,true)
		draw_line(Vector2(x-1,top),Vector2(x-1,bottom),Color("e5cfaa"),4.0,true)
		for strand in 3:
			var fiber=PackedVector2Array()
			for y in range(int(top),int(bottom)+1,10):
				fiber.append(Vector2(x-2.1+strand*2.0+sin(y*.027+strand)*.45,y))
			draw_polyline(fiber,Color(.42,.27,.12,.18),.65,true)
		draw_circle(Vector2(x,bottom),4.0,Color("c9aa80"),true,-1.0,true)
