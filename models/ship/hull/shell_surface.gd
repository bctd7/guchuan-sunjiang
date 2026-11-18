extends RefCounted
## Developed plank coordinates: X along grain, Y thickness, Z across strakes.
## The same loft constructs timber surfaces, joint walls and convex contact cells.
static func rise(z: float) -> float:
 return -.585*z if z<0.0 else -.25*z*(2.34-z)
static func sweep(x: float) -> float:
 return (.18 if x>0 else .12)*pow(absf(x)/4.0,4)
static func point(p: Vector3) -> Vector3:
 return Vector3(p.x,p.y+rise(p.z)+sweep(p.x),p.z)
static func inverse(p: Vector3) -> Vector3:
 return Vector3(p.x,p.y-rise(p.z)-sweep(p.x),p.z)
static func entry(row: int) -> Vector3:
 var z:=row*.78
 return Vector3(0,(rise(z+.001)-rise(z-.001))/.002,1).normalized()
static func normal(p: Vector3,n: Vector3) -> Vector3:
 var dx:=(point(p+Vector3.RIGHT*.001).y-point(p-Vector3.RIGHT*.001).y)/.002
 var dz:=(point(p+Vector3.BACK*.001).y-point(p-Vector3.BACK*.001).y)/.002
 return Vector3(n.x-dx*n.y,n.y,n.z-dz*n.y).normalized()
static func cut(poly: PackedVector2Array,z: float,above: bool) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for i in poly.size():
  var a:=poly[i];var b:=poly[(i+1)%poly.size()]
  var da: float=(a.y-z)*(1 if above else -1);var db: float=(b.y-z)*(1 if above else -1)
  if da>=0.0:result.append(a)
  if da*db<0:
   var hit:=a.lerp(b,da/(da-db));hit.y=z;result.append(hit)
 return result
static func loft(host: Node3D,poly: PackedVector2Array,left: float,right: float,mat: Material) -> MeshInstance3D:
 var low:=INF;var high:=-INF
 for p in poly:low=minf(low,p.y);high=maxf(high,p.y)
 var bands: Array=[]
 var count:=maxi(1,ceili((high-low)/.045))
 for i in count:
  var a:=lerpf(low,high,float(i)/count);var b:=lerpf(low,high,float(i+1)/count)
  var section:=cut(cut(poly,a,true),b,false)
  if section.size()>=3:bands.append(section)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cells: Array=[]
 var steps:=maxi(1,ceili((right-left)/.20))
 for ix in steps:
  var x0:=lerpf(left,right,float(ix)/steps);var x1:=lerpf(left,right,float(ix+1)/steps)
  for section in bands:
   var verts: Array[Vector3]=[];var norms: Array[Vector3]=[];var edges: Array[Vector3]=[]
   for x in [x0,x1]:
    for p in section:verts.append(point(Vector3(x,p.x,p.y)))
   var faces: Array=[]
   var indices:=Geometry2D.triangulate_polygon(section)
   for i in range(0,indices.size(),3):
    for end in 2:
     var tri: Array[Vector3]=[]
     for j in ([0,1,2] if end==0 else [2,1,0]):
      var p: Vector2=section[indices[i+j]];tri.append(Vector3(x0 if end==0 else x1,p.x,p.y))
     faces.append({"tri":tri,"visible":(ix==0 if end==0 else ix==steps-1)})
   for i in section.size():
    var a: Vector2=section[i];var b: Vector2=section[(i+1)%section.size()]
    var internal: bool=absf(a.y-b.y)<.00001 and a.y>low+.00001 and a.y<high-.00001
    var aa:=Vector3(x0,a.x,a.y);var ab:=Vector3(x1,a.x,a.y);var ba:=Vector3(x0,b.x,b.y);var bb:=Vector3(x1,b.x,b.y)
    faces.append({"tri":[aa,ab,bb],"visible":not internal});faces.append({"tri":[aa,bb,ba],"visible":not internal})
   for face in faces:
    var a: Vector3=face.tri[0];var b: Vector3=face.tri[1];var c: Vector3=face.tri[2]
    var n:=(c-a).cross(b-a).normalized()
    norms.append((point(c)-point(a)).cross(point(b)-point(a)).normalized())
    edges.append(point(b)-point(a));edges.append(point(c)-point(b));edges.append(point(a)-point(c))
    if face.visible:
     for p in face.tri:tool.set_normal(normal(p,n));tool.add_vertex(point(p))
   cells.append({"vertices":verts,"normals":norms,"edges":edges})
 var node:=MeshInstance3D.new();node.mesh=tool.commit();node.mesh.set_meta("joinery_contact_cells",cells);node.mesh.set_meta("loft_normals",true);node.material_override=mat;host.add_child(node)
 return node

static func bottom_point(p: Vector3) -> Vector3:
 var g:=sweep(p.x)
 return Vector3(p.x,p.y+cos(.95)*g,p.z*(1.0-sin(.95)*g/.27))
static func floor_board(host: Node3D,left_z: float,right_z: float,material: Material) -> void:
 for i in 40:
  var x0: float=-4+i*.2;var x1:=x0+.2
  var v: Array[Vector3]=[]
  for x in [x0,x1]:
   for y in [-.005,.165]:
    for z in [left_z,right_z]:v.append(bottom_point(Vector3(x,y,z)))
  var indices: Array=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var center:=Vector3.ZERO
  for p in v:center+=p/8
  for face in indices:
   for tri in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
    var a: Vector3=v[tri[0]];var b: Vector3=v[tri[1]];var c: Vector3=v[tri[2]]
    if (c-a).cross(b-a).dot((a+b+c)/3-center)<0:
     var swap:=b;b=c;c=swap
    st.set_normal((c-a).cross(b-a).normalized());st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
  var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material;host.add_child(mesh)
