extends Node3D
const G=preload("res://levels/level02/ship_geometry.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
const PANEL_POS=Vector3(0,.26,.45)
const PANEL_ANGLE=-.95
var camera: Camera3D
var pieces: Dictionary={}
var markers: Dictionary={}
var slots: Dictionary={}
var poses: Dictionary={}
var fixed: Dictionary={}
var animations: Dictionary={}
var seam_lines: Node3D
var water: Node3D
var caulk: Node3D
var inspected := false
var transparent := false
var current
var wood=G.material(Color("b89569"))
var lightwood=G.material(Color("dcc29b"))
var darkwood=G.material(Color("9e805d"))
var teal=G.material(Color("2d8086"))
var red=G.material(Color("bc4d36"))
var _built_layouts: Dictionary={}
func _ready() -> void:
	for m in [wood,lightwood,darkwood]: G.grain(m)
	var world=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("eee7d9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("fffaf0")
	env.ambient_light_energy=.32
	world.environment=env
	add_child(world)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-35,0)
	sun.light_energy=.65
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	camera.near=.05
	add_child(camera)
	G.box(self,Vector3(200,.1,200),Vector3(0,-.3,0),G.material(Color("aaa99b")))
	_build_fixed()
	for id in Rules.IDS:
		var node=Node3D.new()
		node.name=id
		add_child(node)
		pieces[id]=node
		_build_piece(id,"A")
		var slot=Node3D.new()
		add_child(slot)
		slots[id]=slot
		var badge=Label3D.new()
		badge.text="●"
		badge.font_size=76
		badge.pixel_size=.008
		badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		badge.no_depth_test=true
		badge.modulate=Color("2d8086")
		badge.outline_modulate=Color("fff8e8")
		badge.outline_size=9
		slot.add_child(badge)
		markers[id]=badge
	seam_lines=Node3D.new()
	add_child(seam_lines)
	water=Node3D.new()
	add_child(water)
	caulk=Node3D.new()
	add_child(caulk)
	show_overview()
func panel_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT,PANEL_ANGLE),PANEL_POS)
func _new_fixed(id: String,pos: Vector3) -> Node3D:
	var n=Node3D.new()
	n.name=id
	n.position=pos
	add_child(n)
	fixed[id]=n
	return n
func _build_fixed() -> void:
	var bottom=_new_fixed("bottom",Vector3.ZERO)
	for i in 5: G.box(bottom,Vector3(8,.17,.1085),Vector3(0,.08,-.217+i*.1085),lightwood if i%2==0 else wood)
	# Far side is prebuilt only to describe a truncated hull segment.
	var far=_new_fixed("far_shell",Vector3(0,.26,-.45))
	far.rotation.x=.95
	far.scale.z=-1
	for row in 3: G.plank(far,-4,4,row,lightwood if row%2==0 else wood)
	var ribs=_new_fixed("ribs",Vector3.ZERO)
	for x in [-3.8,-.7,.7,3.8]:
		for sign_value in [-1,1]:
			var points=[Vector3(x,.20,0),Vector3(x,.23,sign_value*.20),Vector3(x,.32,sign_value*.27),Vector3(x,.75,sign_value*.58),Vector3(x,1.4,sign_value*1.05),Vector3(x,2.1,sign_value*1.55)]
			for i in range(points.size()-1): _beam(ribs,points[i],points[i+1],.12,darkwood)
	var starter=_new_fixed("starter",PANEL_POS)
	starter.rotation.x=PANEL_ANGLE
	G.box(starter,Vector3(8,.18,.32),Vector3(0,0,-.26),wood)
	for s in [-1,1]: G.box(starter,Vector3(8,.055,.10),Vector3(0,s*.0625,-.05),wood)
	var low=_new_fixed("cross_lower",Vector3(-2.8,1.25,0))
	G.cross_member(low,false,wood)
	var three=_new_fixed("three_lower",Vector3(2.5,1.25,0))
	G.three_member(three,0,wood)
	var legs=_new_fixed("support_legs",Vector3.ZERO)
	for center_x in [-2.8,2.5]:
		for dx in [-.65,.65]: G.box(legs,Vector3(.14,.965,.14),Vector3(center_x+dx,.6475,0),wood)
	var bulkbase=_new_fixed("bulk_base",Vector3(0,.285,0))
	G.cross_member(bulkbase,false,wood,1.4)
	for x in [-3.5,3.5]:
		G.box(bottom,Vector3(.25,.28,2.3),Vector3(x,-.12,0),darkwood)
