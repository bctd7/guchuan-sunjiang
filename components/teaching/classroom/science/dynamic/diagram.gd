extends Control
## Qualitative geometry only. Arrows are forces ON the moving member;
## A timed light band through the fixed member is a qualitative load path.
const INK = Color("233d42")
const WOOD = Color("c49b67")
const TAIL = Color("eece94")
const CONTACT = Color("008f85")
const REACTION = Color("2454a0")
const FLOW = Color("9b622a")
const FORCE = Color("d65e13")
const CLEARANCE := 6.0
const SLOPE := 35.0 / 80.0
const STOP := CLEARANCE / SLOPE
const CYCLE := 6.0
var elapsed := 0.0
var playing := true
var completed_cycles := 0

func advance(delta: float) -> void:
	if playing:
		var total := elapsed + maxf(delta,0.0)
		completed_cycles += int(floor(total/CYCLE))
		elapsed = fposmod(total,CYCLE)
	queue_redraw()

func replay() -> void:
	elapsed = 0.0
	completed_cycles = 0
	playing = true
	queue_redraw()

func displacement() -> float:
	return STOP * smoothstep(.15,1.05,elapsed) * (1.0-smoothstep(4.5,5.9,elapsed))

func touching() -> bool:
	return elapsed >= 1.05 and elapsed <= 4.5

func force_alpha() -> float:
	return smoothstep(.1,1.05,elapsed)*(1.0-smoothstep(1.45,2.0,elapsed))

func reaction_alpha() -> float:
	return smoothstep(1.05,1.22,elapsed)*(1.0-smoothstep(1.45,2.0,elapsed)) if touching() else 0.0

func contact_alpha() -> float:
	if not touching(): return 0.0
	return 0.12+0.88*sin(PI*clampf((elapsed-1.05)/.65,0.0,1.0))

func pulse_progress() -> float:
	if not touching() or elapsed < 2.0 or elapsed > 4.25: return -1.0
	return (elapsed-2.0)/2.25

func support_alpha() -> float:
	return smoothstep(3.95,4.25,elapsed)*(1.0-smoothstep(4.35,4.5,elapsed)) if touching() else 0.0

func base_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(220,220),Vector2(419,220),Vector2(384,300),Vector2(384,312),Vector2(576,312),Vector2(576,300),Vector2(541,220),Vector2(740,220),Vector2(740,365),Vector2(220,365)])

func moving_polygon() -> PackedVector2Array:
	var d := displacement()
	return PackedVector2Array([Vector2(370,130-d),Vector2(590,130-d),Vector2(590,220-d),Vector2(535,220-d),Vector2(570,300-d),Vector2(390,300-d),Vector2(425,220-d),Vector2(370,220-d)])

func contact_point(side: int) -> Vector2:
	return Vector2(480+side*(61.0+90.0)*0.5,(220.0+300.0-STOP)*0.5)

func reaction_vector(side: int) -> Vector2:
	# In screen coordinates, positive y is down. A right face slopes down/right;
	# the force of the slot ON the tongue therefore points left/down.
	return Vector2(-side*43.0,43.0*SLOPE)

func pull_arrow() -> PackedVector2Array:
	var at := Vector2(480,130-displacement())
	return PackedVector2Array([at,at+Vector2(0,-82)])

func force_path(side: int) -> Curve2D:
	var curve := Curve2D.new()
	# Starts at actual contact, traverses only the fixed slot member, then support.
	curve.add_point(contact_point(side),Vector2.ZERO,Vector2(side*35,15))
	curve.add_point(Vector2(480+side*170,365),Vector2(0,-40),Vector2.ZERO)
	return curve

func _draw() -> void:
	var s := minf(1.0,minf(size.x / 960.0,size.y / 480.0)*0.86)
	var origin := (size - Vector2(960,480)*s)/2.0
	# Base and support stay in one fixed frame. Only moving_polygon follows
	# the bounded loading/return displacement; contact never rotates through wood.
	draw_set_transform(origin,0.0,Vector2.ONE*s)
	_section()
	draw_set_transform(Vector2.ZERO)

func _poly(p: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(p,color)
	var outline := p.duplicate()
	outline.append(outline[0])
	draw_polyline(outline,INK,2.0,true)

func _arrow(a: Vector2, b: Vector2, color: Color, width: float = 3.0) -> void:
	var v := (b-a).normalized()
	var head := minf(15.0,a.distance_to(b)*0.42)
	# Shaft stops at the head base, so the triangle stays crisp at small sizes.
	draw_line(a,b-v*head,color,width*1.7*minf(1.0,a.distance_to(b)/16.0),true)
	draw_colored_polygon(PackedVector2Array([b,b-v*head+v.orthogonal()*head*0.5,b-v*head-v.orthogonal()*head*0.5]),color)

func _support(x: float, y: float) -> void:
	draw_line(Vector2(x-40,y),Vector2(x+40,y),INK,4)
	for i in range(8):
		var xx := x-40+i*10
		draw_line(Vector2(xx,y),Vector2(xx-10,y+13),INK,1.5,true)

func _section() -> void:
	_poly(base_polygon(),WOOD)
	_poly(moving_polygon(),TAIL)
	_support(310,365)
	_support(650,365)
	if force_alpha() > 0.01:
		var arrow := pull_arrow()
		_arrow(arrow[0],arrow[0].lerp(arrow[1],force_alpha()),Color(FORCE,force_alpha()),4)
	if touching():
		for side in [-1,1]: _pulse(force_path(side))
		for side in [-1,1]:
			var a := Vector2(480+side*61,220)
			var b := Vector2(480+side*90,300-STOP)
			draw_line(a,b,Color(CONTACT,contact_alpha()),7,true)
			var mid := contact_point(side)
			if reaction_alpha() > 0.01:
				_arrow(mid,mid+reaction_vector(side),Color(REACTION,reaction_alpha()),3)
			if support_alpha() > 0:
				draw_line(Vector2(480+side*170-36,365),Vector2(480+side*170+36,365),Color(CONTACT,support_alpha()*0.65),7,true)

func _pulse(curve: Curve2D) -> void:
	var progress := pulse_progress()
	if progress < 0: return
	var length := curve.get_baked_length()
	# One soft band, not a stream of particles. Each segment is a bounded
	# portion of the same interior curve; no trail through the air or tongue.
	for i in range(48):
		var u := float(i)/48.0
		var distance := absf(u-progress)
		var alpha := exp(-pow(distance/0.11,2.0))*.98
		if alpha > 0.01:
			var a := curve.sample_baked(length*u)
			var b := curve.sample_baked(length*(u+1.0/48.0))
			_band_segment(a,b,Color(CONTACT,alpha*0.20),18)
			_band_segment(a,b,Color(CONTACT,alpha),7)

func _band_segment(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var normal := (b-a).normalized().orthogonal()*width/2.0
	var strip := PackedVector2Array([a+normal,b+normal,b-normal,a-normal])
	# Even the soft halo is clipped to A; nothing leaks into the clearance.
	for polygon in Geometry2D.intersect_polygons(strip,base_polygon()):
		draw_colored_polygon(polygon,color)

