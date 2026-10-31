extends Control
## Story illustration, not an archaeological reconstruction or assembly geometry.
const ART_SIZE := Vector2(1000, 238)

func _ready() -> void:
	custom_minimum_size.y = ART_SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	draw_set_transform(Vector2.ZERO, 0, size / ART_SIZE)
	_draw_workbench()
	_draw_chart()
	_draw_rope()
	_draw_tools()
	_draw_keel()
	_draw_mirror(Vector2(305, 113))
	var coins: Array[Vector2] = [Vector2(497, 96), Vector2(553, 131), Vector2(601, 80), Vector2(651, 143), Vector2(704, 99), Vector2(758, 133), Vector2(813, 86)]
	for index in coins.size():
		_draw_coin(coins[index], index)
	var font := get_theme_default_font()
	draw_line(Vector2(305, 160), Vector2(305, 194), Color(.40, .36, .24, .32), 1, true)
	draw_line(Vector2(654, 168), Vector2(654, 194), Color(.40, .36, .24, .32), 1, true)
	draw_string(font, Vector2(257, 218), "铜镜 · 月亮", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("5e644c"))
	draw_string(font, Vector2(606, 218), "钱币 · 星星", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("5e644c"))
	draw_set_transform(Vector2.ZERO)

func _draw_workbench() -> void:
	draw_style_box(_surface(Color("e5d2af"), Color("cbb18b"), 12), Rect2(0, 0, 1000, 238))
	for row in range(5):
		var y := 12.0 + row * 49
		draw_line(Vector2(1, y), Vector2(999, y + 6), Color(.54, .40, .24, .12), 1, true)
		for grain in range(3):
			var points := PackedVector2Array()
			for step in range(21):
				var x := 8.0 + step * 49
				points.append(Vector2(x, y + 9 + grain * 9 + sin(x * .013 + row) * 2))
			draw_polyline(points, Color(.53, .37, .21, .06), 1, true)
	draw_colored_polygon(PackedVector2Array([Vector2(7, 2), Vector2(400, 2), Vector2(135, 232), Vector2(2, 232)]), Color(1, .96, .80, .10))
	_ellipse(Vector2(898, 207), Vector2(23, 5), Color(.48, .33, .18, .12), 1)
	_ellipse(Vector2(898, 207), Vector2(12, 2), Color(.48, .33, .18, .09), 1)

func _draw_chart() -> void:
	var chart := PackedVector2Array([Vector2(15, 164), Vector2(148, 153), Vector2(163, 223), Vector2(25, 230)])
	draw_colored_polygon(chart, Color(.66, .50, .30, .10))
	for index in chart.size(): chart[index] += Vector2(-3, -4)
	draw_colored_polygon(chart, Color("efe4c8"))
	draw_polyline(PackedVector2Array([Vector2(32, 182), Vector2(52, 178), Vector2(60, 187), Vector2(82, 178), Vector2(100, 185), Vector2(125, 170)]), Color(.43, .51, .42, .34), 1.4, true)
	for row in range(3):
		draw_arc(Vector2(92 + row * 9, 215), 31 + row * 6, 3.8, 5.5, 18, Color(.43, .51, .42, .16), 1, true)
	draw_line(Vector2(38, 206), Vector2(118, 193), Color(.55, .44, .28, .22), 1, true)
	draw_circle(Vector2(40, 205), 3, Color(.55, .44, .28, .30))

func _draw_rope() -> void:
	for index in range(4):
		var center := Vector2(57 + index * 3, 46 + index * 2)
		_ellipse(center + Vector2(0, 2), Vector2(29 - index * 4, 18 - index * 2), Color(.39, .28, .15, .12), 5)
		_ellipse(center, Vector2(29 - index * 4, 18 - index * 2), Color("bea270"), 4)
		_ellipse(center - Vector2(0, 1), Vector2(29 - index * 4, 18 - index * 2), Color("e1c595"), 1)
	draw_polyline(PackedVector2Array([Vector2(80, 54), Vector2(99, 65), Vector2(109, 63), Vector2(116, 77), Vector2(103, 86), Vector2(111, 94)]), Color("b79a69"), 4, true)
	draw_arc(Vector2(109, 74), 8, 0, TAU, 20, Color("c8ac7d"), 3, true)

func _draw_tools() -> void:
	# Quiet workshop props stay around the edge of the central story objects.
	draw_line(Vector2(890, 34), Vector2(942, 85), Color(.40, .28, .16, .12), 12, true)
	draw_line(Vector2(891, 31), Vector2(919, 59), Color("9c7951"), 10, true)
	draw_line(Vector2(892, 29), Vector2(918, 55), Color("c39c67"), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(917, 53), Vector2(944, 79), Vector2(936, 86), Vector2(911, 59)]), Color("a9ab94"))
	draw_line(Vector2(920, 57), Vector2(941, 79), Color("d6d3b7"), 2, true)
	draw_line(Vector2(961, 111), Vector2(931, 171), Color("b08b58"), 6, true)
	draw_line(Vector2(949, 109), Vector2(968, 121), Color("96734b"), 15, true)
	draw_line(Vector2(949, 105), Vector2(970, 116), Color("c1a173"), 10, true)
	for index in range(3):
		var start := Vector2(889 + index * 12, 183 + index * 7)
		draw_arc(start, 10, .1, 2.5, 20, Color(.64, .43, .20, .32), 2, true)

