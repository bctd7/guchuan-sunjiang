extends Control
const Clock = preload("res://classroom/science/force_gallery/timeline.gd")
const PullClock = preload("res://classroom/science/force_gallery/pull_timeline.gd")
const PullEffects = preload("res://classroom/science/force_gallery/pull_effects.gd")
const CrossLapClearance = preload("res://classroom/science/force_gallery/cross_lap_clearance.gd")
const INK := Color("233d42")
const PAPER := Color("f5f2e9")
const PALETTE := [Color("c49b67"),Color("eece94"),Color("d9ae76")]
const FORCE := Color("d65e13")
const CONTACT := Color("008f85")
const REACTION := Color("2454a0")
var clock = Clock.new()
var zong_load_clock = Clock.new()
var profile: Dictionary = {}
var mode: int:
	get: return clock.cycles % profile.modes.size() if not profile.is_empty() else 0
var draw_scale := 1.0
var draw_origin := Vector2.ZERO

func configure(value: Dictionary) -> void:
	profile = value
	clock = PullClock.new() if is_blocked_pull() else Clock.new()
	if is_blocked_pull(): clock.configure(profile.has("cutaway"))
	clock.restart()
	queue_redraw()

func is_blocked_pull() -> bool:
	return profile.get("force_kind","") == "blocked_pull"

func advance(delta: float) -> void:
	clock.advance(delta)
	queue_redraw()

