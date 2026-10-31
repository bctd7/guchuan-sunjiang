extends "res://education/force_gallery/diagram.gd"
## Drop-in gallery renderer: only zong_reference_v1 uses this implementation.
## Other profiles call the current shared renderer unchanged.
const ZongClock = preload("res://education/force_gallery/zong_timeline.gd")
const DisplayMap = preload("res://education/force_gallery/zong_display.gd")
var reference_active := false
var display_map

func configure(value: Dictionary) -> void:
	reference_active = value.get("diagram_kind","") == "zong_reference_v1"
	if not reference_active:
		super.configure(value)
		return
	assert(value.id == "zong_corner" and value.modes.size() == 2)
	profile = value
	display_map = DisplayMap.new()
	display_map.configure(profile)
	clock = ZongClock.new()
	clock.restart()
	queue_redraw()

func _draw() -> void:
	if not reference_active:
		super._draw()
		return
	if profile.is_empty() or size.x < 2 or size.y < 2: return
	_fit(profile)
	draw_set_transform(draw_origin,0.0,Vector2.ONE*draw_scale)
	var alpha: float = clock.cutaway_alpha()
	if alpha > 0.0: _reference_parts(true,1.0)
	if alpha < 1.0: _reference_parts(false,1.0-alpha)
	if alpha > .99: _reference_gap()
	_reference_forces()
	# Support coordinates never include any moving-member displacement.
	for point in profile.supports:
		var center := project(v3(point),profile)
		draw_line(center-Vector2(12,0)/draw_scale,center+Vector2(12,0)/draw_scale,INK,2.0/draw_scale,true)
	draw_set_transform(Vector2.ZERO)

func project(point: Vector3, view: Dictionary) -> Vector2:
	if not reference_active: return super.project(point,view)
	return _raw_project(display_map.point(point))

func _raw_project(point: Vector3) -> Vector2:
	var view: Dictionary = profile
	return Vector2(point.dot(v3(view.camera_right)),point.dot(v3(view.camera_down)))

func displacement() -> Vector3:
	if not reference_active: return super.displacement()
	var m: Dictionary = profile.modes[clock.mode_index()]
	return v3(m.direction)*float(m.distance)*clock.fraction()

func part_offset(id: String, offset: Vector3) -> Vector3:
	if not reference_active: return super.part_offset(id,offset)
	return offset if id in profile.modes[clock.mode_index()].moving else Vector3.ZERO

func display_vertex(id: String, point: Vector3) -> Vector3:
	return point if reference_active else super.display_vertex(id,point)

func _reference_parts(cut: bool, opacity: float) -> void:
	var triangles: Array = []
	var toward := v3(profile.camera_toward)
	for index in profile.parts.size():
		var part: Dictionary = profile.parts[index]
		var vertices: Array = part.cut_vertices if cut else part.vertices
		var faces: Array = part.cut_faces if cut else part.faces
		var offset := part_offset(part.id,displacement())
		for fi in faces.size():
			var face: Array = faces[fi]
			var source: Array = []
			for vi in face: source.append(v3(vertices[vi])+offset)
			for poly in display_map.polygons(source):
				if poly.size() < 3: continue
				var normal: Vector3 = (poly[1]-poly[0]).cross(poly[2]-poly[0]).normalized()
				if normal.dot(toward) <= .000001: continue
				var polygon := PackedVector2Array()
				var depth := 0.0
				for p in poly:
					polygon.append(_raw_project(p))
					depth += p.dot(toward)
				depth /= float(poly.size())
				var shade := .72+.28*absf(normal.dot(Vector3(.4,.8,.6).normalized()))
				if cut and part.cut_caps[fi]: shade = minf(1.0,shade+.1)
				var color: Color = PALETTE[index%3]
				triangles.append({"points":polygon,"depth":depth,"color":Color(color.r*shade,color.g*shade,color.b*shade,opacity)})
	triangles.sort_custom(func(a,b): return a.depth < b.depth)
	for triangle in triangles:
		if absf((triangle.points[1]-triangle.points[0]).cross(triangle.points[2]-triangle.points[0])) > .000001:
			draw_colored_polygon(triangle.points,triangle.color)
	if cut:
		for part in profile.parts:
			var offset := part_offset(part.id,displacement())
			for edge in part.cut_edges:
				var line := PackedVector2Array()
				for p in display_map.segment(v3(edge[0])+offset,v3(edge[1])+offset): line.append(_raw_project(p))
				draw_polyline(line,Color(INK,.65),1.5/draw_scale,true)

func _reference_gap() -> void:
	var m: Dictionary = profile.modes[clock.mode_index()]
	var remaining: float = float(m.distance)*(1.0-clock.fraction())
	if remaining <= .00001: return
	var contact := v3(m.contacts[0])
	var wall := contact-v3(m.direction)*remaining
	# Only the actual void between this mortise wall and the leg tenon side.
	# These heights lie inside both documented source contact-edge intervals.
	var low := Vector3(0,-.03,0)
	var high := Vector3(0,.03,0)
	var ring := PackedVector2Array([project(wall+low,profile),project(contact+low,profile),project(contact+high,profile),project(wall+high,profile)])
	draw_colored_polygon(ring,Color("d4ece4"))
	draw_line(project(wall+low,profile),project(wall+high,profile),Color(INK,.85),1.6/draw_scale,true)
	draw_line(project(contact+low,profile),project(contact+high,profile),Color(INK,.85),1.6/draw_scale,true)

func _reference_forces() -> void:
	var m: Dictionary = profile.modes[clock.mode_index()]
	var alpha: float = clock.force_alpha()
	var length := clampf(minf(size.x,size.y)*.15,55.0,105.0)/draw_scale
	var anchor3 := v3(m.pull_anchor)+displacement()
	var anchor := project(anchor3,profile)
	var direction := (project(anchor3+v3(m.direction)*.01,profile)-anchor).normalized()
	if alpha > .001: _arrow(anchor,anchor+direction*length*(.65+.35*alpha),Color(FORCE,alpha),1.25)
	var reaction: float = clock.reaction_alpha()
	if reaction <= .001: return
	for contact in m.contacts:
		var start := project(v3(contact),profile)
		var normal := (project(v3(contact)+v3(m.reaction)*.01,profile)-start).normalized()
		_arrow(start,start+normal*length*.84,Color(REACTION,reaction),1.25)