func _draw_keel() -> void:
	var plank := Rect2(130, 52, 740, 126)
	draw_style_box(_surface(Color(.32, .22, .11, .12), Color(0, 0, 0, 0), 10), Rect2(132, 62, 742, 126))
	draw_style_box(_surface(Color("b58a59"), Color("a17a4b"), 9), Rect2(130, 61, 740, 126))
	draw_style_box(_surface(Color("d9b985"), Color("ad8350"), 9), plank)
	draw_line(Vector2(142, 56), Vector2(858, 56), Color(1, .91, .69, .52), 2, true)
	draw_line(Vector2(143, 181), Vector2(858, 181), Color(.40, .26, .12, .28), 1, true)
	for row in range(12):
		var points := PackedVector2Array()
		for step in range(31):
			var x := 140.0 + step * 24
			points.append(Vector2(x, 60 + row * 9 + sin(x * .021 + row * .7) * 1.8))
		draw_polyline(points, Color(.48, .30, .12, .13), 1, true)
	_ellipse(Vector2(190, 146), Vector2(26, 7), Color(.50, .32, .15, .17), 1)
	_ellipse(Vector2(190, 146), Vector2(16, 4), Color(.50, .32, .15, .18), 1)
	_ellipse(Vector2(832, 155), Vector2(18, 5), Color(.50, .32, .15, .14), 1)
	var joint := PackedVector2Array([Vector2(431, 53), Vector2(415, 87), Vector2(443, 129), Vector2(430, 177)])
	draw_polyline(joint, Color("8c643c"), 3, true)
	for index in joint.size(): joint[index] += Vector2(3, 0)
	draw_polyline(joint, Color(.98, .85, .60, .55), 1, true)
	draw_line(Vector2(430, 178), Vector2(430, 185), Color("88623d"), 2, true)

func _draw_mirror(center: Vector2) -> void:
	draw_circle(center + Vector2(1, 3), 44, Color(.30, .24, .13, .16))
	draw_circle(center, 43, Color("78623f"))
	draw_circle(center, 40, Color("b0a16e"))
	draw_arc(center, 39, 3.4, 5.9, 42, Color("eddbab"), 2, true)
	draw_circle(center, 36, Color("87917a"))
	draw_circle(center - Vector2(2, 3), 33, Color("bfc1a0"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-28, 2), center + Vector2(-18, -25), center + Vector2(11, -28), center + Vector2(26, -14), center + Vector2(-5, 8)]), Color(.95, .94, .78, .27))
	draw_arc(center, 32, 2.8, 4.2, 24, Color("e5dfb9"), 2, true)
	draw_arc(center, 35, .2, 1.8, 26, Color(.34, .40, .31, .36), 2, true)
	for index in range(7):
		var angle := .3 + index * .77
		var mark := center + Vector2(cos(angle), sin(angle)) * 30
		draw_circle(mark, 1.8 + float(index % 2), Color(.39, .49, .37, .16))
	draw_circle(center, 4, Color("89947b"))
	draw_arc(center, 6, 3.4, 5.4, 16, Color(.96, .91, .70, .44), 1, true)

func _draw_coin(center: Vector2, index: int) -> void:
	draw_circle(center + Vector2(1, 2), 20, Color(.30, .21, .10, .16))
	draw_circle(center, 19, Color("795d36"))
	draw_circle(center, 17, Color("c39a55"))
	draw_circle(center, 14, Color("dfbd78"))
	draw_arc(center, 17, 3.5, 5.8, 26, Color("f1d6a1"), 1.6, true)
	draw_arc(center, 14, .1, 2.8, 24, Color("b18b4d"), 1, true)
	draw_arc(center, 12, 3.3 + index * .1, 4.7 + index * .1, 16, Color(.48, .53, .33, .30), 2, true)
	draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), Color("80643d"))
	draw_line(center + Vector2(-4, -4), center + Vector2(4, -4), Color("aa8045"), 1, true)
	draw_line(center + Vector2(-4, 5), center + Vector2(4, 5), Color("f0cf91"), 1, true)
	for mark in range(3):
		var angle := .7 + mark * 1.9 + index * .24
		var point := center + Vector2(cos(angle), sin(angle)) * 10
		draw_line(point, point + Vector2(2, 1), Color(.56, .39, .17, .34), 1, true)

func _ellipse(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for step in range(49):
		var angle := TAU * step / 48
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)

func _surface(color: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box