func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func _build_piece(id: String,layout: String) -> void:
	var n: Node3D=pieces[id]
	_clear(n)
	var row=Rules.row_for(id)
	if row>=0:
		var seam=Rules.seam(layout)
		G.plank(n,-4 if id.ends_with("a") else seam,seam if id.ends_with("a") else 4,row,lightwood if row%2==0 else wood)
		poses[id]=panel_transform()
	elif id=="cross_upper":
		G.cross_member(n,true,lightwood)
		poses[id]=Transform3D(Basis.IDENTITY,Vector3(-2.8,1.25,0))
	elif id.begins_with("three"):
		G.three_member(n,1 if id=="three_middle" else 2,lightwood if id=="three_middle" else darkwood)
		poses[id]=Transform3D(Basis.IDENTITY,Vector3(2.5,1.25,0))
	else:
		# Panel is integrated with a bottom rail that half-laps over its base.
		G.cross_member(n,true,lightwood,.5368)
		G.box(n,Vector3(.19,1.755,.5368),Vector3(0,.9975,0),lightwood)
		# Sloped side inserts extend toward both shell slopes.
		for sign_value in [-1,1]:
			var poly=PackedVector2Array([Vector2(-.12,sign_value*.2684),Vector2(1.875,sign_value*1.6945),Vector2(1.875,sign_value*.2684)])
			var form=Node3D.new()
			n.add_child(form)
			form.rotation.z=PI/2
			# x-z polygon extruded in Y, rotated into the Y-Z partition plane.
			G.prism(form,poly,-.095,.095,lightwood)
		poses[id]=Transform3D(Basis.IDENTITY,Vector3(0,.285,0))
	n.transform=poses[id]
	_built_layouts[id]=layout
func socket_position(id: String,layout: String) -> Vector3:
	var row=Rules.row_for(id)
	if row>=0:
		var seam=Rules.seam(layout)
		var x=(-4+seam)/2 if id.ends_with("a") else (seam+4)/2
		return panel_transform()*Vector3(x,.13,row*.78+.39)
	return poses[id].origin+Vector3(0,.3,0)
func sync_state(s) -> void:
	current=s
	for id in Rules.IDS:
		var row=Rules.row_for(id)
		var layout=str(s.placed.get(id,{}).get("layout",s.layout if id==s.selected and not s.layout.is_empty() else s.layouts.get(row,"A")))
		if layout.is_empty(): layout="A"
		if _built_layouts.get(id,"")!=layout: _build_piece(id,layout)
		if not animations.has(id): pieces[id].transform=poses[id]
		pieces[id].visible=s.placed.has(id)
		slots[id].position=socket_position(id,layout)
		markers[id].visible=not inspected and (not s.placed.has(id))
		markers[id].modulate=Color("df9f3f") if id==s.selected else Color("619297")
	for n in fixed.values(): n.visible=true
	if inspected: _inspect_visibility()
	_update_seams(s)
	_set_shell_transparency()
func _set_shell_transparency() -> void:
	for id in pieces:
		if Rules.row_for(id)>=0: _alpha(pieces[id],.26 if transparent else 1.0)
	_alpha(fixed.far_shell,.26 if transparent else 1.0)
func _alpha(n: Node,a: float) -> void:
	if n is MeshInstance3D:
		var m=n.material_override.duplicate() as StandardMaterial3D
		m.albedo_color.a=a
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if a<1 else BaseMaterial3D.TRANSPARENCY_DISABLED
		n.material_override=m
	for child in n.get_children(): _alpha(child,a)
