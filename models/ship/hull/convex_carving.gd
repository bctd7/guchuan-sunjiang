extends RefCounted
## Convex face clipping used only while constructing one carved timber.
## Every emitted chunk is convex; gameplay collision reads its actual faces.
const EPS:=.00001
static func vertices(faces: Array) -> Array[Vector3]:
 var result: Array[Vector3]=[]
 for face in faces:
  for p in face:
   if not result.any(func(q):return p.distance_squared_to(q)<EPS*EPS):result.append(p)
 return result
static func clip(faces: Array,plane: Plane) -> Array:
 var distances: Array[float]=[]
 for point in vertices(faces):distances.append(plane.distance_to(point))
 if distances.is_empty() or distances.min()>=-EPS:return []
 if distances.max()<=EPS:return faces
 var result: Array=[];var cap: Array[Vector3]=[]
 for face in faces:
  var polygon:=PackedVector3Array()
  for i in face.size():
   var a: Vector3=face[i];var b: Vector3=face[(i+1)%face.size()]
   var da:=plane.distance_to(a);var db:=plane.distance_to(b)
   if da<=EPS:polygon.append(a)
   if (da< -EPS and db>EPS) or (da>EPS and db< -EPS):
    var point:=a.lerp(b,da/(da-db));polygon.append(point)
    if not cap.any(func(q):return point.distance_squared_to(q)<EPS*EPS):cap.append(point)
   elif absf(da)<=EPS and not cap.any(func(q):return a.distance_squared_to(q)<EPS*EPS):cap.append(a)
  if polygon.size()>=3:result.append(polygon)
 if cap.size()>=3:
  var center:=Vector3.ZERO
  for p in cap:center+=p
  center/=cap.size()
  var u:=plane.normal.cross(Vector3.UP).normalized()
  if u.length_squared()<.5:u=plane.normal.cross(Vector3.RIGHT).normalized()
  var v:=plane.normal.cross(u)
  cap.sort_custom(func(a,b):return atan2((a-center).dot(v),(a-center).dot(u))<atan2((b-center).dot(v),(b-center).dot(u)))
  result.append(PackedVector3Array(cap))
 var points:=vertices(result)
 if points.size()<4:return []
 var bounds:=AABB(points[0],Vector3.ZERO)
 for p in points:bounds=bounds.expand(p)
 if minf(bounds.size.x,minf(bounds.size.y,bounds.size.z))<EPS:return []
 var center:=Vector3.ZERO
 for p in points:center+=p
 center/=points.size()
 var volume:=0.0
 for face in result:
  for i in range(1,face.size()-1):volume+=absf((face[0]-center).dot((face[i]-center).cross(face[i+1]-center)))/6.0
 if volume<.000000001:return []
 return result
static func subtract(faces: Array,planes: Array[Plane]) -> Array:
 var outside: Array=[];var inside:=faces
 for plane in planes:
  if inside.is_empty():break
  var remainder:=clip(inside,Plane(-plane.normal,-plane.d))
  if not remainder.is_empty():outside.append(remainder)
  inside=clip(inside,plane)
 return outside
static func from_mesh(mesh: Mesh,pose: Transform3D) -> Array:
 var points:=mesh.get_faces();var faces: Array=[]
 for i in range(0,points.size(),3):faces.append(PackedVector3Array([pose*points[i],pose*points[i+1],pose*points[i+2]]))
 return faces
static func downward_cut(points: Array[Vector3],normals: Array[Vector3],gap:=.001) -> Array[Plane]:
 var planes: Array[Plane]=[]
 for normal in normals:
  normal=normal.normalized()
  for sign_value in [-1,1]:
   var n: Vector3=normal*sign_value
   if n.y<-.00001:continue
   if planes.any(func(p):return p.normal.dot(n)>.99999):continue
   var d: float=-INF
   for point in points:d=maxf(d,n.dot(point))
   planes.append(Plane(n,d+gap))
 var flat:=PackedVector2Array()
 for p in points:flat.append(Vector2(p.x,p.z))
 var hull:=Geometry2D.convex_hull(flat)
 if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.remove_at(hull.size()-1)
 for i in hull.size():
  var a:=hull[i];var b:=hull[(i+1)%hull.size()]
  var n:=Vector3(b.y-a.y,0,a.x-b.x).normalized()
  var d: float=-INF
  for point in points:d=maxf(d,n.dot(point))
  if not planes.any(func(p):return p.normal.dot(n)>.99999):planes.append(Plane(n,d+gap))
 return planes
static func emit(host: Node3D,faces: Array,material: Material) -> void:
 var points:=vertices(faces);var center:=Vector3.ZERO
 for p in points:center+=p
 center/=maxi(1,points.size())
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_smooth_group(-1)
 for face in faces:
  for i in range(1,face.size()-1):
   var a: Vector3=face[0];var b: Vector3=face[i];var c: Vector3=face[i+1]
   var normal: Vector3=(c-a).cross(b-a)
   if normal.length_squared()<.0000000001:continue
   if normal.dot((a+b+c)/3.0-center)<0:
    var swap:=b;b=c;c=swap
   tool.add_vertex(a);tool.add_vertex(b);tool.add_vertex(c)
 tool.generate_normals()
 var node:=MeshInstance3D.new();node.mesh=tool.commit();node.material_override=material;host.add_child(node)
