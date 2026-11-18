extends SceneTree
## Independent edge-incidence check: exposed loft surfaces must be closed.
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Supports=preload("res://models/ship/hull/support_geometry.gd")
const Contact=preload("res://levels/level02/trial_contact.gd")
var checked:=0
var failures: Array[String]=[]
func closed(mesh: Mesh,label: String) -> void:
 var edges: Dictionary={};var faces:=mesh.get_faces()
 for i in range(0,faces.size(),3):
  if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<1e-16:continue
  for k in 3:
   var a:=faces[i+k].snapped(Vector3.ONE*.00001);var b:=faces[i+(k+1)%3].snapped(Vector3.ONE*.00001)
   if a==b:continue
   var key: Array=[a,b] if str(a)<str(b) else [b,a]
   edges[key]=edges.get(key,0)+1
 for key in edges:
  if edges[key]!=2:failures.append(label+": nonmanifold edge "+str(key));break
 checked+=1
func _initialize():
 var material:=G.material(Color.WHITE)
 for row in 3:
  for offset in [-.045,0.0,.045]:
   for span in [Vector2(-4,-1.4),Vector2(-1.4,4)]:
    var host:=Node3D.new();G.plank(host,span.x,span.y,row,material,offset,0,true)
    for part in Contact.meshes(host,Transform3D.IDENTITY):closed(part.mesh,"row "+str(row)+" offset "+str(offset))
    host.free()
 for station in [-3.8,-1.8,-.7,.7,1.5,3.5]:
  var host:=Node3D.new();Supports.rib(host,station,material)
  for part in Contact.meshes(host,Transform3D.IDENTITY):closed(part.mesh,"rib "+str(station))
  host.free()
 var report:={"closed_meshes_checked":checked,"failed":failures.size(),"failures":failures}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/rounded-hull")
 FileAccess.open("res://tests/evidence/rounded-hull/manifold.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CURVED MANIFOLD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