func v3(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func view_data() -> Dictionary:
	return profile

func load_clock():
	if is_blocked_pull(): return clock
	if not profile.has("cutaway"): return clock
	# Same scene: whole -> fade shell -> load one -> load two -> restore shell.
	# Only the illustration shell changes opacity; solid geometry never morphs.
	zong_load_clock.elapsed = clampf((clock.elapsed-1.6)*clock.DURATION/4.4 if mode == 0 else clock.elapsed*clock.DURATION/4.4,0.0,clock.DURATION)
	return zong_load_clock

func cutaway_alpha() -> float:
	if not profile.has("cutaway"): return 0.0
	if is_blocked_pull(): return clock.cutaway_alpha()
	return smoothstep(.45,1.55,clock.elapsed) if mode == 0 else 1.0-smoothstep(4.45,5.55,clock.elapsed)

func project(point: Vector3, view: Dictionary) -> Vector2:
	if view.get("projection","") == "top_orthographic": return Vector2(point.x,point.z)
	# Cross lap alone: a fixed high view shows both complete crossing members.
	# Y still has a visible projection, so downward load is not drawn along Z.
	if view.get("projection","") == "high_oblique": return Vector2(point.x,point.z*.82-point.y*.57)
	if view.iso: return Vector2((point.x-point.z)*.8660254,(point.x+point.z)*.35-point.y)
	return Vector2(point.z,-point.y) if view.axis == 0 else Vector2(point.x,-point.y)

func display_vertex(id: String, point: Vector3) -> Vector3:
	# Cross-lap lesson only: widen the drawn slot clearance, never the OBJ,
	# collision shape or assembly. Keep the neck widths/contact faces unchanged.
	var extra: float = profile.get("display_clearance",0.0)
	if extra > 0:
		if id == "lower" and absf(point.x) >= .43: point.x += signf(point.x)*extra
		if id == "upper" and absf(point.z) >= .43: point.z += signf(point.z)*extra
	return point

func display_displacement() -> Vector3:
	return displacement()*(1.0+float(profile.get("display_clearance",0.0))/.02)

func rings(part: Dictionary, view: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in part.polygons:
		var ring := PackedVector2Array()
		for point in polygon:
			ring.append(Vector2(point[1],-point[0]) if view.axis == 0 else Vector2(point[0],-point[1]))
		result.append(ring)
	return result

func displacement() -> Vector3:
	var m: Dictionary = profile.modes[mode]
	var timing = load_clock()
	var fraction: float = timing.fraction(m.removable)
	if not is_blocked_pull() and profile.has("cutaway") and timing.elapsed >= 1.05 and timing.elapsed < 1.85:
		var age: float = timing.elapsed-1.05
		fraction *= 1.0-.18*exp(-5.0*age)*pow(sin(age*14.0),2)
	return v3(m.initial)+v3(m.direction)*float(m.distance)*fraction

func _fit(view: Dictionary) -> void:
	var points: Array[Vector2] = []
	for part in view.parts:
		var offsets := [Vector3.ZERO]
		# All retained load cases share one framing, independent of cycle phase.
		for m in profile.modes:
			if part.id in m.moving:
				var gain := 1.0+float(profile.get("display_clearance",0.0))/.02
				offsets.append_array([v3(m.initial)*gain,(v3(m.initial)+v3(m.direction)*float(m.distance))*gain])
		for offset in offsets:
			if view.iso:
				for vertex in part.vertices: points.append(project(display_vertex(part.id,v3(vertex))+offset,view))
			else:
				for ring in rings(part,view):
					for point in ring: points.append(point+project(offset,view))
	var low := Vector2(INF,INF)
	var high := -low
	for point in points: low = low.min(point); high = high.max(point)
	var span := (high-low).max(Vector2(.1,.1))
	var available := size*Vector2(.70,.70)
	if profile.has("overview"): available.x *= .72
	draw_scale = minf(available.x/span.x,available.y/span.y)
	var center := size*Vector2(.39 if profile.has("overview") else .5,.53)
	draw_origin = center-(low+high)*.5*draw_scale

func _draw() -> void:
	if profile.is_empty() or size.x < 2 or size.y < 2: return
	var view := view_data()
	_fit(view)
	# Shared picture transform is static. Per-part displacement remains limited
	# to the current loaded member; fixed solids and supports never inherit sway.
	draw_set_transform(draw_origin,0.0,Vector2.ONE*draw_scale)
	if profile.has("cutaway"):
		var alpha := cutaway_alpha()
		if alpha > 0: _draw_parts(view,displacement(),false,true)
		if alpha < 1: _draw_parts(view,displacement(),false,false,1.0-alpha)
	else: _draw_parts(view,display_displacement())
	CrossLapClearance.draw(self,view)
	_draw_effects(view)
	_draw_supports(view)
	draw_set_transform(Vector2.ZERO)
	if profile.has("overview"): _overview()

func part_offset(id: String, offset: Vector3) -> Vector3:
	return offset if id in profile.modes[mode].moving else Vector3.ZERO

func _draw_parts(view: Dictionary, offset: Vector3, exploded := false, cut := false, opacity := 1.0) -> void:
	var m: Dictionary = profile.modes[mode]
	if view.iso:
		var triangles: Array = []
		for index in view.parts.size():
			var part: Dictionary = view.parts[index]
			var shift := part_offset(part.id,offset)
			if exploded:
				shift = {"leg":Vector3(0,-1.2,0),"xrail":Vector3(1.2,0,0),"zrail":Vector3(0,0,1.2)}.get(part.id,Vector3.ZERO)
			var vertices: Array = part.cut_vertices if cut else part.vertices
			var faces: Array = part.cut_faces if cut else part.faces
			for face_index in faces.size():
				var face: Array = faces[face_index]
				var points := PackedVector2Array()
				var depth := 0.0
				for vertex_index in face:
					var vertex := display_vertex(part.id,v3(vertices[vertex_index]))+shift
					points.append(project(vertex,view))
					if view.get("projection","") == "top_orthographic": depth += vertex.y
					else: depth += vertex.z*.57+vertex.y*.82 if view.get("projection","") == "high_oblique" else vertex.x+vertex.z+vertex.y*(.7 if profile.has("cutaway") else 1.8)
				var normal := (v3(vertices[face[1]])-v3(vertices[face[0]])).cross(v3(vertices[face[2]])-v3(vertices[face[0]])).normalized()
				if view.get("projection","") == "top_orthographic" and normal.y <= .000001: continue
				# OBJ source has verified outward normals; reject rear faces so
				# they cannot paint over the true front section caps.
				if profile.has("cutaway") and normal.dot(Vector3(1,.7,1)) <= .000001: continue
				var shade := .72+.28*absf(normal.dot(Vector3(.4,.8,.6).normalized()))
				var color: Color = PALETTE[index%3]
				if cut and part.cut_caps[face_index]: shade = minf(1.0,shade+.10)
				triangles.append({"points":points,"depth":depth,"color":Color(color.r*shade,color.g*shade,color.b*shade,opacity)})
		triangles.sort_custom(func(a,b): return a.depth < b.depth)
		for triangle in triangles:
			if absf((triangle.points[1]-triangle.points[0]).cross(triangle.points[2]-triangle.points[0])) > .000001:
				draw_colored_polygon(triangle.points,triangle.color)
		if cut:
			for part in view.parts:
				var shift := part_offset(part.id,offset)
				for edge in part.cut_edges:
					draw_line(project(v3(edge[0])+shift,view),project(v3(edge[1])+shift,view),Color(INK,.72),1.7/draw_scale,true)
		return
	for index in view.parts.size():
		var part: Dictionary = view.parts[index]
		var shift := project(part_offset(part.id,offset),view)
		var polygons := rings(part,view)
		polygons.sort_custom(func(a,b): return polygon_area(a)>polygon_area(b))
		for polygon in polygons:
			var nesting := 0
			for other in polygons:
				if polygon_area(other)>polygon_area(polygon) and Geometry2D.is_point_in_polygon(polygon[0],other): nesting += 1
			var translated := PackedVector2Array()
			for point in polygon: translated.append(point+shift)
			draw_colored_polygon(translated,PALETTE[index%3] if nesting%2 == 0 else PAPER)
			translated.append(translated[0])
			draw_polyline(translated,INK,1.5/draw_scale,true)

func polygon_area(p: PackedVector2Array) -> float:
	var area := 0.0
	for i in p.size(): area += p[i].cross(p[(i+1)%p.size()])
	return absf(area)

func support_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var m: Dictionary = profile.modes[mode]
	if m.has("supports"):
		for point in m.supports: points.append(project(display_vertex(m.fixed,v3(point)),view_data()))
		return points
	if profile.has("supports"):
		for point in profile.supports: points.append(project(v3(point),view_data()))
		return points
	for load_case in profile.modes:
		for path in load_case.paths:
			var point := project(v3(path[-1]),view_data())
			if not points.has(point): points.append(point)
	return points

func _draw_supports(_view: Dictionary) -> void:
	var m: Dictionary = profile.modes[mode]
	if m.has("supports"):
		# Fade during the seated handover; the next fixed wood gets its own marks.
		var alpha := smoothstep(.1,.4,clock.elapsed)*(1.0-smoothstep(4.9,5.4,clock.elapsed))
		var axis := project(v3(m.support_direction),view_data()).normalized()*12.0/draw_scale
		for point in support_points(): draw_line(point-axis,point+axis,Color(INK,alpha),2/draw_scale,true)
		return
	# All support marks remain visible at fixed points through every load/fade.
	for point in support_points():
		draw_line(point-Vector2(12,0)/draw_scale,point+Vector2(12,0)/draw_scale,INK,2/draw_scale,true)

func _arrow(start: Vector2, end: Vector2, color: Color, emphasis := 1.0) -> void:
	if start.distance_to(end) < .0001: return
	var direction := (end-start).normalized()
	var head := minf(15.0*emphasis/draw_scale,start.distance_to(end)*.4)
	draw_line(start,end-direction*head,color,5.5*emphasis/draw_scale,true)
	draw_colored_polygon(PackedVector2Array([end,end-direction*head+direction.orthogonal()*head*.5,end-direction*head-direction.orthogonal()*head*.5]),color)

func _draw_effects(view: Dictionary) -> void:
	if is_blocked_pull():
		PullEffects.draw(self,view)
		return
	if profile.has("cutaway"):
		_draw_zong_effects(view)
		return
	if view.get("projection","") == "top_orthographic":
		_draw_top_effects(view)
		return
	var timing = load_clock()
	var m: Dictionary = profile.modes[mode]
	var move_dir := project(v3(m.direction),view).normalized()
	# The arrow points into the actual moving member, and follows it on removal.
	var bounds := Rect2()
	var first := true
	for part in view.parts:
		if part.id not in m.moving: continue
		var points: Array[Vector2] = []
		if view.iso:
			for vertex in part.vertices: points.append(project(v3(vertex),view))
		else:
			for ring in rings(part,view):
				for point in ring: points.append(point)
		for point in points:
			if first: bounds = Rect2(point,Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	var anchor := bounds.get_center()+project(displacement(),view)
	var alpha: float = timing.force_alpha()
	if view.get("projection","") == "high_oblique":
		# Project a world-Y arrow above the upper member, including foreshortening.
		var tip := project(Vector3(0,.4,0)+displacement(),view)
		var tail := project(Vector3(0,1.55,0)+displacement(),view)
		_arrow(tail.lerp(tip,1.0-alpha),tip,Color(FORCE,alpha))
	else: _arrow(anchor-move_dir*95/draw_scale,anchor,Color(FORCE,alpha))
	if not timing.touching(m.removable): return
	for contact in m.contacts:
		var point := project(v3(contact),view)
		draw_circle(point,6.0/draw_scale,Color(CONTACT,.95))
		var reaction := project(v3(m.reaction),view).normalized() if m.has("reaction") else -move_dir
		var reaction_offset := project(Vector3(0,.46,0),view) if view.get("projection","") == "high_oblique" else reaction*50/draw_scale
		_arrow(point,point+reaction_offset,Color(REACTION,alpha))
	var progress: float = timing.pulse()
	if progress < 0: return
	for path in m.paths:
		var curve := Curve2D.new()
		for point in path:
			var projected := project(v3(point),view)
			if curve.point_count == 0 or curve.get_point_position(curve.point_count-1).distance_to(projected) > .000001: curve.add_point(projected)
		var length := curve.get_baked_length()
		if length < .000001: continue
		for i in range(60):
			var u := float(i)/60.0
			var strength := exp(-pow((u-progress)/.11,2))*.98
			if strength < .01: continue
			var a := curve.sample_baked(u*length)
			var b := curve.sample_baked(minf(1,u+1.0/60)*length)
			# Clip the short light band to the fixed member; never through air.
			if not view.iso:
				var normal := (b-a).normalized().orthogonal()*4.5/draw_scale
				var strip := PackedVector2Array([a+normal,b+normal,b-normal,a-normal])
				for part in view.parts:
					if part.id in m.moving: continue
					for ring in rings(part,view):
						for polygon in Geometry2D.intersect_polygons(strip,ring): draw_colored_polygon(polygon,Color(CONTACT,strength))
			else:
				var normal := (b-a).normalized().orthogonal()*3.5/draw_scale
				var strip := PackedVector2Array([a+normal,b+normal,b-normal,a-normal])
				for part in view.parts:
					if part.id in m.moving: continue
					for face in part.faces:
						var triangle := PackedVector2Array()
						for index in face: triangle.append(project(v3(part.vertices[index]),view))
						if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0])) < .000001: continue
						for polygon in Geometry2D.intersect_polygons(strip,triangle): draw_colored_polygon(polygon,Color(CONTACT,strength))