func _update_seams(s) -> void:
	_clear(seam_lines)
	_clear(water)
	_clear(caulk)
	seam_lines.transform=panel_transform()
	caulk.transform=panel_transform()
	for row in 3:
		if not s.placed.has("plank_%da"%row): continue
		var seam=Rules.seam(str(s.layouts.get(row,"A")))
		var bad=s.checked and s.bad_row()>=0 and (row==s.bad_row() or row==s.bad_row()-1)
		G.box(seam_lines,Vector3(.055,.025,.75),Vector3(seam,-.104,row*.78+.39),red if bad else darkwood)
		if s.completed:
			G.box(caulk,Vector3(.035,.02,.76),Vector3(seam,-.104,row*.78+.39),teal)
			G.box(caulk,Vector3(8,.02,.018),Vector3(0,-.104,row*.78),teal)
		if bad:
			for i in 4:
				var drop=MeshInstance3D.new()
				var sphere=SphereMesh.new()
				sphere.radius=.055
				sphere.height=.17
				drop.mesh=sphere
				drop.material_override=teal
				drop.position=panel_transform()*Vector3(seam+.06,-.17,row*.78+.12+i*.17)
				water.add_child(drop)
	if s.completed:
		var seals=Node3D.new()
		caulk.add_child(seals)
		seals.transform=panel_transform().affine_inverse()
		G.box(seals,Vector3(.25,.025,.57),Vector3(0,.17,0),teal)
		for sign_value in [-1,1]:
			_beam(seals,Vector3(0,.17,sign_value*.2714),Vector3(0,2.16,sign_value*1.6975),.025,teal)
			G.box(seals,Vector3(.32,.12,.025),Vector3(0,.225,sign_value*.145),teal)
		var m=G.material(Color(.26,.58,.64,.25))
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		G.box(water,Vector3(3.6,.03,.73),Vector3(-1.9,.34,0),m)
func animate_place(id: String) -> void:
	inspected=false
	show_overview()
	var n: Node3D=pieces[id]
	n.visible=true
	var offset=Vector3(0,1.2,0)
	if Rules.row_for(id)>=0: offset=poses[id].basis*Vector3(0,0,.65)
	n.position=poses[id].origin+offset
	var tween=create_tween()
	animations[id]=tween
	tween.tween_property(n,"position",poses[id].origin,.65)
	tween.finished.connect(func(): animations.erase(id))
func cancel_animations() -> void:
	for tween in animations.values(): tween.kill()
	animations.clear()
func inspect_selected() -> void:
	inspected=true
	transparent=false
	_inspect_visibility()
	var id: String=current.selected
	var row=Rules.row_for(id)
	var target=socket_position(id,str(current.layout) if not current.layout.is_empty() else "A")
	if row>=0:
		target=panel_transform()*Vector3(0,0,row*.78+.1)
		_camera(target+Vector3(1.2,2.5,4),target,7.4)
		camera.v_offset=1.2
	else:
		_camera(target+(Vector3(0,6,3.5) if id.begins_with("three") else Vector3(2.4,2.7,3.5)),target,6.0)
		camera.v_offset=1.33 if id.begins_with("three") else 1.2
		if id.begins_with("three"): camera.size=8.0
func _inspect_visibility() -> void:
	if current==null: return
	var id: String=current.selected
	var row=Rules.row_for(id)
	for other in pieces:
		pieces[other].visible=other==id or (row>0 and Rules.row_for(other)==row-1 and current.placed.has(other)) or (id=="three_upper" and other=="three_middle" and current.placed.has(other))
		markers[other].visible=false
	for key in fixed:
		fixed[key].visible=(row==0 and key=="starter") or (id=="cross_upper" and key=="cross_lower") or (id.begins_with("three") and key=="three_lower") or (id=="bulkhead" and key=="bulk_base")
	pieces[id].position=poses[id].origin+(poses[id].basis*Vector3(0,0,.42) if row>=0 else Vector3(0,.75,0))
func show_overview() -> void:
	inspected=false
	_camera(Vector3(8,9,12),Vector3(0,.85,.1),11.5)
	camera.v_offset=.9
	if current!=null: sync_state(current)
func show_plan() -> void:
	inspected=false
	_camera(Vector3(0,13,4),Vector3(0,.7,.5),7.8)
	if current!=null: sync_state(current)
func _camera(from: Vector3,target: Vector3,size_value: float) -> void:
	camera.position=from
	camera.look_at(target)
	camera.size=size_value
	camera.h_offset=-1.35
	camera.v_offset=.08
func socket_screen_position(id: String) -> Vector2:
	return camera.unproject_position(slots[id].global_position)
func pick_socket(point: Vector2) -> String:
	if inspected: return ""
	var closest=""
	var distance=36.0
	for id in markers:
		if not markers[id].visible: continue
		var d=socket_screen_position(id).distance_to(point)
		if d<distance:
			distance=d
			closest=id
	return closest


func _beam(host: Node3D,a: Vector3,b: Vector3,width: float,mat: Material) -> MeshInstance3D:
	var n=G.box(host,Vector3(width,width,a.distance_to(b)),(a+b)/2,mat)
	n.look_at_from_position((a+b)/2,b,Vector3.UP)
	return n
