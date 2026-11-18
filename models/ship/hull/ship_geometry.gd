extends RefCounted
## Ship-specific static solids; no legacy workshop models or runtime CSG.
const Shell=preload("res://models/ship/hull/shell_surface.gd")
const ANGLES := [0.0,PI/3.0,-PI/3.0]
const THICK := 0.24
const WIDTH := 0.28
const LENGTH := 2.0
const PLANK_THICKNESS := .18
const GROOVE_WIDTH := .07
const GROOVE_DEPTH := .10
const TONGUE_WIDTH := .06
const TONGUE_DEPTH := .09
static func dimensions(node: Node,key: String="mating_dimensions") -> Dictionary:
	if node.has_meta(key):return node.get_meta(key).duplicate(true)
	for child in node.get_children():
		var found:=dimensions(child,key)
		if not found.is_empty():return found
	return {}

static func material(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.87
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m
static func box(parent: Node3D,size: Vector3,pos: Vector3,mat: Material) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=BoxMesh.new()
	mesh.size=size
	n.mesh=mesh
	n.position=pos
	n.material_override=mat
	parent.add_child(n)
	return n
static func rectangle(angle: float) -> PackedVector2Array:
	var p=PackedVector2Array([Vector2(-LENGTH/2,-WIDTH/2),Vector2(LENGTH/2,-WIDTH/2),Vector2(LENGTH/2,WIDTH/2),Vector2(-LENGTH/2,WIDTH/2)])
	for i in p.size(): p[i]=p[i].rotated(angle)
	return p
static func layer_polygons(index: int,layer: int,opening_offset:=0.0) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array]=[rectangle(ANGLES[index])]
	for other in 3:
		if index==other: continue
		var remove := (index<other and layer>index) or (index>other and layer<=other)
		if not remove: continue
		var next: Array[PackedVector2Array]=[]
		var cut:=rectangle(ANGLES[other])
		var shift:=Vector2(cos(ANGLES[index]),sin(ANGLES[index]))*opening_offset
		for vertex in cut.size():cut[vertex]+=shift
		for p in polys:
			for q in Geometry2D.clip_polygons(p,cut):
				if q.size()>=3: next.append(q)
		polys=next
	return polys
static func prism(parent: Node3D,poly: PackedVector2Array,y0: float,y1: float,mat: Material) -> MeshInstance3D:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var triangles=Geometry2D.triangulate_polygon(poly)
	for i in range(0,triangles.size(),3):
		for j in [2,1,0]:
			var p=poly[triangles[i+j]]
			st.add_vertex(Vector3(p.x,y0,p.y))
		for j in [0,1,2]:
			var p=poly[triangles[i+j]]
			st.add_vertex(Vector3(p.x,y1,p.y))
	for i in poly.size():
		var a=poly[i]
		var b=poly[(i+1)%poly.size()]
		for v in [Vector3(b.x,y1,b.y),Vector3(a.x,y1,a.y),Vector3(a.x,y0,a.y),Vector3(b.x,y0,b.y),Vector3(b.x,y1,b.y),Vector3(a.x,y0,a.y)]: st.add_vertex(v)
	st.generate_normals()
	var n=MeshInstance3D.new()
	n.mesh=st.commit()
	n.material_override=mat
	parent.add_child(n)
	return n
static func three_member(parent: Node3D,index: int,mat: Material,opening_offset:=0.0) -> void:
	for layer in 3:
		# Layers share arm boundaries; mating faces do not interpenetrate.
		for poly in layer_polygons(index,layer,opening_offset):
			prism(parent,poly,-.12+layer*.08,-.12+(layer+1)*.08,mat)
static func cross_member(parent: Node3D,upper: bool,mat: Material,length:=1.86,opening_offset:=0.0) -> void:
	# Wood size and opening width stay constant; the split shoulders move along stock.
	var full:=Vector3(.28,.12,length) if upper else Vector3(length,.12,.28)
	box(parent,full,Vector3(0,.06 if upper else -.06,0),mat)
	for side in [-1,1]:
		var start: float=-length/2.0 if side<0 else opening_offset+.15
		var end: float=opening_offset-.15 if side<0 else length/2.0
		var center: float=(start+end)*.5
		var size:=Vector3(.28,.12,end-start) if upper else Vector3(end-start,.12,.28)
		box(parent,size,Vector3(0,-.06,center) if upper else Vector3(center,.06,0),mat)
