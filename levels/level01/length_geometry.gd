extends RefCounted
## The single physical length definition for level 1. apply() edits local meshes
## only; callers animate toward seated_pose(), then reveal the removable pins.
## Every replacement mesh is private to the supplied part, including clones.
const LENGTHS := {
	"blind_tenon": {"short": .27, "correct": .42, "long": .62},
	"dovetail": {"short": .62, "correct": .93, "long": 1.25},
	"through_tenon": {"short": 5.82, "correct": 6.32, "long": 7.02},
}
const PIN_RADIUS := .04
const PIN_END_DISTANCE := .15
const RIB_OUTER_FACE := 2.97
const HOLE_SEGMENTS := 48

static func kind(piece_id: String) -> String:
	if piece_id.begins_with("rib_"): return "blind_tenon"
	if piece_id in ["bow", "stern"]: return "dovetail"
	if piece_id.begins_with("beam"): return "through_tenon"
	return ""

static func span(piece_id: String, length: String = "correct") -> float:
	var family := kind(piece_id)
	if family.is_empty(): return 0.0
	return float(LENGTHS[family].get(length, LENGTHS[family].correct))

static func reference_span(piece_id: String) -> float:
	return float({"blind_tenon": .45,"dovetail": .95,"through_tenon": 6.32}.get(kind(piece_id),0.0))

static func seated_pose(piece_id: String, length: String = "correct") -> Transform3D:
	var offset := Vector3.ZERO
	if length == "long":
		if piece_id.begins_with("rib_"):
			offset.x = -.18 if piece_id.begins_with("rib_l") else .18
		elif piece_id in ["bow", "stern"]:
			offset.z = -.32 if piece_id == "bow" else .32
	return Transform3D(Basis.IDENTITY, offset)

static func measurement(piece_id: String, length: String = "correct") -> Dictionary:
	var family := kind(piece_id)
	var size := span(piece_id, length)
	var data := {"kind": family, "span": size, "reference_span": reference_span(piece_id),
		"seated_offset": seated_pose(piece_id, length).origin, "unit_ticks": 100}
	if family == "blind_tenon":
		data.merge({"slot_depth": .45, "engagement": minf(size, .44),
			"shoulder_gap": .18 if length == "long" else 0.0,
			"tip_clearance": .01 if length == "long" else .45-size})
	elif family == "dovetail":
		data.merge({"groove_span": .95, "engagement": minf(size, .93),
			"shoulder_gap": .32 if length == "long" else 0.0})
	elif family == "through_tenon":
		var pin_x := size*.5-PIN_END_DISTANCE
		data.merge({"pin_center_x": pin_x, "pin_radius": PIN_RADIUS,
			"pins_accessible": pin_x-PIN_RADIUS >= RIB_OUTER_FACE-.0001,
			"axial_play": maxf(0.0, pin_x-PIN_RADIUS-RIB_OUTER_FACE)})
	return data

static func caption(piece_id: String, length: String = "correct") -> String:
	var family := kind(piece_id)
	if family == "blind_tenon": return "榫长 %d 格 · 盲槽深 45 格" % roundi(span(piece_id,length)*100)
	if family == "dovetail": return "滑榫长 %d 格 · 滑槽长 95 格" % roundi(span(piece_id,length)*100)
	if family == "through_tenon": return "横梁长 %d 格 · 两端木销定位" % roundi(span(piece_id,length)*100)
	return ""

static func apply(part: Node3D, piece_id: String, length: String = "correct") -> void:
	if not is_instance_valid(part): return
	var family := kind(piece_id)
	if family.is_empty(): return
	var size := span(piece_id,length)
	if family == "blind_tenon":
		var tip := part.find_child("RootTenon",true,false) as MeshInstance3D
		if tip == null: return
		tip.mesh = _box(Vector3(size,.27,.30))
		var side := -1.0 if piece_id.begins_with("rib_l") else 1.0
		tip.position = Vector3(side*(.55-size*.5),.38,0)
	elif family == "dovetail":
		if part.get_child_count() == 0: return
		var form := part.get_child(0) as Node3D
		if form == null or form.get_child_count() == 0: return
		var tip := form.get_child(0) as MeshInstance3D
		if tip == null: return
		tip.mesh = _dovetail(4.45-size,4.45)
		tip.position = Vector3.ZERO
	elif family == "through_tenon":
		if part.get_child_count() == 0: return
		var body := part.get_child(0) as MeshInstance3D
		if body == null: return
		var station := body.position.z
		body.mesh = _drilled_beam(size)
		body.position = Vector3(0,2.34,station)
		# Preserve the original end-grain accents and narrow grain highlight.
		for index in range(1,part.get_child_count()):
			var accent := part.get_child(index) as MeshInstance3D
			if accent == null: continue
			if accent.mesh is BoxMesh and accent.mesh.size.x < .03:
				accent.mesh = _box(Vector3(.016,.26,.30))
				accent.position.x = signf(accent.position.x)*(size*.5+.01)
			elif accent.mesh is BoxMesh and accent.mesh.size.x > 5.0:
				accent.mesh = _box(Vector3(size-.07,.005,.009))
				accent.position.x = 0.0
		var pins := part.get_node_or_null("LengthFasteners") as Node3D
		if pins == null:
			pins = Node3D.new()
			pins.name = "LengthFasteners"
			part.add_child(pins)
		for child in pins.get_children():
			pins.remove_child(child)
			child.free()
		var material := body.material_override.duplicate() as StandardMaterial3D if body.material_override is StandardMaterial3D else StandardMaterial3D.new()
		material.albedo_color = Color("94714c")
		material.roughness = .9
		for side in [-1.0,1.0]:
			var pin := MeshInstance3D.new()
			pin.name = "WoodPinLeft" if side < 0 else "WoodPinRight"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = PIN_RADIUS
			cylinder.bottom_radius = PIN_RADIUS
			cylinder.height = .46
			cylinder.radial_segments = HOLE_SEGMENTS
			pin.mesh = cylinder
			pin.position = Vector3(side*(size*.5-PIN_END_DISTANCE),2.34,station)
			pin.material_override = material
			pins.add_child(pin)
		pins.set_meta("accessible",length != "short")
		pins.hide()
	part.set_meta("length_geometry",measurement(piece_id,length))

