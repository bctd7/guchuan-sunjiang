extends Node3D
## Harbor-scale model. Batch each finish into one mesh so fine rigging adds no nodes.
var _surfaces: Dictionary = {}
var _finishes: Dictionary = {}
const TIMBER := Color("965e39")
const STRAKE := Color("654333")
const LACQUER := Color("305651")
const IVORY := Color("ded2af")
const CORD := Color("69513a")
const STATIONS := 32

func _init() -> void:
	_build_hull()
	_build_deck()
	_sail(Vector3(-.28,.65,0),3.65,1.0)
	_sail(Vector3(1.53,.72,0),2.23,.59)
	# Stern steering gear extends below the transom and clear of the hull.
	_spar(Vector3(-2.82,-.56,0),Vector3(-2.63,1.32,0),.073,.060,STRAKE)
	_quad(Vector3(-2.8,.30,0),Vector3(-3.10,.20,0),Vector3(-3.14,-.59,0),Vector3(-2.85,-.64,0),TIMBER)
	_spar(Vector3(-2.64,1.30,0),Vector3(-2.03,1.20,.20),.043,.027,TIMBER)
	for finish in _surfaces:
		var surface: SurfaceTool = _surfaces[finish]
		surface.generate_normals()
		surface.index()
		var part := MeshInstance3D.new()
		part.name = "SailsAndPennants" if finish == "canvas" else "HullDeckAndRigging"
		part.mesh = surface.commit()
		part.material_override = _finishes[finish]
		add_child(part)
	_surfaces.clear()
	_finishes.clear()

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color,finish := "wood") -> void:
	if not _surfaces.has(finish):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(-1)
		_surfaces[finish] = surface
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = .92
		if finish == "wood":
			mat.albedo_texture = preload("res://models/ship/hull/wood_appearance.gd").grain_texture()
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(.38,4.1,4.1)
		_finishes[finish] = mat
	var tool: SurfaceTool = _surfaces[finish]
	for point in [a,b,c,a,c,d]:
		tool.set_color(tint)
		tool.add_vertex(point)

# Longitudinal stations define a broad transom, curved sheer and narrow raised stem.
func _width(t: float) -> float:
	return (.71+.33*sin(PI*t))*(1.0-pow(t,3.4))+.024

func _sheer(t: float) -> float:
	return .64+.27*pow(1.0-t,4.0)+.53*pow(t,5.0)

func _side(t: float,h: float,side: float) -> Vector3:
	var x := lerpf(-2.68,2.95,t) + .38*(h-1.0)*pow(t,5) - .12*(h-1.0)*pow(1-t,6)
	var y := lerpf(-.48+.23*pow(t,3),_sheer(t),h)
	return Vector3(x,y,side*_width(t)*(.25+.75*sin(h*PI*.51)))

