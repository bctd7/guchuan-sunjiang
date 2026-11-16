extends SceneTree
const Probe=preload("res://tests/stock_clearance.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var a:=MeshInstance3D.new();var b:=MeshInstance3D.new()
	for node in [a,b]:node.mesh=BoxMesh.new();root.add_child(node)
	var passed:=0
	assert(Probe.intersects(Probe.shape(a),Probe.shape(b)));passed+=1
	b.position=Vector3(1.01,0,0);assert(not Probe.intersects(Probe.shape(a),Probe.shape(b)));passed+=1
	b.position=Vector3(1,0,0);assert(not Probe.intersects(Probe.shape(a),Probe.shape(b)));passed+=1
	b.position=Vector3(.7,0,.7);b.rotation.y=PI/4;assert(Probe.intersects(Probe.shape(a),Probe.shape(b)));passed+=1
	b.position.y=1.01;assert(not Probe.intersects(Probe.shape(a),Probe.shape(b)));passed+=1
	var probe:=Probe.new()
	var rotated:=Transform3D(Basis(Vector3.UP,-5*PI/6),Vector3(2,1,3))
	var neighbor:=rotated;neighbor.origin+=rotated.basis.x*1.0012
	assert(not probe.triangles_intersect({"mesh":a.mesh,"pose":rotated},{"mesh":b.mesh,"pose":neighbor}));passed+=1
	neighbor.origin=rotated.origin+rotated.basis.x*.95
	assert(probe.triangles_intersect({"mesh":a.mesh,"pose":rotated},{"mesh":b.mesh,"pose":neighbor}));passed+=1
	var prism:=Node3D.new()
	var shape=load("res://models/ship/hull/ship_geometry.gd").prism(prism,PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(.4,1),Vector2(.4,-.4),Vector2(-.4,-.4),Vector2(-.4,1),Vector2(-1,1)]),-.2,.2,null)
	var small:=BoxMesh.new();small.size=Vector3(.2,.2,.2)
	assert(not probe.triangles_intersect({"mesh":small,"pose":Transform3D.IDENTITY},{"mesh":shape.mesh,"pose":Transform3D.IDENTITY}));passed+=1
	assert(probe.triangles_intersect({"mesh":small,"pose":Transform3D(Basis.IDENTITY,Vector3(.7,0,0))},{"mesh":shape.mesh,"pose":Transform3D.IDENTITY}));passed+=1
	prism.free();probe.free()
	a.free();b.free();print("STOCK_CLEARANCE ",passed," passed / 0 failed");quit()