# Rounded joint sections shared by the curved plank loft.
static func rounded_tip(poly: PackedVector2Array,radius: float,indices: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for i in poly.size():
		var corner:=poly[i]
		if not i in indices:
			result.append(corner)
			continue
		var u: Vector2=(poly[(i+poly.size()-1)%poly.size()]-corner).normalized()
		var v: Vector2=(poly[(i+1)%poly.size()]-corner).normalized()
		var safe_radius: float=minf(radius,.45*minf(corner.distance_to(poly[(i+poly.size()-1)%poly.size()]),corner.distance_to(poly[(i+1)%poly.size()])))
		var center:=corner+(u+v)*safe_radius
		for step in 9:
			var angle: float=step*PI/16.0
			result.append(center-safe_radius*(v*cos(angle)+u*sin(angle)))
	return result

static func edge_section(parent: Node3D,poly: PackedVector2Array,length: float,x: float,mat: Material) -> MeshInstance3D:
	var mesh:=prism(parent,poly,-length*.5,length*.5,mat)
	mesh.rotation.z=PI/2
	mesh.position.x=x
	return mesh

static func plank(parent: Node3D,a: float,b: float,row: int,mat: Material,incoming_offset:=0.0,outgoing_offset:=0.0,opening_at_entry:=false) -> MeshInstance3D:
	var start: float=row*.78
	# The chapter-two option moves the actual female groove; stock size never changes.
	var body_start: float=start+.10 if opening_at_entry else start
	Shell.loft(parent,PackedVector2Array([Vector2(-.09,body_start),Vector2(.09,body_start),Vector2(.09,body_start+.68),Vector2(-.09,body_start+.68)]),a+.006,b-.006,mat)
	var slot_offset: float=incoming_offset if opening_at_entry else outgoing_offset
	parent.set_meta("mating_dimensions",{"kind":"groove","width":GROOVE_WIDTH,"depth":GROOVE_DEPTH,"offset":slot_offset,"stock":PLANK_THICKNESS})
	parent.set_meta("receiving_dimensions",{"kind":"tongue","width":TONGUE_WIDTH,"depth":TONGUE_DEPTH,"offset":outgoing_offset if opening_at_entry else incoming_offset,"stock":PLANK_THICKNESS})
	for side in [-1,1]:
		var low: float=-PLANK_THICKNESS*.5 if side<0 else slot_offset+GROOVE_WIDTH*.5
		var high: float=slot_offset-GROOVE_WIDTH*.5 if side<0 else PLANK_THICKNESS*.5
		var z0: float=start if opening_at_entry else start+.68
		var lip:=PackedVector2Array([Vector2(low,z0),Vector2(high,z0),Vector2(high,z0+.10),Vector2(low,z0+.10)])
		# Ease only the groove mouth; preserve the seat and the designed clearance.
		var corner: int=(1 if side<0 else 0) if opening_at_entry else (2 if side<0 else 3)
		Shell.loft(parent,rounded_tip(lip,.012,[corner]),a+.006,b-.006,mat)
	var center: float=outgoing_offset if opening_at_entry else incoming_offset
	var z0: float=start+.78 if opening_at_entry else start-.09
	var tongue:=PackedVector2Array([Vector2(center-.03,z0),Vector2(center+.03,z0),Vector2(center+.03,z0+.09),Vector2(center-.03,z0+.09)])
	return Shell.loft(parent,rounded_tip(tongue,.018,[2,3] if opening_at_entry else [0,1]),a+.006,b-.006,mat)
static func plank_solid(p: Vector3,row: int,a: float,b: float) -> bool:
	p=Shell.inverse(p)
	if p.x<=a+.006 or p.x>=b-.006: return false
	var z=p.z-row*.78
	if z>0 and z<.68 and absf(p.y)<.09:return true
	var point:=Vector2(p.y,z)
	var tongue:=PackedVector2Array([Vector2(-.03,-.09),Vector2(.03,-.09),Vector2(.03,0),Vector2(-.03,0)])
	if Geometry2D.is_point_in_polygon(point,rounded_tip(tongue,.018,[0,1])):return true
	for side in [-1,1]:
		var low: float=-.09 if side<0 else .035
		var high: float=-.035 if side<0 else .09
		var lip:=PackedVector2Array([Vector2(low,.68),Vector2(high,.68),Vector2(high,.78),Vector2(low,.78)])
		if Geometry2D.is_point_in_polygon(point,rounded_tip(lip,.012,[2 if side<0 else 3])):return true
	return false
static func three_solid(p: Vector3,index: int) -> bool:
	if p.y<=-.12 or p.y>=.12: return false
	var layer=int(floor((p.y+.12)/.08))
	if layer<0 or layer>2: return false
	for poly in layer_polygons(index,layer):
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),poly): return true
	return false

static func grain(m: StandardMaterial3D) -> void:
	var noise=FastNoiseLite.new()
	noise.seed=2749
	noise.frequency=.035
	noise.fractal_octaves=3
	var ramp=Gradient.new()
	ramp.colors=PackedColorArray([Color(.88,.86,.82),Color(1,1,1)])
	var texture=NoiseTexture2D.new()
	texture.width=256
	texture.height=256
	texture.noise=noise
	texture.seamless=true
	texture.color_ramp=ramp
	m.albedo_texture=texture
	m.uv1_triplanar=true
	m.uv1_scale=Vector3(.3,5,5)