func _build_hull() -> void:
	var colors := [Color("704939"),Color("89583a"),Color("ab7248"),Color("985f39"),Color("b87f52"),Color("92603f"),LACQUER]
	for i in STATIONS:
		var a := float(i)/STATIONS
		var b := float(i+1)/STATIONS
		for sign_value: float in [-1.,1.]:
			for row in colors.size():
				var low := float(row)/colors.size()
				var high := float(row+1)/colors.size()
				var p := _side(a,low,sign_value)
				var q := _side(b,low,sign_value)
				var r := _side(b,high,sign_value)
				var s := _side(a,high,sign_value)
				_quad(p,q,r,s,colors[row])
				# Narrow caulking line follows each plank's lower edge.
				var seam := Vector3(0,.010,sign_value*.004)
				_quad(p+Vector3(0,0,seam.z),q+Vector3(0,0,seam.z),q+seam,p+seam,STRAKE)
			# Butt seams alternate by strake, as on a planked hull.
			for row in range(1,6):
				if (i+row*3)%10 == 0:
					var lo := (row+.08)/7.0
					var hi := (row+.92)/7.0
					var bias := Vector3(0,0,.006*sign_value)
					_quad(_side(a,lo,sign_value)+bias,_side(a+.002,lo,sign_value)+bias,_side(a+.002,hi,sign_value)+bias,_side(a,hi,sign_value)+bias,STRAKE)
			var lip_a := _side(a,1,sign_value)
			var lip_b := _side(b,1,sign_value)
			var inboard := Vector3(0,0,-sign_value*.047)
			_quad(lip_a,lip_b,lip_b+inboard,lip_a+inboard,IVORY)
			for stripe in [.81,.94]:
				var p := _side(a,stripe,sign_value)+Vector3(0,0,sign_value*.008)
				var q := _side(b,stripe,sign_value)+Vector3(0,0,sign_value*.008)
				_quad(p,q,q+Vector3.UP*.018,p+Vector3.UP*.018,IVORY)
		_quad(_side(a,0,-1),_side(b,0,-1),_side(b,0,1),_side(a,0,1),STRAKE)
		# Deck planks follow the changing beam and leave the gunwales raised.
		for plank in 12:
			var u := lerpf(-.96,.96,float(plank)/12)
			var v := lerpf(-.96,.96,float(plank+1)/12)-.009
			_quad(_deck(a,u),_deck(b,u),_deck(b,v),_deck(a,v),Color("c29061").darkened(.035*(plank%3)))
	for t: float in [0.,1.]:
		for i in 7:
			var h := float(i)/7
			var k := float(i+1)/7
			_quad(_side(t,h,-1),_side(t,h,1),_side(t,k,1),_side(t,k,-1),colors[i])
	for s: float in [-1.,1.]:
		for station in [.06,.18,.31,.69,.79,.88]:
			var foot := _deck(station,s*.93)
			_spar(foot,foot+Vector3.UP*.25,.025,.025,STRAKE)
		for limits in [Vector2(.04,.32),Vector2(.68,.90)]:
			for i in 6:
				var a := lerpf(limits.x,limits.y,i/6.)
				var b := lerpf(limits.x,limits.y,(i+1)/6.)
				_spar(_deck(a,s*.93)+Vector3.UP*.24,_deck(b,s*.93)+Vector3.UP*.24,.023,.023,TIMBER)

func _deck(t: float,s: float) -> Vector3:
	return Vector3(lerpf(-2.68,2.95,t),_sheer(t)-.10,_width(t)*s)

func _box(center: Vector3,extent: Vector3,tint: Color) -> void:
	var corners := AABB(center-extent*.5,extent)
	for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
		_quad(corners.get_endpoint(face[0]),corners.get_endpoint(face[1]),corners.get_endpoint(face[2]),corners.get_endpoint(face[3]),tint)

func _build_deck() -> void:
	# Raised afterhouse, slatted shutters and a slightly arched roof.
	_box(Vector3(-1.72,.91,0),Vector3(1.28,.60,1.13),Color("925e3c"))
	for s: float in [-1.,1.]:
		for x in [-2.10,-1.72,-1.34]:
			_box(Vector3(x,.97,s*.572),Vector3(.28,.275,.016),Color("394943"))
			for offset in [-.095,0,.095]:
				_box(Vector3(x+offset,.97,s*.59),Vector3(.018,.28,.026),IVORY)
			_box(Vector3(x,.985,s*.59),Vector3(.28,.023,.026),IVORY)
		_box(Vector3(-1.72,.735,s*.584),Vector3(1.30,.065,.055),LACQUER)
	for i in 12:
		var a := lerpf(-.73,.73,i/12.)
		var b := lerpf(-.73,.73,(i+1)/12.)
		var ya := 1.31-.17*a*a
		var yb := 1.31-.17*b*b
		_quad(Vector3(-2.48,ya,a),Vector3(-.97,ya,a),Vector3(-.97,yb,b),Vector3(-2.48,yb,b),Color("425c56").lightened(.025*(i%3)))
	_box(Vector3(.66,.60,0),Vector3(.84,.12,.68),STRAKE)
	for i in 8:
		_box(Vector3(.31+i*.10,.681,0),Vector3(.072,.045,.61),Color("be8e61"))
	# A coiled line sits on the foredeck beside the hatch.
	var prev := Vector3.ZERO
	for i in 52:
		var theta := i*.40
		var radius := .065+i*.0023
		var p := Vector3(1.69+cos(theta)*radius,.70,sin(theta)*radius+.23)
		if i>0: _spar(prev,p,.014,.014,CORD)
		prev = p

