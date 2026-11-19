extends RefCounted
## Actual local ship members. Box boolean meshing keeps all slots physically open.
const SHAFT_RADIUS := 0.17
const BEARING_RADIUS := 0.20
static var _pieces = preload("res://models/ship/model_variants.gd").new()
const Look = preload("res://components/teaching/classroom/display/workshop_look.gd")
static var _wood_finishes: Dictionary = {}

static func wood(color := Color("b89569"), axis := 0) -> StandardMaterial3D:
	var key := color.to_html()+str(axis)
	if _wood_finishes.has(key): return _wood_finishes[key]
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.roughness = .84
	finish.metallic_specular = .22
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	finish.albedo_texture = Look.grain_texture()
	finish.uv1_triplanar = true
	finish.uv1_triplanar_sharpness = 12
	finish.uv1_scale = Vector3(3.4,3.4,3.4)
	finish.uv1_scale[axis] = .28
	_wood_finishes[key] = finish
	return finish

# A small planed edge catches the light without rounding off a fitting shoulder.
static func _planed_stock(size: Vector3) -> ArrayMesh:
	var half := size*.5
	var bevel := minf(.036,half[half.min_axis_index()]*.16)
	var core := half-Vector3.ONE*bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for axis in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		for side: float in [-1.,1.]:
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
				var point := Vector3.ZERO
				point[axis] = side*half[axis]
				point[u] = corner.x*core[u]
				point[v] = side*corner.y*core[v]
				points.append(point)
			_quad(surface,points)
			for edge: float in [-1.,1.]:
				var start := Vector3.ZERO
				start[axis] = side*core[axis]
				start[u] = edge*core[u]
				start[v] = -core[v]
				var end := start
				end[v] = core[v]
				var n := Vector3.ZERO
				n[axis] = side*bevel
				var m := Vector3.ZERO
				m[u] = edge*bevel
				_quad(surface,[start+n,start+m,end+m,end+n])
	for x: float in [-1.,1.]:
		for y: float in [-1.,1.]:
			for z: float in [-1.,1.]:
				var p := core*Vector3(x,y,z)
				for n in [Vector3(x,0,0),Vector3(0,y,0),Vector3(0,0,z)]:
					surface.add_vertex(p+n*bevel)
	surface.generate_normals()
	return surface.commit()

static func box(host: Node3D, lo: Vector3, hi: Vector3, mat: Material, label := "Stock") -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.name = label
	var dimensions := hi-lo
	if mat is StandardMaterial3D and mat.albedo_texture != null:
		p.mesh = _planed_stock(dimensions)
		mat = wood(mat.albedo_color,dimensions.max_axis_index())
	else:
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		p.mesh = mesh
	p.position = (lo+hi)*.5
	p.material_override = mat
	host.add_child(p)
	return p
static func cylinder(host: Node3D, radius: float, height: float, pos: Vector3, mat: Material, label := "Round") -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	p.mesh = mesh
	p.position = pos
	p.material_override = wood(mat.albedo_color,1) if mat is StandardMaterial3D and mat.albedo_texture != null else mat
	host.add_child(p)
	return p
static func ring(host: Node3D, inner: float, outer: float, low: float, high: float, pos: Vector3, mat: Material, start := 0.0, span := TAU, label := "Bearing") -> MeshInstance3D:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil(48.0*span/TAU))
	for i in count:
		var a := start+span*float(i)/count
		var b := start+span*float(i+1)/count
		var ia := Vector3(cos(a)*inner,low,sin(a)*inner)
		var ib := Vector3(cos(b)*inner,low,sin(b)*inner)
		var oa := Vector3(cos(a)*outer,low,sin(a)*outer)
		var ob := Vector3(cos(b)*outer,low,sin(b)*outer)
		var up := Vector3(0,high-low,0)
		for quad in [[ia,ib,ib+up,ia+up],[oa,oa+up,ob+up,ob],[ia,oa,ob,ib],[ia+up,ib+up,ob+up,oa+up]]:
			_quad(s,quad)
		if span < TAU-.001:
			if i == 0: _quad(s,[ia,ia+up,oa+up,oa])
			if i == count-1: _quad(s,[ib,ob,ob+up,ib+up])
	s.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = s.commit()
	node.position = pos
	node.material_override = mat
	host.add_child(node)
	return node
static func _quad(s: SurfaceTool, q: Array) -> void:
	for j in [0,1,2,0,2,3]: s.add_vertex(q[j])
