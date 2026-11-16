extends RefCounted
## Receiving spans come from the outgoing tongue meshes themselves, not the
## selected answer, labels or progress flags. No State or chapter dependency.
static func collect(root: Node3D,pose: Transform3D,parts: Array) -> void:
 for child in root.get_children():
  if not child is Node3D:continue
  var frame: Transform3D=pose*child.transform
  if child is MeshInstance3D and child.get_meta("receiving_edge",false) and child.mesh!=null:
   parts.append({"mesh":child.mesh,"pose":frame})
  collect(child,frame,parts)

static func covers(parts: Array,frame: Transform3D,left: float,right: float,entry_z: float) -> bool:
 var spans: Array[Vector2]=[]
 for part in parts:
  var local: Transform3D=frame.affine_inverse()*part.pose
  var faces: PackedVector3Array=part.mesh.get_faces()
  if faces.is_empty():continue
  var bounds:=AABB(local*faces[0],Vector3.ZERO)
  for vertex in faces:bounds=bounds.expand(local*vertex)
  # Loose earlier planks can still offer their actual edge. Their slight
  # offset is dealt with by contact geometry, not silently corrected here.
  if absf(bounds.get_center().z-entry_z)>.30 or absf(bounds.get_center().y)>.20:continue
  if bounds.size.y>.10 or bounds.size.z>.14:continue
  spans.append(Vector2(bounds.position.x,bounds.end.x))
 spans.sort_custom(func(a: Vector2,b: Vector2):return a.x<b.x)
 var cursor:=left+.006
 for span in spans:
  if span.y<=cursor:continue
  # Permit the deliberately cut .012 plank end seam, not an unsupported bay.
  if span.x>cursor+.025:return false
  cursor=maxf(cursor,span.y)
  if cursor>=right-.006-.0001:return true
 return false
