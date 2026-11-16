extends RefCounted
## A matched top key crosses the starter rail and its paired middle member.
## Each pair is built before assembly and keeps its geometry throughout both strokes.
const Carve=preload("res://models/ship/hull/convex_carving.gd")
const ANGLE:=PI/6.0
const PARK_HEIGHT:=.85
# Receiver cells for this pair are supplied in the top's local frame. This
# builder knows neither level state nor whether the pair suits the next board.
static func top(host: Node3D,receivers: Array,material: Material,channel_offset:=0.0) -> void:
 host.set_meta("wood_axis",Vector3(cos(ANGLE),0,sin(ANGLE)))
 var box:=BoxMesh.new();box.size=Vector3(1.0,.40,.18)
 var frame:=Transform3D(Basis(Vector3.UP,-ANGLE),Vector3(channel_offset,.08,0))
 var chunks: Array=[Carve.clip(Carve.from_mesh(box,frame),Plane(Vector3.BACK,.13))]
 for cell in receivers:
  var planes:=Carve.downward_cut(cell.vertices,cell.normals)
  var next: Array=[]
  for chunk in chunks:next.append_array(Carve.subtract(chunk,planes))
  chunks=next
 for chunk in chunks:Carve.emit(host,chunk,material)