func _draw_zong_effects(view: Dictionary) -> void:
	var timing = load_clock()
	var m: Dictionary = profile.modes[mode]
	var alpha: float = timing.force_alpha()
	var contact := project(v3(m.contacts[0]),view)
	var loaded := Vector3(1.9,1.0,.5) if mode == 0 else Vector3(.5,1.0,1.9)
	var tip := project(loaded+displacement(),view)
	_arrow(tip-Vector2(0,130)/draw_scale,tip,Color(FORCE,alpha),1.45)
	if not timing.touching(false): return
	var reaction := project(v3(m.reaction),view).normalized()
	_arrow(contact,contact+reaction*76.0/draw_scale,Color(REACTION,alpha),1.4)
	var beat := .5+.5*sin(timing.elapsed*9.0)
	draw_circle(contact,7.5/draw_scale,Color(CONTACT,.98))
	draw_arc(contact,(12.0+5.0*beat)/draw_scale,0,TAU,32,Color(CONTACT,.35+.25*beat),2.5/draw_scale,true)
	var progress: float = timing.pulse()
	for path in m.paths:
		var curve := Curve2D.new()
		for point in path: curve.add_point(project(v3(point),view))
		var length := curve.get_baked_length()
		# Continuous faint route plus a longer bright travelling pulse, inside the leg.
		draw_polyline(curve.get_baked_points(),Color(CONTACT,.30),5.0/draw_scale,true)
		if progress < 0: continue
		for i in range(60):
			var u := float(i)/60.0
			var strength := exp(-pow((u-progress)/.18,2))*.98
			if strength < .01: continue
			draw_line(curve.sample_baked(u*length),curve.sample_baked(minf(1,u+1.0/60)*length),Color(CONTACT,strength),11.0/draw_scale,true)