static func solid(host: Node3D, stocks: Array, holes: Array, mat: Material, label := "MortisedStock") -> MeshInstance3D:
	var axes := [[],[],[]]
	for bounds in stocks+holes:
		for axis in 3:
			for point in bounds:
				if not axes[axis].has(point[axis]): axes[axis].append(point[axis])
	for a in axes: a.sort()
	var filled := {}
	for x in axes[0].size()-1:
		for y in axes[1].size()-1:
			for z in axes[2].size()-1:
				var p := Vector3((axes[0][x]+axes[0][x+1])*.5,(axes[1][y]+axes[1][y+1])*.5,(axes[2][z]+axes[2][z+1])*.5)
				var inside := false
				for b in stocks:
					if AABB(b[0],b[1]-b[0]).has_point(p): inside = true
				for b in holes:
					if AABB(b[0],b[1]-b[0]).has_point(p): inside = false
				if inside: filled[Vector3i(x,y,z)] = true
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs := [Vector3i(-1,0,0),Vector3i(1,0,0),Vector3i(0,-1,0),Vector3i(0,1,0),Vector3i(0,0,-1),Vector3i(0,0,1)]
	for key in filled:
		var a := Vector3(axes[0][key.x],axes[1][key.y],axes[2][key.z])
		var b := Vector3(axes[0][key.x+1],axes[1][key.y+1],axes[2][key.z+1])
		var faces := [[Vector3(a.x,a.y,a.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z)], [Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z)], [Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z)], [Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z)], [Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z)], [Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)]]
		for i in 6:
			if not filled.has(key+dirs[i]): _quad(s,faces[i])
	s.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = s.commit()
	node.material_override = mat
	host.add_child(node)
	return node
static func zong(host: Node3D, id: String, mat: Material) -> void:
	var p := MeshInstance3D.new()
	p.name = "ShipZong_"+id
	p.mesh = load("res://models/ship/rigging/assets/ship_mastframe_"+id+".obj")
	p.material_override = wood(mat.albedo_color,p.mesh.get_aabb().size.max_axis_index())
	host.add_child(p)
static func piece(id: String, kind: String) -> Node3D:
	return _pieces.instantiate(id + ":" + kind, _build_piece.bind(id, kind))

static func _build_piece(id: String, kind: String) -> Node3D:
	var p := Node3D.new()
	p.name = id
	p.set_meta("ship_member",id)
	p.set_meta("candidate_kind",kind)
	var light := wood(Color("dcc29b"))
	var dark := wood(Color("b89569"))
	if id in ["zrail","leg"]:
		if kind == "zong_corner":
			zong(p,id,light)
			if id == "zrail":
				_furled_sail(p)
		else:
			if id == "zrail": box(p,Vector3(0,0,1),Vector3(1,1,4.4),light)
			else: box(p,Vector3(0,-2.225,0),Vector3(1,0,1),light)
			if kind == "clamp_head":
				box(p,Vector3(.1,0,.1),Vector3(.3,.75,1.1),dark,"WrongForkA")
				box(p,Vector3(.7,0,.1),Vector3(.9,.75,1.1),dark,"WrongForkB")
			else:
				box(p,Vector3(.1,0,.1),Vector3(.8,.35,1.1),dark,"WrongLShort")
				box(p,Vector3(.55,.35,.1),Vector3(.8,.8,1.1),dark,"WrongLStep")
	elif id == "mast":
		var shaft := cylinder(p,.32,3.7,Vector3(0,3.68,0),dark,"MastShaft")
		shaft.mesh.top_radius = .235
		lashing(p,Vector3(0,2.12,0),.317)
		lashing(p,Vector3(0,4.87,0),.256)
		if kind == "square_foot": box(p,Vector3(-.28,1.10,-.28),Vector3(.28,1.86,.28),light,"SquareFoot")
		elif kind == "round_axle": cylinder(p,.28,.75,Vector3(0,1.48,0),light,"WrongRoundFoot")
		else:
			box(p,Vector3(-.28,1.10,-.28),Vector3(.05,1.86,.28),light,"WrongLFoot")
			box(p,Vector3(.05,1.43,-.28),Vector3(.28,1.86,.28),light,"WrongFootStep")
	elif id == "apron":
		box(p,Vector3(-2.6,-.18,-.17),Vector3(2.6,.35,.17),light,"SparApron")
		if kind != "clamp_head":
			box(p,Vector3(-.25,-.7,-.25),Vector3(.25,-.15,.25),dark,"WrongApronPeg")
			if kind == "zong_corner": box(p,Vector3(.4,-.5,-.25),Vector3(.56,-.15,.25),dark,"WrongApronPeg2")
	elif id == "top":
		var cuts := [[Vector3(-.27,.35,-.42),Vector3(.27,.58,-.17)],[Vector3(-.27,.35,.17),Vector3(.27,.58,.42)]] if kind == "clamp_head" else [[Vector3(-.2,.35,-.3),Vector3(.2,.58,.3)]]
		if kind == "l_through":
			cuts.append([Vector3(.19,.35,-.30),Vector3(.52,.47,.30)])
		cuts.append([Vector3(-.30,1.08,-.30),Vector3(.30,1.91,.30)])
		solid(p,[[Vector3(-1.85,.40,-.85),Vector3(1.85,1.83,.85)]],cuts,light,"MastBedTwinSockets")
	elif id == "lbrace":
		var stocks := [[Vector3(.668,-.5,-.47),Vector3(3.3,.5,.47)]]
		if kind == "l_through":
			stocks.append([Vector3(-.14,-.29,-.24),Vector3(.69,.29,.24)])
			stocks.append([Vector3(-.80,-.29,-.24),Vector3(-.12,-.08,.24)])
		elif kind == "through_tenon": stocks.append([Vector3(-.8,-.29,-.24),Vector3(.69,.29,.24)])
		else: stocks.append([Vector3(.0,-.29,-.24),Vector3(.69,.29,.24)])
		# The shaft opening continues through the support timber under the bearing.
		solid(p,stocks,[[Vector3(2.06,-.6,-.24),Vector3(2.54,.6,.24)]],light,"FixedSteppedRudderBrace")
		ring(p,.20,.38,.50,.82,Vector3(2.3,0,0),dark,0,TAU,"IndependentRoundBearing")
	elif id == "rudder":
		if kind == "round_axle": cylinder(p,.17,3.65,Vector3(2.3,.075,0),light,"RoundShaft")
		elif kind == "square_foot": box(p,Vector3(2.13,-1.75,-.17),Vector3(2.47,1.9,.17),light,"WrongSquareShaft")
		else:
			box(p,Vector3(2.13,-1.75,-.17),Vector3(2.35,1.9,.17),light,"WrongLShank")
			box(p,Vector3(2.35,.65,-.17),Vector3(2.54,1.9,.17),light,"WrongShankStep")
		cylinder(p,.31,.12,Vector3(2.3,.88,0),dark,"TopThrustShoulder")
		box(p,Vector3(2.15,1.65,-.1),Vector3(3.6,1.82,.1),dark,"Tiller")
	elif id == "blade":
		ring(p,.19,.32,-.9,-.6,Vector3(2.3,0,0),dark,PI,PI,"BladeSplitCollarBack")
		box(p,Vector3(2.23,-1.7,-1.3),Vector3(2.37,-.60,-.24),light,"RudderBlade")
		for x in [1.94,2.55]: box(p,Vector3(x,-.91,-.15),Vector3(x+.11,-.59,0),dark,"BackClampEar")
		var cap := Node3D.new()
		cap.name = "SideCap"
		p.add_child(cap)
		ring(cap,.19,.32,-.9,-.6,Vector3(2.3,0,0),dark,0,PI,"BladeSplitCollarFront")
		for x in [1.94,2.55]: box(cap,Vector3(x,-.91,0),Vector3(x+.11,-.59,.15),dark,"FrontClampEar")
		for x in [1.97,2.57]:
			var pin := cylinder(cap,.035,.58,Vector3(x,-.75,0),wood(Color("815d40")),"RemovablePin")
			pin.rotation.x = PI/2
	return p

