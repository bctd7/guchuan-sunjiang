extends RefCounted
## Ship-specific static solids; no legacy workshop models or runtime CSG.
const ANGLES := [0.0,PI/3.0,-PI/3.0]
const THICK := 0.24
const WIDTH := 0.28
const LENGTH := 2.0
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
static func layer_polygons(index: int,layer: int) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array]=[rectangle(ANGLES[index])]
	for other in 3:
		if index==other: continue
		var remove := (index<other and layer>index) or (index>other and layer<=other)
		if not remove: continue
		var next: Array[PackedVector2Array]=[]
		for p in polys:
			for q in Geometry2D.clip_polygons(p,rectangle(ANGLES[other])):
				if q.size()>=3: next.append(q)
		polys=next
	return polys
static func prism(parent: Node3D,poly: PackedVector2Array,y0: float,y1: float,mat: Material) -> MeshInstance3D:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var triangles=Geometry2D.triangulate_polygon(poly)
	for i in range(0,triangles.size(),3):
		for j in [0,1,2]:
			var p=poly[triangles[i+j]]
			st.add_vertex(Vector3(p.x,y0,p.y))
		for j in [2,1,0]:
			var p=poly[triangles[i+j]]
			st.add_vertex(Vector3(p.x,y1,p.y))
	for i in poly.size():
		var a=poly[i]
		var b=poly[(i+1)%poly.size()]
		for v in [Vector3(a.x,y0,a.y),Vector3(a.x,y1,a.y),Vector3(b.x,y1,b.y),Vector3(a.x,y0,a.y),Vector3(b.x,y1,b.y),Vector3(b.x,y0,b.y)]: st.add_vertex(v)
	st.generate_normals()
	var n=MeshInstance3D.new()
	n.mesh=st.commit()
	n.material_override=mat
	parent.add_child(n)
	return n
static func three_member(parent: Node3D,index: int,mat: Material) -> void:
	for layer in 3:
		# Layers share arm boundaries; mating faces do not interpenetrate.
		for poly in layer_polygons(index,layer):
			prism(parent,poly,-.12+layer*.08,-.12+(layer+1)*.08,mat)
static func cross_member(parent: Node3D,upper: bool,mat: Material,length:=1.86) -> void:
	if upper:
		box(parent,Vector3(.28,.12,length),Vector3(0,.06,0),mat)
		for s in [-1,1]: box(parent,Vector3(.28,.12,(length-.30)/2),Vector3(0,-.06,s*(length+.30)/4),mat)
	else:
		box(parent,Vector3(length,.12,.28),Vector3(0,-.06,0),mat)
		for s in [-1,1]: box(parent,Vector3((length-.30)/2,.12,.28),Vector3(s*(length+.30)/4,.06,0),mat)
static func plank(parent: Node3D,a: float,b: float,row: int,mat: Material) -> void:
	var length=b-a-.012
	var x=(a+b)/2
	var z=row*.78+.39
	box(parent,Vector3(length,.18,.68),Vector3(x,0,z-.05),mat)
	for side in [-1,1]: box(parent,Vector3(length,.055,.10),Vector3(x,side*.0625,z+.34),mat)
	box(parent,Vector3(length,.06,.09),Vector3(x,0,z-.435),mat)
static func plank_solid(p: Vector3,row: int,a: float,b: float) -> bool:
	if p.x<=a+.006 or p.x>=b-.006: return false
	var z=p.z-row*.78
	return (z>0 and z<.68 and absf(p.y)<.09) or (z>=.68 and z<.78 and absf(p.y)>.035 and absf(p.y)<.09) or (z>-.09 and z<=0 and absf(p.y)<.03)
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
