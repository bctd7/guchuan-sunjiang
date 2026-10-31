extends Button
## Code-native wooden face detail; hit area and text remain ordinary Button UI.
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	expand_icon = true
	add_theme_constant_override("icon_max_width",28)

func _draw() -> void:
	if size.x < 80: return
	var color := Color(Color("79906b"),.18) if button_pressed else Color(Color("a1784e"),.18)
	var right := size.x-17
	var bottom := size.y-9
	draw_polyline(PackedVector2Array([Vector2(right-45,bottom),Vector2(right-24,bottom-2),Vector2(right,bottom)]),color,1.2,true)
	draw_line(Vector2(right-27,bottom-5),Vector2(right-6,bottom-5),color,1.0,true)
