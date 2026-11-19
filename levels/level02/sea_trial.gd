extends Node3D
## Bounded visual pressure-test story, not hydrodynamics or a strength calculation.
signal phase_changed(message: String)
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Presentation=preload("res://levels/level02/trial_presentation.gd")
var _presentation=Presentation.new()
var motion: Tween
var phase := "idle"
var elapsed := 0.0
var crest: Node3D
var drops: Node3D
var cracks: Node3D
var sea: MeshInstance3D
var _drop_starts: Array[Vector3]=[]
var impact_count := 0

func _ready() -> void:
	hide()
	set_process(false)

func presentation_snapshot() -> Presentation:
	return _presentation.snapshot()
func setup() -> void:
	crest=Node3D.new()
	add_child(crest)
	drops=Node3D.new()
	add_child(drops)
	cracks=Node3D.new()
	add_child(cracks)
	var water=G.material(Color(.22,.48,.49,.30))
	water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	sea=G.box(self,Vector3(10,.035,4.6),Vector3(0,.12,3.0),water)
	var foam=G.material(Color("d7e6d5"))
	var blue=G.material(Color("5f9391"))
	var skin:=SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 44:
		for j in 10:
			var points: Array[Vector3]=[]
			for step in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var x: float=-4.8+(i+step.x)*9.6/44.0
				var z: float=-.6+(j+step.y)*1.2/10.0
				points.append(Vector3(x,.42*sin((z+.6)/1.2*PI),z+.04*sin(x*1.7)))
			for point in points:skin.add_vertex(point)
	skin.generate_normals()
	var ribbon:=MeshInstance3D.new()
	ribbon.mesh=skin.commit()
	ribbon.material_override=blue
	crest.add_child(ribbon)
	for i in 32:
		var x: float=-4.8+i*.31
		var bubble:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=.065
		sphere.height=.13
		bubble.mesh=sphere
		bubble.material_override=foam
		bubble.scale=Vector3(2.5,.55,1.0)
		bubble.position=Vector3(x,.43,.04*sin(x*1.7))
		crest.add_child(bubble)
	hide()
func play(presentation: Presentation) -> Tween:
	if crest == null:
		setup()
	cancel()
	_presentation=presentation.snapshot()
	impact_count=0
	elapsed=0.0
	phase="approach"
	show()
	set_process(true)
	phase_changed.emit("海浪测试 · 浪峰正在接近船板。")
	motion=create_tween()
	motion.tween_method(_approach,0.0,1.0,.8)
	motion.tween_callback(_impact)
	motion.tween_method(_pressure,0.0,1.0,1.15)
	motion.tween_method(_recede,0.0,1.0,.65)
	motion.tween_callback(func():
		_settle_loose_parts()
		var wet: bool=not _presentation.seam_rows.is_empty() or not _presentation.connection_points.is_empty()
		var loose: bool=not _presentation.structural_ids.is_empty()
		phase="leaking" if wet else ("loose" if loose else "passed")
		crest.hide()
		phase_changed.emit("试浪发现船板漏水、内部支撑松动。" if wet and loose else ("试浪发现船板接缝漏水。" if wet else ("试浪发现内部支撑松动，搭扣没有扣牢。" if loose else "试浪未见漏水或支撑松动，正在检查整关连接。"))))
	return motion
func _approach(value: float) -> void:
	crest.position=Vector3(0,.23+sin(value*PI)*.28,lerpf(4.4,1.2,value))
func _impact() -> void:
	phase="impact"
	impact_count+=1
	phase_changed.emit("海浪冲击 · 木料松动，观察榫型与接合处。" if not _presentation.type_error_ids.is_empty() else "海浪冲击 · 观察连接处。")
	var teal=G.material(Color("4c9caa"))
	var red=G.material(Color("b6543f"))
	for pose in _presentation.seam_poses:
		var crack=G.box(cracks,Vector3(.055,.032,.75),Vector3.ZERO,red)
		crack.transform=pose
		for j in 5:
			var drop:=MeshInstance3D.new()
			var mesh:=SphereMesh.new()
			mesh.radius=.045
			mesh.height=.15
			drop.mesh=mesh
			drop.material_override=teal
			drop.position=pose*Vector3(.03,-.055,-.29+float(j)*.14)
			drops.add_child(drop)
			_drop_starts.append(drop.position)
	for point in _presentation.connection_points:
		G.box(cracks,Vector3(.13,.035,.13),point,red)
		for j in 5:
			var drop:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.045;mesh.height=.15;drop.mesh=mesh;drop.material_override=teal
			drop.position=point+Vector3((j-2)*.06,-.08,0);drops.add_child(drop);_drop_starts.append(drop.position)
func _pressure(value: float) -> void:
	crest.position=Vector3(0,.52+sin(value*PI*4)*.10,1.2+sin(value*PI*4)*.12)
	cracks.scale.x=1.0+sin(value*PI)*.03
func _recede(value: float) -> void:
	crest.position=Vector3(0,lerpf(.52,.15,value),lerpf(1.2,4.6,value))
func _process(delta: float) -> void:
	if not visible: return
	elapsed+=delta
	if phase=="impact":
		# Loosen outward, never push farther into an obstructed joint. A shared
		# phase preserves clearance between supported pieces; no sideways yaw.
		var travel:=absf(sin(elapsed*12.0))*.025
		for part in _presentation.loose_parts:
			if is_instance_valid(part.node):
				part.node.transform=part.rest
				part.node.position+=part.withdraw*travel
	for i in drops.get_child_count():
		var cycle: float=fposmod(elapsed*1.4+float(i)*.18,1.0)
		var drop: Node3D=drops.get_child(i)
		drop.position=_drop_starts[i]+Vector3(.03*sin(elapsed*4+i),-.62*cycle,.16*cycle)
		drop.scale=Vector3.ONE*(1.0-.35*cycle)
func _settle_loose_parts() -> void:
	for part in _presentation.loose_parts:
		if is_instance_valid(part.node):part.node.transform=part.rest
func cancel() -> void:
	_settle_loose_parts()
	_presentation=Presentation.new()
	if is_instance_valid(motion): motion.kill()
	motion=null
	phase="idle"
	_drop_starts.clear()
	for container in [drops,cracks]:
		if is_instance_valid(container):
			for node in container.get_children():
				container.remove_child(node)
				node.queue_free()
	if is_instance_valid(crest):
		crest.show()
		crest.position=Vector3(0,.2,4.4)
	hide()
	set_process(false)
