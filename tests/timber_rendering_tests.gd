extends SceneTree
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Appearance=preload("res://levels/level02/wood_appearance.gd")
const Context=preload("res://levels/level02/inspection_context.gd")
const Lighting=preload("res://levels/level02/timber_lighting.gd")
var passed:=0
var failures: Array[String]=[]
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
 if ok:passed+=1
 else:failures.append(message);push_error(message)
func run():
 var source:=Node3D.new();root.add_child(source)
 source.set_meta("wood_axis",Vector3.RIGHT)
 var box=G.box(source,Vector3(4,.4,1),Vector3.ZERO,G.material(Color("b89569")))
 Appearance.apply(source)
 var material: StandardMaterial3D=box.material_override
 for mirrored in [false,true]:
  var pose:=Transform3D(Basis.from_euler(Vector3(.4,.2,.1)),Vector3(2,.3,-.4))
  if mirrored:pose.basis=pose.basis.scaled(Vector3(1,1,-1))
  var copy:=Node3D.new();root.add_child(copy)
  Context.append(copy,box,pose,1.2,2.8,.5)
  check(not material.uv1_triplanar,"stock uses continuous baked grain across separate notch solids")
  check(copy.get_child_count()==1,"clipped box exists")
  var mesh: MeshInstance3D=copy.get_child(0)
  check(mesh.transform.is_equal_approx(pose),"clipped stock retains source-local texture space even when mirrored")
  check(mesh.material_override.albedo_color==material.albedo_color and mesh.material_override.roughness==material.roughness and mesh.material_override.uv1_scale==material.uv1_scale,"receiver copy has same wood finish, not context tint")
  var arrays=mesh.mesh.surface_get_arrays(0);var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for index in points.size():
   var expected:=Appearance.Surface.uv(points[index],normals[index],Vector3.RIGHT)
   check(uvs[index].distance_to(expected)<.0001,"cut section preserves source stock grain phase on original and new faces")
  for index in range(0,points.size(),3):
   check(normals[index].dot(normals[index+1])>.999 and normals[index].dot(normals[index+2])>.999,"each flat triangle retains a hard plane normal")
   var midpoint: Vector3=pose*((points[index]+points[index+1]+points[index+2])/3.0)
   var n: Vector3=(pose.basis.inverse().transposed()*normals[index]).normalized()
   if absf(midpoint.x-1.2)<.0001:check(n.dot(Vector3.LEFT)>.99,"left cut cap points out of retained solid")
   elif absf(midpoint.x-2.8)<.0001:check(n.dot(Vector3.RIGHT)>.99,"right cut cap points out of retained solid")
   elif absf(midpoint.y-.5)<.0001:check(n.dot(Vector3.UP)>.99,"top cut cap points out of retained solid")
   else:
    var local_mid: Vector3=(points[index]+points[index+1]+points[index+2])/3.0
    check(normals[index].dot(local_mid)>0,"retained original box face stays outward, including mirrored stock")
  copy.free()
 var rigs: Array=[]
 for i in 3:
  var host:=Node3D.new();root.add_child(host);Lighting.install(host);rigs.append(host)
 for i in [1,2]:
  for name in ["TimberKey","TimberFill"]:
   var a=rigs[0].get_node(name);var b=rigs[i].get_node(name)
   check(a.transform.is_equal_approx(b.transform) and a.light_color==b.light_color and a.light_energy==b.light_energy and a.shadow_enabled==b.shadow_enabled and a.shadow_opacity==b.shadow_opacity,"world/card/enlarged light parameters agree")
 for host in rigs:host.free()
 source.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"scope":"Clipped original and mirrored stock: hard outward normals and cap winding, local triplanar coordinates, material equality, common fixed lighting rig."}
 FileAccess.open("res://tests/timber_rendering_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TIMBER_RENDERING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