static func lashing(host: Node3D,center: Vector3,radius: float) -> void:
	var cord := wood(Color("ae8b61"))
	for i in 4:
		var wrap := TorusMesh.new()
		wrap.inner_radius = radius-.012
		wrap.outer_radius = radius+.026
		wrap.rings = 28
		wrap.ring_segments = 6
		var loop := MeshInstance3D.new()
		loop.mesh = wrap
		loop.material_override = cord
		loop.position = center + Vector3.UP*.033*i
		loop.rotation.z = .034
		host.add_child(loop)

static func _furled_sail(host: Node3D) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("e5cda0")
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous: Array[Vector3] = []
	for i in 33:
		var t := i/32.0
		var z := lerpf(1.26,4.35,t)
		var sag := pow(absf(sin(PI*3*t)),.75)
		var ring_points: Array[Vector3] = []
		for j in 24:
			var angle := TAU*j/24
			var folds := 1.0+.11*cos(6*angle+2*t)
			ring_points.append(Vector3(.52+(.22+.10*sag)*folds*cos(angle),-.15-.135*sag+(.17+.08*sag)*folds*sin(angle),z))
		if not previous.is_empty():
			for j in 24:
				var k := (j+1)%24
				_quad(surface,[previous[j],previous[k],ring_points[k],ring_points[j]])
		if i==0 or i==32:
			var center := Vector3(.52,-.15,z)
			for j in 24:
				for point in [center,ring_points[j],ring_points[(j+1)%24]]:surface.add_vertex(point)
		previous = ring_points
	surface.generate_normals()
	var roll := MeshInstance3D.new()
	roll.name = "FurledSail"
	roll.mesh = surface.commit()
	roll.material_override = cloth
	host.add_child(roll)
	for t in [0.02,1.0/3,2.0/3,.98]:
		var z := lerpf(1.26,4.35,t)
		for dz in [-.036,.036]:
			var strap := ring(host,.50,.523,-.016,.016,Vector3(.5,.35,z+dz),wood(Color("996f47")),0,TAU,"SailTie")
			strap.rotation.x = PI/2
			strap.scale.z = 1.44