func _spar(a: Vector3,b: Vector3,r1: float,r2: float,tint: Color) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z)<.8 else Vector3.UP).normalized()
	var up := axis.cross(side)
	for i in 8:
		var u := side*cos(TAU*i/8)+up*sin(TAU*i/8)
		var v := side*cos(TAU*(i+1)/8)+up*sin(TAU*(i+1)/8)
		_quad(a+u*r1,b+u*r2,b+v*r2,a+v*r1,tint)

# Fan-shaped sail, with diminishing upper panels, a curved belly and an inclined yard.
func _cloth(root: Vector3,scale_factor: float,h: float,u: float) -> Vector3:
	var left := lerpf(-1.48,-.80,h)
	var right := lerpf(.64,.43,h)
	return root+Vector3(lerpf(left,right,u),.58+h*2.65+u*(.02+.57*h),.11+.29*sin(PI*u)*sin(PI*h)+.10*sin(PI*u)+.035*sin(6*PI*h)*sin(PI*u))*scale_factor

func _sail(base: Vector3,height: float,k: float) -> void:
	var head := base+Vector3(-.12*k,height,0)
	_spar(base,head,.079*k,.036*k,STRAKE)
	var origin := base+Vector3(0,.12*k,0)
	for row in 6:
		var a := float(row)/6
		var b := float(row+1)/6
		for col in 10:
			var u := float(col)/10
			var v := float(col+1)/10
			var color := Color("ddbd82").lightened(.038*((row+col/4)%3))
			_quad(_cloth(origin,k,a,u),_cloth(origin,k,b,u),_cloth(origin,k,b,v),_cloth(origin,k,a,v),color,"canvas")
		for seam in [.245,.495,.745]:
			_quad(_cloth(origin,k,a,seam)+Vector3.BACK*.004,_cloth(origin,k,b,seam)+Vector3.BACK*.004,_cloth(origin,k,b,seam+.004)+Vector3.BACK*.004,_cloth(origin,k,a,seam+.004)+Vector3.BACK*.004,Color("c99965"),"canvas")
		for col in 5:
			var p := _cloth(origin,k,a,col/5.)
			var q := _cloth(origin,k,a,(col+1)/5.)
			_spar(p,q,.017*k,.017*k,Color("916c41"))
		_spar(_cloth(origin,k,a,0),_cloth(origin,k,b,0),.014*k,.014*k,CORD)
		_spar(_cloth(origin,k,a,1),_cloth(origin,k,b,1),.014*k,.014*k,CORD)
		if row%2==0:
			_spar(_cloth(origin,k,a,0),base+Vector3(-1.59*k,.22*k,.32*k),.008*k,.008*k,CORD)
	_spar(_cloth(origin,k,1,0),_cloth(origin,k,1,1),.035*k,.029*k,TIMBER)
	for sign_value: float in [-1.,1.]:
		_spar(head,base+Vector3(.67*k,0,sign_value*.69*k),.012*k,.012*k,CORD)
	_spar(head,base+Vector3(1.62*k,0,0),.012*k,.012*k,CORD)
	# Small swallowtail burgee catches the same breeze as the sails.
	var flag := head-Vector3.UP*.05
	_quad(flag,flag+Vector3(-.58,.06,.06)*k,flag+Vector3(-.37,-.08,.05)*k,flag+Vector3(0,-.16,0)*k,Color("a84432"),"canvas")