static func set_fasteners_visible(part: Node3D, enabled: bool) -> void:
	if not is_instance_valid(part): return
	var pins := part.get_node_or_null("LengthFasteners") as Node3D
	if pins != null: pins.visible = enabled and bool(pins.get_meta("accessible",false))

static func _box(size: Vector3) -> BoxMesh:
	var result := BoxMesh.new()
	result.size = size
	return result

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Callers list the rectangle with its mathematical cross product outward.
	# Godot uses clockwise front faces, so reverse both triangles consistently.
	for vertex in [a,c,b,a,d,c]: surface.add_vertex(vertex)

static func _dovetail(z_min: float, z_max: float) -> ArrayMesh:
	var polygon := PackedVector2Array([Vector2(-.405,.215),Vector2(.405,.215),Vector2(.237,.705),Vector2(-.237,.705)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		for side in [0,1]:
			for corner in ([0,1,2] if side == 0 else [2,1,0]):
				var point: Vector2 = polygon[indices[i+corner]]
				surface.add_vertex(Vector3(point.x,point.y,z_min if side == 0 else z_max))
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		_quad(surface,Vector3(a.x,a.y,z_min),Vector3(b.x,b.y,z_min),Vector3(b.x,b.y,z_max),Vector3(a.x,a.y,z_max))
	surface.generate_normals()
	return surface.commit()

static func _stock(surface: SurfaceTool, low: float, high: float, close_low := false, close_high := false) -> void:
	var a := Vector3(low,-.13,-.15)
	var b := Vector3(high,.13,.15)
	# Only the two physical beam ends have caps. Intermediate ends join the
	# drilled regions; retaining those caps creates coincident internal sheets.
	if close_low: _quad(surface,Vector3(a.x,a.y,a.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z))
	if close_high: _quad(surface,Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z))
	_quad(surface,Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z))
	_quad(surface,Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z))
	_quad(surface,Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z))
	_quad(surface,Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z))

static func _drilled_beam(size: float) -> ArrayMesh:
	# The two small vertical bores are actual open topology through the stock.
	# Around each bore a radial mesh runs from its circle to a rectangular edge.
	# Three solid stretches complete the original uniform rectangular section.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var center := size*.5-PIN_END_DISTANCE
	_stock(surface,-size*.5,-center-.06,true,false)
	_stock(surface,-center+.06,center-.06)
	_stock(surface,center+.06,size*.5,false,true)
	for hole_x in [-center,center]:
		# Include rectangle corner rays so the outside is exactly rectangular.
		var angles: Array[float] = []
		for i in HOLE_SEGMENTS: angles.append(TAU*float(i)/HOLE_SEGMENTS)
		var corner := atan2(.15,.06)
		for angle in [corner,PI-corner,PI+corner,TAU-corner]: angles.append(angle)
		angles.sort()
		for i in angles.size():
			var a := angles[i]
			var b := angles[(i+1)%angles.size()]
			var inner_a := Vector3(hole_x+cos(a)*PIN_RADIUS,-.13,sin(a)*PIN_RADIUS)
			var inner_b := Vector3(hole_x+cos(b)*PIN_RADIUS,-.13,sin(b)*PIN_RADIUS)
			var radius_a := minf(.06/maxf(absf(cos(a)),.000001),.15/maxf(absf(sin(a)),.000001))
			var radius_b := minf(.06/maxf(absf(cos(b)),.000001),.15/maxf(absf(sin(b)),.000001))
			var outer_a := Vector3(hole_x+cos(a)*radius_a,-.13,sin(a)*radius_a)
			var outer_b := Vector3(hole_x+cos(b)*radius_b,-.13,sin(b)*radius_b)
			var up := Vector3(0,.26,0)
			_quad(surface,inner_a,inner_b,inner_b+up,inner_a+up)
			# The X edges meet adjacent stock, and are not exposed surfaces.
			# Only the rectangle's Z edges form the outside of the beam.
			if not (is_equal_approx(outer_a.x,outer_b.x) and is_equal_approx(absf(outer_a.x-hole_x),.06)):
				_quad(surface,outer_a,outer_a+up,outer_b+up,outer_b)
			_quad(surface,inner_a,outer_a,outer_b,inner_b)
			_quad(surface,inner_a+up,inner_b+up,outer_b+up,outer_a+up)
	surface.generate_normals()
	return surface.commit()
