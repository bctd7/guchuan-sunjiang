extends RefCounted
## Actual pocket frames. Pure geometry/orientation data, no verdict or camera.
const Boat=preload("res://models/ship/hull/boat_joints.gd")
const Openings=preload("res://levels/level02/opening_rules.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
static func feature(id: String,opening: String,layout: String,detail:=false) -> Transform3D:
	var shift: float=Openings.offset(id,opening)
	var axis:=Vector3(0,0,1)
	var entry:=Vector3.UP
	var center:=Vector3(0,-.06,shift)
	if id.begins_with("plank"):
		axis=Vector3.RIGHT;entry=Vector3(0,0,1)
		var row: int=0 if detail else Rules.row_for(id)
		var seam: float=Rules.seam(layout)
		var x: float=0 if detail else ((-4.0+seam)*.5 if id.ends_with("a") else (seam+4.0)*.5)
		# Wrong-type plank detail has an existing -.39 child offset.
		center=Vector3(x,shift,row*.78+.05-(.39 if detail else 0.0))
	elif id.begins_with("three"):
		var index:=1 if id=="three_middle" else 2
		axis=Vector3(cos(Boat.ANGLES[index]),0,sin(Boat.ANGLES[index]))
		center=axis*shift+Vector3.UP*(-.08 if index==1 else -.04)
		if index==1:
			# The first member offered for a three-way joint is the side slider.
			# Align its entry axis, not its length, with an incompatible receiver.
			axis=Vector3.FORWARD;entry=Vector3.RIGHT;center=Vector3.ZERO
	# Entry points into the pocket; its visible mouth faces the opposite direction.
	return Transform3D(Basis(axis,entry,axis.cross(entry)),center)
static func trial_pose(target: String,geometry: String,nominal: Transform3D,layout: String) -> Transform3D:
	var canonical: String=Openings.target(target)
	var receiver_frame:=nominal*feature(target,canonical,layout)
	var stock_frame:=feature(geometry,canonical,layout,true)
	# Calibrate against one canonical opening. A/B/C's real offset remains intact.
	return receiver_frame*stock_frame.affine_inverse()
