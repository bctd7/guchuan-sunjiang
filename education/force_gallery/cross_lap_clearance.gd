extends RefCounted
## A plan-view clearance window. The upper slot is underneath its opaque top:
## its dashed window exposes that hidden gap without cutting/changing any mesh.
static func draw(d: Control, view: Dictionary) -> void:
	if not d.profile.has("display_clearance"): return
	var fraction: float = d.clock.fraction(false)
	var alpha := .84*smoothstep(0.0,.25,fraction)
	if alpha <= .001: return
	var m: Dictionary = d.profile.modes[d.mode]
	var shift: float = d.display_displacement().x if d.mode == 0 else d.display_displacement().z
	var shoulder := .44+float(d.profile.display_clearance)
	# Fixed wood occupies [-.42,.42]; only its surrounding slot clearance is
	# highlighted. No pale fill crosses the fixed solid or the moving shoulder.
	for interval in [Vector2(-shoulder+shift,-.42),Vector2(.42,shoulder+shift)]:
		if interval.y-interval.x <= .00001: continue
		var a := Vector2(interval.x,-.38) if d.mode == 0 else Vector2(-.38,interval.x)
		var b := Vector2(interval.y,.38) if d.mode == 0 else Vector2(.38,interval.y)
		d.draw_colored_polygon(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),Color(d.PAPER,alpha))
		# Dashed boundaries mean hidden underside on the light vertical wood.
		for coordinate in [interval.x,interval.y]:
			var start := Vector2(coordinate,-.38) if d.mode == 0 else Vector2(-.38,coordinate)
			var end := Vector2(coordinate,.38) if d.mode == 0 else Vector2(.38,coordinate)
			if d.mode == 0:
				d.draw_line(start,end,Color(d.INK,alpha*.5),1.0/d.draw_scale,true)
			else:
				for i in range(0,8,2):
					d.draw_line(start.lerp(end,float(i)/8),start.lerp(end,float(i+1)/8),Color(d.INK,alpha*.65),1.0/d.draw_scale,true)