func _draw_top_effects(view: Dictionary) -> void:
	# True plan view: -Y enters the page (cross), +Y leaves it (dot).
	# Never substitute an in-plane arrow for a vertical load.
	var timing = load_clock()
	var m: Dictionary = profile.modes[mode]
	var alpha: float = timing.force_alpha()
	var contact := project(v3(m.contacts[0]),view)
	var radius := (11.0+3.0*alpha)/draw_scale
	var force_center := contact+Vector2(-24,-24)/draw_scale
	var reaction_center := contact+Vector2(24,24)/draw_scale
	if alpha > .001:
		draw_line(force_center,contact,Color(FORCE,alpha*.55),2.0/draw_scale,true)
		draw_circle(force_center,radius,Color(PAPER,.94))
		draw_arc(force_center,radius,0,TAU,40,Color(FORCE,alpha),3.5/draw_scale,true)
		var arm := radius*.45
		for sign in [-1,1]: draw_line(force_center+Vector2(-arm,arm*sign),force_center+Vector2(arm,-arm*sign),Color(FORCE,alpha),3.5/draw_scale,true)
	if not timing.touching(false): return
	draw_circle(contact,5.0/draw_scale,CONTACT)
	draw_line(contact,reaction_center,Color(REACTION,alpha*.55),2.0/draw_scale,true)
	draw_circle(reaction_center,radius,Color(PAPER,.94))
	draw_arc(reaction_center,radius,0,TAU,40,Color(REACTION,alpha),3.5/draw_scale,true)
	draw_circle(reaction_center,4.0/draw_scale,Color(REACTION,alpha))
	var progress: float = timing.pulse()
	if progress < 0: return
	for path in m.paths:
		var curve := Curve2D.new()
		for point in path:
			var projected := project(v3(point),view)
			if curve.point_count == 0 or curve.get_point_position(curve.point_count-1).distance_to(projected) > .000001: curve.add_point(projected)
		var length := curve.get_baked_length()
		if length < .000001: continue
		for i in range(60):
			var u := float(i)/60.0
			var strength := exp(-pow((u-progress)/.14,2))*.95
			if strength < .01: continue
			# These source-verified paths stay inside the supporting solid.
			draw_line(curve.sample_baked(u*length),curve.sample_baked(minf(1,u+1.0/60)*length),Color(CONTACT,strength),7.0/draw_scale,true)

func _overview() -> void:
	# Current OBJ surfaces, deliberately separated to reveal unequal tenons.
	var overview: Dictionary = profile.overview
	var scale := minf(size.x*.22/5.5,size.y*.5/5.5)
	draw_set_transform(Vector2(size.x*.80,size.y*.58),0,Vector2.ONE*scale)
	_draw_parts(overview,Vector3.ZERO,true)
	draw_set_transform(Vector2.ZERO)
