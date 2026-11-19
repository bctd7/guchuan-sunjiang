extends Node3D
const Lighting=preload("res://levels/level02/timber_lighting.gd")
const Context=preload("res://levels/level02/inspection_context.gd")
const ReceivingEdge=preload("res://levels/level02/receiving_edge.gd")
const StarterLock=preload("res://models/ship/hull/starter_lock.gd")
const Starter=preload("res://models/ship/hull/starter_joint.gd")
const Supports=preload("res://models/ship/hull/support_geometry.gd")
const Alignment=preload("res://levels/level02/assembly_alignment.gd")
const Appearance=preload("res://models/ship/hull/wood_appearance.gd")
const TrialContact=preload("res://models/ship/hull/trial_contact.gd")
const BoatJoints=preload("res://models/ship/hull/boat_joints.gd")
const InspectionCamera=preload("res://levels/level02/inspection_camera.gd")
const Openings=preload("res://levels/level02/opening_rules.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
const SeamGuides=preload("res://levels/level02/model_seam_guides.gd")
const SeaTrial=preload("res://levels/level02/sea_trial.gd")
const TrialPresentation=preload("res://levels/level02/trial_presentation.gd")
const Backdrop=preload("res://components/ui/workshop_backdrop.gd")
const Rules=preload("res://levels/level02/connection_rules.gd")
const ModelVariants = preload("res://models/ship/model_variants.gd")
const THREE_CENTER=Vector3(2.5,1.45,0)
const PANEL_POS=Vector3(0,.26,.45)
const PANEL_ANGLE=-.95
var trial: Node3D
var backdrop: CanvasLayer
var _environment: Environment
var camera: Camera3D
var framing=InspectionCamera.new()
var pieces: Dictionary={}
var poses: Dictionary={}
var contact_poses: Dictionary={}
var resting: Dictionary={}
var loose_directions: Dictionary={}
var contact_failures: Array[String]=[]
var fixed: Dictionary={}
var animations: Dictionary={}
var local_context: Node3D
var model_seams: Node3D
var seam_lines: Node3D
var water: Node3D
var caulk: Node3D
var inspected := false
var transparent := false
var _detail_frame: Dictionary={}
var current
var wood=G.material(Color("b89569"))
var lightwood=G.material(Color("dcc29b"))
var darkwood=G.material(Color("9e805d"))
var teal=G.material(Color("2d8086"))
var red=G.material(Color("bc4d36"))
var preview_id := ""
var preview_progress := 0.0
var _preview_key := ""
var _built_layouts: Dictionary={}
var _built_openings: Dictionary={}
var _built_geometry: Dictionary={}
var _pose_cache: Dictionary={}
var _model_variants = ModelVariants.new()
var _seam_presentation: Array = []
var lock_seats: Dictionary={}
var lock_templates: Dictionary={}
var _lock_openings: Dictionary = {}
var lock_variants: Dictionary={}
var lock_middles: Dictionary={}
var lock_waiting_tops: Dictionary={}
var lock_top_fits: Dictionary={}
var local_surface: Control
var local_viewport: SubViewport
var observation_orbit: Control
func _ready() -> void:
	_environment=Lighting.install(self)
	_environment.background_mode=Environment.BG_CANVAS
	_environment.background_canvas_max_layer=-10
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	camera.near=.05
	add_child(camera)
	framing.configure(camera)
	get_viewport().size_changed.connect(_fit_camera)
	tree_entered.connect(_fit_camera.call_deferred)
	backdrop=Backdrop.new()
	backdrop.image_texture = preload("res://assets/images/level02/seaside_shipyard.png")
	add_child(backdrop)
	visibility_changed.connect(_sync_background)
	var shadow=G.material(Color(0,0,0,0))
	shadow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shadow_to_opacity=true
	G.box(self,Vector3(200,.1,200),Vector3(0,-.3,0),shadow)
	local_context=Node3D.new();local_context.name="ShipSection";add_child(local_context);local_context.hide()
	_build_fixed()
	for id in Rules.IDS:
		var node=Node3D.new()
		node.name=id
		add_child(node)
		pieces[id]=node
		_build_piece(id,"A")
		_update_pose(id,"A","B")
		node.transform=poses[id]
	seam_lines=Node3D.new()
	add_child(seam_lines)
	water=Node3D.new()
	add_child(water)
	caulk=Node3D.new()
	add_child(caulk)
	model_seams=SeamGuides.new()
	add_child(model_seams)
	model_seams.hide()
	trial=SeaTrial.new()
	add_child(trial)
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
	for i in 5: G.Shell.floor_board(bottom,-.27+i*.108+.001,-.27+(i+1)*.108-.001,lightwood if i%2==0 else wood)
	# Far side is prebuilt only to describe a truncated hull segment.
	var far=_new_fixed("far_shell",Vector3(0,.26,-.45))
	far.rotation.x=.95
	far.scale.z=-1
	for row in 3: G.plank(far,-4,4,row,lightwood if row%2==0 else wood,0.0,0.0,true)
	var ribs=_new_fixed("ribs",Vector3.ZERO)
	for x in [-.7,.7]:Supports.rib(ribs,x,darkwood)
	var starter=_new_fixed("starter",PANEL_POS)
	starter.rotation.x=PANEL_ANGLE
	starter.set_meta("wood_axis",Vector3.RIGHT)
	Starter.rail(starter,wood)
	var low=_new_fixed("cross_lower",Vector3(-2.8,1.25,Openings.offset("cross_upper",Openings.target("cross_upper"))))
	BoatJoints.cross_member(low,false,wood)
	var three=_new_fixed("three_lower",THREE_CENTER)
	BoatJoints.three_member(three,0,wood)
	var cross_frame=_new_fixed("cross_frame",Vector3.ZERO)
	Supports.support_bay(cross_frame,-2.8,1.13,darkwood)
	var three_frame=_new_fixed("three_frame",Vector3.ZERO)
	Supports.support_bay(three_frame,2.5,1.33,darkwood)
	var bulkbase=_new_fixed("bulk_base",Vector3(0,.285,Openings.offset("bulkhead",Openings.target("bulkhead"))))
	BoatJoints.cross_member(bulkbase,false,wood,"C",1.4)
	for x in [-3.5,3.5]:
		G.box(bottom,Vector3(.25,.28,2.3),Vector3(x,-.12,0),darkwood)
		var lift:=cos(.95)*G.Shell.sweep(x)
		G.box(bottom,Vector3(.25,lift+.03,.25),Vector3(x,.005+lift*.5,0),darkwood)
	for node in fixed.values():Appearance.apply(node)
func _clear(node: Node) -> void:
	for key in ["mating_dimensions","receiving_dimensions"]:
		if node.has_meta(key):node.remove_meta(key)
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func _ensure_starter_lock(id: String,opening: String) -> void:
	if _lock_openings.get(id) == opening:
		return
	_pose_cache.erase(id)
	var middle:=Node3D.new()
	_populate_starter_specimen(middle,"three_middle",opening)
	var obstacles: Array=[]
	for fixture in fixed.values():
		for part in TrialContact.meshes(fixture,fixture.transform):obstacles.append(TrialContact.box(part))
	var nominal:=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(Starter.CENTERS[0 if id.ends_with("a") else 1],.303,.36))
	var seat: Transform3D=TrialContact.blocked(middle,nominal,Vector3.BACK,obstacles).pose
	lock_seats[id]=seat
	var key:=id+":"+opening
	if not lock_variants.has(key):
		var parts:=TrialContact.meshes(fixed.starter,seat.affine_inverse()*fixed.starter.transform)
		parts.append_array(TrialContact.meshes(middle,Transform3D.IDENTITY))
		var receivers: Array=[]
		for part in parts:
			var solid:=TrialContact.box(part)
			receivers.append_array(solid.get("cells",[solid]))
		var top:=Node3D.new();StarterLock.top(top,receivers,lightwood,BoatJoints.middle_upper_offset(opening));Appearance.apply(top)
		lock_variants[key] = ModelVariants.pack_model(top)
		top.free()
	middle.free();lock_templates[id]=lock_variants[key]
	_lock_openings[id] = opening
	if not lock_waiting_tops.has(id):
		var waiting:=Node3D.new();add_child(waiting);waiting.hide();lock_waiting_tops[id]=waiting
	var waiting: Node3D=lock_waiting_tops[id]
	_clear(waiting)
	_copy_starter_top(waiting, id)
	waiting.set_meta("opening",opening);waiting.transform=seat;waiting.position.y+=StarterLock.PARK_HEIGHT

func _copy_starter_top(target: Node3D, id: String) -> void:
	var top := ModelVariants.instantiate_model(lock_templates[id])
	for child in top.get_children():
		top.remove_child(child)
		target.add_child(child)
	top.free()
func _ensure_starter_middle(id: String,opening: String) -> void:
	_ensure_starter_lock(id,opening)
	if not lock_middles.has(id):
		var middle:=Node3D.new();add_child(middle);lock_middles[id]=middle
	var node: Node3D=lock_middles[id]
	if node.get_meta("opening","")!=opening:
		_clear(node)
		_populate_starter_specimen(node,"three_middle",opening)
		node.set_meta("opening",opening)
	node.transform=lock_seats[id]
func _sync_starter_members() -> void:
	for id in ["plank_0a","plank_0b"]:
		var top_stage: bool=current.starter_top(id) or current.starter_completed(id)
		if top_stage:
			var data: Dictionary=current.placed.get(id,current.starter_locks.get(id,{}))
			_ensure_starter_middle(id,str(data.opening))
		if lock_middles.has(id):lock_middles[id].visible=top_stage and (not inspected or pieces[id].visible)
		if lock_waiting_tops.has(id):
			lock_waiting_tops[id].visible=inspected and current.selected==id and current.joint=="three_way_lap" and not top_stage and not current.placed.has(id)
func _append_held_obstacle(id: String,obstacles: Array) -> void:
	if current.starter_completed(id) and lock_middles.has(id):
		for part in TrialContact.meshes(lock_middles[id],lock_seats[id]):obstacles.append(TrialContact.box(part))

func _build_piece(id: String,layout: String,opening: String="B") -> void:
	_pose_cache.erase(id)
	var node: Node3D=pieces[id]
	_clear(node)
	var geometry_id: String=opening_geometry_id(id)
	if geometry_id==id:_populate_piece(node,id,layout,opening)
	else:
		var alternative:=Node3D.new();node.add_child(alternative)
		if geometry_id=="starter_lock_top":
			_ensure_starter_middle(id,opening)
			_copy_starter_top(alternative, id)
		elif Rules.row_for(id)==0 and geometry_id in ["cross_upper", "three_middle"]:
			_populate_starter_specimen(alternative,geometry_id,opening)
			if geometry_id=="three_middle":_ensure_starter_lock(id,opening)
		else:_populate_piece(alternative,geometry_id,layout,opening)
		if geometry_id.begins_with("plank"):alternative.position.z-=.39
	_built_layouts[id]=layout
	_built_openings[id]=opening
	_built_geometry[id]=geometry_id
func _update_pose(id: String,layout: String,opening: String) -> void:
	var geometry_id: String=opening_geometry_id(id)
	var row: int=Rules.row_for(id)
	var pose:=panel_transform() if row>=0 else Transform3D(Basis.IDENTITY,Vector3(-2.8,1.25,0) if id=="cross_upper" else Vector3(0,.285,0))
	if id.begins_with("three"):
		pose.origin=THREE_CENTER
	var active: bool=current!=null and (current.placed.has(id) or current.selected==id)
	var receiver_bad:=false
	if active and row>0:receiver_bad=not current.connection_seated("plank_%d%s"%[row-1,"a" if id.ends_with("a") else "b"])
	if active and id=="three_upper":receiver_bad=not current.connection_seated("three_middle")
	# Later installed parts cannot alter an earlier member's receiving geometry.
	# Cache against the predecessors actually consulted by the contact solver.
	var preceding: Dictionary={}
	if current!=null:
		for previous in Rules.IDS:
			if previous==id:break
			if current.placed.has(previous):preceding[previous]=current.placed[previous].duplicate(true)
	var signature: Array=[active,geometry_id,layout,opening,receiver_bad,preceding]
	if _pose_cache.has(id) and _pose_cache[id].signature==signature:
		var cached: Dictionary=_pose_cache[id]
		poses[id]=cached.pose;contact_poses[id]=cached.contact
		resting[id]=cached.resting;loose_directions[id]=cached.direction
		if cached.failed:contact_failures.append(id)
		return
	resting[id]=active and (geometry_id!=id or not Openings.matches(id,opening) or receiver_bad)
	loose_directions[id]=pose.basis*G.Shell.entry(row) if row>=0 else (Vector3.RIGHT if id=="three_middle" else Vector3.UP)
	var obstacles: Array=[]
	if active:
		for fixture in fixed.values():
			for solid in TrialContact.meshes(fixture,fixture.transform):obstacles.append(TrialContact.box(solid))
		for previous in Rules.IDS:
			if previous==id:break
			if current.placed.has(previous):
				_append_held_obstacle(previous,obstacles)
				for solid in TrialContact.meshes(pieces[previous],poses[previous]):obstacles.append(TrialContact.box(solid))
		# A correctly chosen later member can meet already misplaced wood too.
		# Keep the all-correct assembly poses unchanged; only loose earlier stock
		# introduces this physical obstruction, with the same insertion path.
		if not resting[id]:
			for previous in Rules.IDS:
				if previous==id:break
				if current.placed.has(previous) and resting.get(previous,false):
					var loose: Array=[]
					for solid in TrialContact.meshes(pieces[previous],poses[previous]):loose.append(TrialContact.box(solid))
					if not TrialContact.clear(TrialContact.meshes(pieces[id],pose),loose):resting[id]=true;break
	if geometry_id=="starter_lock_top":
		pose=lock_seats[id];loose_directions[id]=Vector3.UP
		for part in TrialContact.meshes(lock_middles[id],pose):obstacles.append(TrialContact.box(part))
		var contact: Dictionary=TrialContact.blocked(pieces[id],pose,Vector3.UP,obstacles,StarterLock.PARK_HEIGHT)
		lock_top_fits[id]=contact.clear and contact.distance<.002
		pose=contact.pose
		if not contact.clear:contact_failures.append(id)
	elif resting[id]:
		var result: Dictionary
		if row==0 and geometry_id!=id:
			var x: float=Starter.CENTERS[0 if id.ends_with("a") else 1]
			pose=Transform3D(Basis.IDENTITY,Vector3(x,.20,.36))
			loose_directions[id]=Vector3.UP
			if geometry_id=="three_middle":
				pose=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(x,.303,.36))
				loose_directions[id]=Vector3.BACK
		elif geometry_id!=id:
			pose=Alignment.trial_pose(id,geometry_id,pose,layout)
			if row>=0:
				# A thicker wrong joint rests on the exterior side of the plank band.
				# Keep its pocket facing the receiver, but do not drive its shoulder
				# through the shell-attached ribs or shove it all the way to the sheer.
				var inside: float=-INF
				var inverse:=panel_transform().affine_inverse()
				for vertex in TrialContact.points(TrialContact.meshes(pieces[id],pose)):inside=maxf(inside,(inverse*vertex).y)
				pose.origin-=panel_transform().basis.y*maxf(0.0,inside-(.09-Supports.FIT_CLEARANCE))
		# Every stock faces the real receiver before approaching. Incompatible
		# pockets stop against wood on that same axis rather than a generic shelf.
		result=TrialContact.blocked(pieces[id],pose,loose_directions[id],obstacles)
		if receiver_bad and geometry_id==id and Openings.matches(id,opening) and result.distance==0:resting[id]=false
		pose=result.pose
		if not result.clear:contact_failures.append(id)
	if active and row>0 and not installation_receiver_present(id):
		# No supporting edge exists here. Stop short of an imaginary seated
		# position; committing the gesture reports failure rather than floating.
		pose.origin+=loose_directions[id]*.18
	contact_poses[id]=pose
	poses[id]=pose
	_pose_cache[id]={"signature":signature,"pose":pose,"contact":contact_poses[id],"resting":resting[id],"direction":loose_directions[id],"failed":contact_failures.has(id)}

func installation_receiver_present(id: String) -> bool:
	var row: int=Rules.row_for(id)
	if row<=0 or current==null:return true
	var edges: Array=[]
	for previous in Rules.IDS:
		if Rules.row_for(previous)!=row-1 or not current.placed.has(previous):continue
		ReceivingEdge.collect(pieces[previous],poses[previous],edges)
	var layout: String=str(_built_layouts.get(id,"A"))
	var seam: float=Rules.seam(layout)
	return ReceivingEdge.covers(edges,panel_transform(),-4.0 if id.ends_with("a") else seam,seam if id.ends_with("a") else 4.0,row*.78+.045)

func installation_closes_joint(id: String) -> bool:
	if opening_geometry_id(id)=="starter_lock_top":return lock_top_fits.get(id,false)
	# A top merely resting above the notch cannot lock the sliding middle.
	# Use the actual contact pose, including the retained middle's real cuts.
	if id=="three_upper" and opening_geometry_id(id)==id:
		return contact_poses[id].origin.distance_to(THREE_CENTER)<.002
	return true

func installation_path_clear(id: String) -> bool:
	if contact_failures.has(id):return false
	var obstacles: Array=[]
	for fixture in fixed.values():
		for solid in TrialContact.meshes(fixture,fixture.transform):obstacles.append(TrialContact.box(solid))
	for previous in Rules.IDS:
		if previous==id:break
		if current.placed.has(previous):
			_append_held_obstacle(previous,obstacles)
			for solid in TrialContact.meshes(pieces[previous],poses[previous]):obstacles.append(TrialContact.box(solid))
	if opening_geometry_id(id)=="starter_lock_top":
		for part in TrialContact.meshes(lock_middles[id],lock_seats[id]):obstacles.append(TrialContact.box(part))
	var offset:=preview_offset(id)
	if TrialContact.approach_clear(pieces[id],contact_poses[id],offset,obstacles):return true
	# A later obstruction can invalidate otherwise correct stock. Its rejection
	# animation must stop at the first reachable wall too, never at the far end.
	var stop:=TrialContact.blocked(pieces[id],contact_poses[id],offset.normalized(),obstacles)
	contact_poses[id]=stop.pose;poses[id]=stop.pose
	if _pose_cache.has(id):
		_pose_cache[id].pose=stop.pose;_pose_cache[id].contact=stop.pose;_pose_cache[id].failed=true
	return false
func _populate_piece(node: Node3D,id: String,layout: String,opening: String) -> void:
	var seam_layout := layout if Rules.row_for(id) >= 0 else ""
	_model_variants.populate(node, "%s:%s:%s" % [id, seam_layout, opening], _build_stock.bind(id, layout, opening))

func _populate_starter_specimen(node: Node3D,geometry_id: String,opening: String) -> void:
	_model_variants.populate(node, "starter:%s:%s" % [geometry_id, opening], _build_starter_specimen.bind(geometry_id, opening))

func _build_starter_specimen(node: Node3D,geometry_id: String,opening: String) -> void:
	if geometry_id=="cross_upper":
		Starter.cross_stock(node,lightwood,opening)
	else:
		BoatJoints.three_member(node,1,lightwood,opening,.20)
	Appearance.apply(node)

func _build_stock(node: Node3D,id: String,layout: String,opening: String) -> void:
	var row: int=Rules.row_for(id)
	var shift: float=Openings.offset(id,opening)
	if row>=0:
		node.set_meta("wood_axis",Vector3.RIGHT)
		var seam: float=Rules.seam(layout)
		var outgoing: MeshInstance3D=G.plank(node,(-4 if id.ends_with("a") else seam),(seam if id.ends_with("a") else 4),row,lightwood if row%2==0 else wood,shift,Openings.next_groove(row),true)
		outgoing.set_meta("receiving_edge",true)
		if row==0:
			Starter.plank_keys(node,(-4.0 if id.ends_with("a") else seam),(seam if id.ends_with("a") else 4.0),shift,lightwood,Starter.CENTERS)
	elif id=="cross_upper":BoatJoints.cross_member(node,true,lightwood,opening)
	elif id.begins_with("three"):BoatJoints.three_member(node,1 if id=="three_middle" else 2,lightwood if id=="three_middle" else darkwood,opening)
	else:
		BoatJoints.bulkhead_foot(node,lightwood,opening)
		var poly:=PackedVector2Array()
		for side in [-1,1]:
			for index in 49:
				var t: float=float(index if side<0 else 48-index)/48
				var y:=lerpf(.405,2.16,t)
				poly.append(Vector2(y-.285,side*(Supports.inner_side(y)-.008)))
		var form:=Node3D.new();node.add_child(form);form.rotation.z=PI/2
		G.prism(form,poly,-.095,.095,lightwood)
	Appearance.apply(node)
func candidate_opening(id: String,option: String) -> Node3D:
	var node:=Node3D.new()
	var geometry_id := opening_geometry_id(id)
	if geometry_id=="starter_lock_top":
		_ensure_starter_lock(id,str(_built_openings.get(id,option)))
		_copy_starter_top(node, id)
	elif Rules.row_for(id)==0 and geometry_id in ["cross_upper", "three_middle"]:
		_populate_starter_specimen(node,geometry_id,option)
	else:_populate_piece(node,geometry_id,str(current.layout) if not current.layout.is_empty() else "A",option)
	if Rules.row_for(id)>=0 and geometry_id==id:
		var row: int=Rules.row_for(id)
		var end: float=(Rules.seam(str(current.layout) if not current.layout.is_empty() else "A") if id.ends_with("a") else 4.0)-.006
		node.position=Vector3(.30,0,0)-G.Shell.point(Vector3(end,0,row*.78))
	return node

func receiving_dimensions(id: String) -> Dictionary:
	# For the last stroke the reference must follow the actual installed middle,
	# including its wrong width/offset, rather than a pristine correct template.
	var receivers:=_trial_receivers(id)
	if receivers.is_empty():return {}
	return G.dimensions(receivers.back().node,"receiving_dimensions")

func opening_geometry_id(id: String) -> String:
	if current!=null and (current.starter_top(id) or current.starter_completed(id)):return "starter_lock_top"
	if current!=null:
		var chosen: String=str(current.placed.get(id,{}).get("joint",current.joint if current.selected==id else Rules.expected(id)))
		if not chosen.is_empty() and chosen!=Rules.expected(id):
			return {"tongue_groove":"plank_0a","cross_lap":"cross_upper","three_way_lap":"three_middle"}.get(chosen,id)
	return id
func socket_position(id: String,layout: String) -> Vector3:
	var row=Rules.row_for(id)
	if row>=0:
		var seam=Rules.seam(layout)
		var x=(-4+seam)/2 if id.ends_with("a") else (seam+4)/2
		return panel_transform()*G.Shell.point(Vector3(x,.13,row*.78+.39))
	return poses[id].origin+Vector3(0,.3,0)
func sync_state(s) -> void:
	current=s
	var geometry_changed:=false
	contact_failures.clear()
	for id in Rules.IDS:
		var row=Rules.row_for(id)
		var layout=str(s.placed.get(id,{}).get("layout",s.layout if id==s.selected and not s.layout.is_empty() else s.layouts.get(row,"A")))
		if layout.is_empty(): layout="A"
		var opening: String=str(s.placed.get(id,{}).get("opening",s.opening if id==s.selected and not s.opening.is_empty() else Openings.target(id)))
		if _built_layouts.get(id,"")!=layout or _built_openings.get(id,"")!=opening or _built_geometry.get(id,"")!=opening_geometry_id(id):
			_build_piece(id,layout,opening)
			geometry_changed=true
		_update_pose(id,layout,opening)
		if not animations.has(id): pieces[id].transform=poses[id]
		pieces[id].visible=s.placed.has(id)
	for n in fixed.values(): n.visible=true
	# Clear a terminal preview before visibility can reapply its waiting offset.
	# Failed stock must remain at contact, never jump back behind the dialog.
	_sync_preview(s)
	if inspected:
		_inspect_visibility()
		_rebuild_context()
	_sync_starter_members()
	_update_seams(s)
	_set_connection_transparency()
	if inspected and geometry_changed:_fit_inspection()
func _set_connection_transparency() -> void:
	var row: int=Rules.row_for(current.selected)
	for id in pieces:
		var alpha:=1.0
		if inspected and id!=current.selected:
			if transparent and pieces[id].visible:alpha=.24
		_alpha(pieces[id],alpha)
	for node in fixed.values():_alpha(node,.24 if inspected and transparent and node.visible else 1.0)
	_alpha(local_context,.24 if inspected and transparent else 1.0)
func _alpha(n: Node,a: float) -> void:
	if n is MeshInstance3D:
		var original=n.material_override as StandardMaterial3D
		if original!=null and not is_equal_approx(original.albedo_color.a,a):
			var m=original.duplicate() as StandardMaterial3D
			m.albedo_color.a=a
			m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if a<1 else BaseMaterial3D.TRANSPARENCY_DISABLED
			n.material_override=m
	for child in n.get_children(): _alpha(child,a)
func _update_seams(s) -> void:
	var layouts: Array[String] = []
	for row in 3:
		layouts.append(str(s.layouts.get(row, "A")) if s.row_has_boards(row) else "")
	var bad_row: int = s.bad_row() if s.checked else -1
	var presentation := [layouts, bad_row, s.completed]
	if presentation == _seam_presentation:
		return
	_seam_presentation = presentation
	_clear(seam_lines)
	_clear(water)
	_clear(caulk)
	seam_lines.transform=panel_transform()
	caulk.transform=panel_transform()
	for row in 3:
		if layouts[row].is_empty(): continue
		var seam=Rules.seam(layouts[row])
		var bad=bad_row>=0 and (row==bad_row or row==bad_row-1)
		G.Shell.loft(seam_lines,PackedVector2Array([Vector2(-.116,row*.78+.015),Vector2(-.092,row*.78+.015),Vector2(-.092,row*.78+.765),Vector2(-.116,row*.78+.765)]),seam-.0275,seam+.0275,red if bad else darkwood)
		if s.completed:
			G.Shell.loft(caulk,PackedVector2Array([Vector2(-.114,row*.78+.01),Vector2(-.094,row*.78+.01),Vector2(-.094,row*.78+.77),Vector2(-.114,row*.78+.77)]),seam-.0175,seam+.0175,teal)
			G.Shell.loft(caulk,PackedVector2Array([Vector2(-.114,row*.78-.009),Vector2(-.094,row*.78-.009),Vector2(-.094,row*.78+.009),Vector2(-.114,row*.78+.009)]),-4,4,teal)
		if bad:
			for i in 4:
				var drop=MeshInstance3D.new()
				var sphere=SphereMesh.new()
				sphere.radius=.055
				sphere.height=.17
				drop.mesh=sphere
				drop.material_override=teal
				drop.position=panel_transform()*G.Shell.point(Vector3(seam+.06,-.17,row*.78+.12+i*.17))
				water.add_child(drop)
	if s.completed:
		var seals=Node3D.new()
		caulk.add_child(seals)
		seals.transform=panel_transform().affine_inverse()
		G.box(seals,Vector3(.25,.025,.57),Vector3(0,.17,0),teal)
		for sign_value in [-1,1]:
			for i in 32:
				var y0:=lerpf(.405,2.16,float(i)/32);var y1:=lerpf(.405,2.16,float(i+1)/32)
				_beam(seals,Vector3(0,y0,sign_value*Supports.inner_side(y0)),Vector3(0,y1,sign_value*Supports.inner_side(y1)),.025,teal)
			G.box(seals,Vector3(.32,.12,.025),Vector3(0,.225,Openings.offset("bulkhead",Openings.target("bulkhead"))+sign_value*.145),teal)
		var m=G.material(Color(.26,.58,.64,.25))
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		G.box(water,Vector3(3.6,.03,.73),Vector3(-1.9,.34,0),m)
func animate_place(id: String) -> void:
	var n: Node3D=pieces[id]
	var released: Transform3D=n.transform
	var remaining:=maxf(.12,.65*(1.0-preview_progress))
	preview_id=""
	preview_progress=0.0
	_preview_key=""
	n.visible=true
	n.transform=released
	var tween=create_tween()
	animations[id]=tween
	tween.tween_property(n,"transform",contact_poses[id],remaining).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): animations.erase(id))
func cancel_animations() -> void:
	if is_instance_valid(trial): trial.cancel()
	for tween in animations.values(): tween.kill()
	animations.clear()
func configure_workspace(surface: Control,viewport: SubViewport,orbit: Control) -> void:
	local_surface=surface;local_viewport=viewport;observation_orbit=orbit
	framing.configure_workspace(surface,viewport,orbit)
	local_viewport.size_changed.connect(_fit_inspection)
func inspect_selected(reset:=true) -> void:
	inspected=true
	transparent=false
	_detail_frame.clear()
	_sync_background()
	_inspect_visibility()
	_rebuild_context()
	var id: String=current.selected
	var row: int=Rules.row_for(id)
	var center:=panel_transform()*Vector3(0,0,row*.78+.35) if row>=0 else socket_position(id,"A")
	if row==0:
		var seam: float=Rules.seam(str(current.layout) if not current.layout.is_empty() else "A")
		center=panel_transform()*Vector3((-4.0+seam)*.5 if id.ends_with("a") else (seam+4.0)*.5,0,.55)
	if row<0 and id!="bulkhead":center=poses[id].origin+Vector3(0,.18,0)
	var direction:=Vector3(-3,6,-5) if row==0 else (Vector3(-2.5,5,-7) if row>0 else (Vector3(.7,6,7) if id.begins_with("three") else Vector3(3.2,6,7)))
	if id=="bulkhead":center+=Vector3(0,.7,0)
	framing.inspect(center,direction,reset)
	_fit_inspection()
func visible_stock_corners() -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for node in pieces.values():
		if node.visible:InspectionCamera.corners(node,points)
	for node in fixed.values():
		if node.visible:InspectionCamera.corners(node,points)
	if local_context.visible:InspectionCamera.corners(local_context,points)
	for node in lock_middles.values()+lock_waiting_tops.values():
		if node.visible:InspectionCamera.corners(node,points)
	return points
func _fit_inspection() -> void:
	if not inspected or not is_inside_tree() or not is_instance_valid(local_viewport):return
	framing.fit(inspection_focus_corners(),true)
func inspection_focus_corners() -> Array[Vector3]:
	# Frame the real mating members. The cropped hull remains as context, but
	# its distant keel/planking must not shrink a small mouth beyond readability.
	if not transparent or current==null or Rules.row_for(current.selected)>0:return visible_stock_corners()
	var points: Array[Vector3]=[]
	InspectionCamera.corners(pieces[current.selected],points)
	if Rules.row_for(current.selected)==0:
		# The first task has no stagger choice yet. Fit the active board and its
		# real receiver span, not the distant automatic half of the eight-unit row.
		var seam: float=Rules.seam(str(current.layout) if not current.layout.is_empty() else "A")
		var left: float=-4.0 if current.selected.ends_with("a") else seam
		var right: float=seam if current.selected.ends_with("a") else 4.0
		for x in [left,right]:
			for y in [-.09,.09]:
				for z in [-.32,.09]:points.append(panel_transform()*Vector3(x,y,z))
		return points
	for receiver in _trial_receivers(current.selected):InspectionCamera.corners(receiver.node,points)
	return points
func orbit_delta(delta: Vector2) -> void:framing.rotate(delta)
func zoom_observation(factor: float) -> void:
	if not inspected:return
	# Wrong families occupy their actual adapted receiver, not the expected
	# plank's nominal socket. Keep the held stock and its destination centred.
	var points: Array[Vector3]=[]
	InspectionCamera.corners(pieces[current.selected],points)
	if points.is_empty():return
	var bounds:=AABB(points[0],Vector3.ZERO)
	for point in points:bounds=bounds.expand(point)
	var focus:=bounds.get_center()
	if preview_id==current.selected:focus-=global_basis*preview_displacement(preview_id,preview_progress)*.5
	framing.zoom(factor,focus)
func inside_observation(point: Vector2) -> bool:return framing.contains(point,inspected)
func project_point(point: Vector3) -> Vector2:return framing.project(point,inspected)
func _camera_point(point: Vector2) -> Vector2:return framing.camera_point(point,inspected)
func _inspect_visibility() -> void:
	if current==null: return
	var id: String=current.selected
	var row=Rules.row_for(id)
	for other in pieces:
		pieces[other].visible=other==id or (row>0 and current.placed.has(other) and Rules.row_for(other)>=0 and Rules.row_for(other)<=row) or (id=="three_upper" and other=="three_middle" and current.placed.has(other))
	for key in fixed:
		fixed[key].visible=(id=="cross_upper" and key=="cross_lower") or (id.begins_with("three") and key=="three_lower") or (id=="bulkhead" and key=="bulk_base")
	_apply_preview()
	_sync_starter_members()
func _rebuild_context() -> void:
	_clear(local_context)
	var id: String=current.selected
	var row: int=Rules.row_for(id)
	local_context.visible=inspected
	if not local_context.visible:return
	if row>=0:
		var seam: float=Rules.seam(str(current.layout) if not current.layout.is_empty() else "A")
		var left: float=-4.0 if row>0 or id.ends_with("a") else seam
		var right: float=4.0 if row>0 or id.ends_with("b") else seam
		# Keep the whole moving board plus the adjacent framing bay. Cropping
		# only the distant length leaves the receiver and its support legible.
		for key in ["starter","bottom","ribs"]:
			Context.append(local_context,fixed[key],fixed[key].transform,left-.35,right+.35,INF,key=="ribs")
		_set_connection_transparency()
		return
	var center: float=-2.8 if id=="cross_upper" else (2.5 if id.begins_with("three") else 0.0)
	var half_span: float=1.25 if id!="bulkhead" else .85
	# Cut only the display copy below the mating stock. Tall hull/rib silhouettes
	# otherwise conceal the same central mouth the player is asked to inspect.
	var cut_height: float=INF if id=="bulkhead" else (1.13 if id=="cross_upper" else 1.33)
	Context.append(local_context,fixed.far_shell,fixed.far_shell.transform,center-half_span,center+half_span)
	Context.append(local_context,fixed.bottom,fixed.bottom.transform,center-half_span,center+half_span)
	Context.append(local_context,fixed.starter,fixed.starter.transform,center-half_span,center+half_span)
	for piece in Rules.IDS:
		if Rules.row_for(piece)>=0 and current.placed.has(piece):
			Context.append(local_context,pieces[piece],poses[piece],center-half_span,center+half_span,cut_height)
	if id!="bulkhead":
		var support: Node3D=fixed.cross_frame if id=="cross_upper" else fixed.three_frame
		Context.append(local_context,support,support.transform,center-half_span,center+half_span,INF,true)
	_set_connection_transparency()
func show_overview() -> void:
	inspected=false
	local_context.hide()
	_sync_background()
	_camera(Vector3(8,9,12),Vector3(0,.85,.1),11.5)
	camera.v_offset=.9
	if current!=null: sync_state(current)
func show_plan() -> void:
	inspected=false
	_camera(Vector3(0,13,4),Vector3(0,.7,.5),7.8)
	if current!=null: sync_state(current)
func _camera(from: Vector3,target: Vector3,size_value: float) -> void:
	framing.overview(from,target,size_value,get_viewport().get_visible_rect().size)
func _beam(host: Node3D,a: Vector3,b: Vector3,width: float,mat: Material) -> MeshInstance3D:
	var n=G.box(host,Vector3(width,width,a.distance_to(b)),(a+b)/2,mat)
	n.look_at_from_position((a+b)/2,b,Vector3.UP)
	return n

# Preview travel is visual only; State receives a placement after an accepted release.
func _sync_preview(s) -> void:
	var eligible: bool=not s.failed and not s.completed and not s.placed.has(s.selected) and s.selected==s.next_id()
	if not eligible:
		preview_id=""
		preview_progress=0.0
		_preview_key=""
		return
	var key: String=s.selected+":"+str(_built_layouts[s.selected])+":"+str(_built_openings[s.selected])+":"+str(_built_geometry[s.selected])
	if key!=_preview_key:
		preview_progress=0.0
		_preview_key=key
	preview_id=s.selected
	_apply_preview()

func preview_displacement(id: String,progress: float) -> Vector3:
	return preview_offset(id)*(1.0-progress)

func preview_offset(id: String) -> Vector3:
	if opening_geometry_id(id)=="starter_lock_top":return Vector3.UP*maxf(.01,StarterLock.PARK_HEIGHT-(contact_poses[id].origin.y-lock_seats[id].origin.y))
	if id=="three_middle" or (Rules.row_for(id)==0 and opening_geometry_id(id)=="three_middle"):return loose_directions.get(id,Vector3.RIGHT)*1.3
	if resting.get(id,false):return loose_directions[id]*(1.1 if Rules.row_for(id)>=0 else 1.05)
	return poses[id].basis*G.Shell.entry(Rules.row_for(id))*.75 if Rules.row_for(id)>=0 else loose_directions.get(id,Vector3.UP)*1.05

func _apply_preview() -> void:
	if preview_id.is_empty() or animations.has(preview_id): return
	pieces[preview_id].visible=inspected
	pieces[preview_id].transform=contact_poses[preview_id]
	pieces[preview_id].position+=preview_displacement(preview_id,preview_progress)

func set_preview_progress(value: float) -> void:
	preview_progress=clampf(value,0.0,1.0)
	_apply_preview()

func reset_preview() -> void:
	preview_progress=0.0
	_apply_preview()

func drag_path_screen() -> Vector2:
	if preview_id.is_empty(): return Vector2.ZERO
	var center: Vector3=socket_position(preview_id,str(_built_layouts[preview_id]))
	return project_point(center)-project_point(center+preview_offset(preview_id))

func drag_input_path_screen() -> Vector2:
	# Match chapter one's 80–220 logical-pixel gesture. Rendering scale and an
	# end-on camera must not turn a push into a twitch or an unreachable stroke.
	if preview_id.is_empty():return Vector2.ZERO
	var canvas: Transform2D=local_surface.get_global_transform_with_canvas()
	var path: Vector2=canvas.affine_inverse().basis_xform(drag_path_screen())
	var axis: Vector2=path.normalized() if path.length()>=18.0 else Vector2.UP
	return canvas.basis_xform(axis*clampf(path.length(),80.0,220.0))

func drag_grab_screen() -> Vector2:
	# A point on the center of actual exposed timber, useful for guide rendering.
	if preview_id.is_empty(): return Vector2.ZERO
	var n: Node3D=pieces[preview_id]
	var geometry_id: String=opening_geometry_id(preview_id)
	if geometry_id=="starter_lock_top":return _visible_grab_point(n,n.global_transform*Vector3(BoatJoints.middle_upper_offset(str(_built_openings[preview_id])),.24,0))
	if geometry_id!=preview_id:
		# A wrong type is still real draggable stock, not an invisible expected-shape hitbox.
		var alternate: Node3D=n.get_child(0)
		var sample:=Vector3(0,0,.32) if geometry_id.begins_with("plank") else Vector3(0,.06,.55)
		if geometry_id.begins_with("three"):
			var angle: float=BoatJoints.ANGLES[1 if geometry_id=="three_middle" else 2]
			sample=Vector3(cos(angle)*.65,.02,sin(angle)*.65)
		return _visible_grab_point(n,alternate.global_transform*sample)
	var row: int=Rules.row_for(preview_id)
	var local:=Vector3.ZERO
	if row>=0:
		var seam: float=Rules.seam(str(_built_layouts[preview_id]))
		local=G.Shell.point(Vector3((-4.0+seam)*.5 if preview_id.ends_with("a") else (seam+4.0)*.5,0,row*.78+.32))
	elif preview_id.begins_with("three"):
		var angle: float=BoatJoints.ANGLES[1 if preview_id=="three_middle" else 2]
		local=Vector3(cos(angle)*.65,.02,sin(angle)*.65)
	elif preview_id=="bulkhead": local=Vector3(0,1.0,0)
	else: local=Vector3(0,.06,.55)
	return _visible_grab_point(n,n.global_transform*local)

func _visible_grab_point(node: Node3D,preferred: Vector3) -> Vector2:
	var point:=project_point(preferred)
	if not inspected or not is_instance_valid(local_surface):return point
	var area:=local_surface.get_global_rect()
	if area.size.x<30 or area.size.y<90:return point
	area=area.grow(-12)
	# Only the top-right is covered by the camera toolbar. At high zoom the
	# visible stock can be a narrow strip at the top-left of the stage.
	var toolbar_width:=minf(310,area.size.x*.55)
	var toolbar:=Rect2(Vector2(area.end.x-toolbar_width,area.position.y),Vector2(toolbar_width,58))
	var exposed:=func(candidate: Vector2):return area.has_point(candidate) and not toolbar.has_point(candidate)
	if exposed.call(point) and pick_drag_piece(point)==preview_id:return point
	var distance:=INF;var best:=point
	for part in TrialContact.meshes(node,node.global_transform):
		var faces: PackedVector3Array=part.mesh.get_faces()
		for index in range(0,faces.size(),3):
			var candidate:=project_point(part.pose*((faces[index]+faces[index+1]+faces[index+2])/3.0))
			if exposed.call(candidate) and candidate.distance_squared_to(area.get_center())<distance and pick_drag_piece(candidate)==preview_id:
				best=candidate;distance=candidate.distance_squared_to(area.get_center())
	if not is_finite(distance):
		for y in range(1,9):
			for x in range(1,9):
				var candidate:=area.position+area.size*Vector2(x/9.0,y/9.0)
				if exposed.call(candidate) and candidate.distance_squared_to(area.get_center())<distance and pick_drag_piece(candidate)==preview_id:
					best=candidate;distance=candidate.distance_squared_to(area.get_center())
	return best

func pick_drag_piece(point: Vector2) -> String:
	if preview_id.is_empty() or not pieces[preview_id].is_visible_in_tree(): return ""
	var origin: Vector3=camera.project_ray_origin(_camera_point(point))
	var direction: Vector3=camera.project_ray_normal(_camera_point(point))
	return preview_id if _hit_mesh(pieces[preview_id],origin,direction) else ""

func _hit_mesh(node: Node3D,origin: Vector3,direction: Vector3) -> bool:
	if node is MeshInstance3D and node.mesh!=null:
		var inverse: Transform3D=node.global_transform.affine_inverse()
		var local_origin:=inverse*origin
		var local_direction:=inverse.basis*direction
		if node.get_aabb().intersects_ray(local_origin,local_direction)!=null:
			var faces: PackedVector3Array=node.mesh.get_faces()
			for i in range(0,faces.size(),3):
				if Geometry3D.ray_intersects_triangle(local_origin,local_direction,faces[i],faces[i+1],faces[i+2])!=null: return true
	for child in node.get_children():
		if child is Node3D and child.visible and _hit_mesh(child,origin,direction): return true
	return false

func _fit_camera() -> void:
	if not is_inside_tree():return
	if inspected:
		_fit_inspection()
		return
	var viewport_size:=get_viewport().get_visible_rect().size
	framing.fit_overview(viewport_size)

func _sync_background() -> void:
	for layer in [seam_lines,water,caulk]:
		if is_instance_valid(layer):layer.visible=not inspected
	if is_instance_valid(backdrop):backdrop.visible=is_visible_in_tree() and not inspected
	if _environment!=null:
		_environment.background_mode=Environment.BG_COLOR if inspected else Environment.BG_CANVAS
		_environment.background_color=Color("fff7e9")

func _process(_delta: float) -> void:
	_sync_model_seams()
	if inspected and framing.has_rotated():_fit_inspection()
func _sync_model_seams() -> void:
	if not is_instance_valid(model_seams):return
	var row: int=Rules.row_for(current.selected) if current!=null else -1
	model_seams.visible=inspected and is_visible_in_tree() and row>0 and opening_geometry_id(current.selected)==current.selected
	if not model_seams.visible:return
	var layout: String=str(_built_layouts[current.selected])
	model_seams.sync(row,Rules.seam(layout),pieces[current.selected].transform,Rules.seam(str(current.layouts.get(row-1,"A"))),panel_transform(),row>0 and current.row_has_boards(row-1))

func connection_leak_points(ids: Array[String]) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for id in ids:
		var row: int=Rules.row_for(id)
		if row<0:continue # Interior frames are not holes in the hull skin.
		var box: AABB=TrialContact.bounds(TrialContact.meshes(pieces[id],Transform3D.IDENTITY))
		var mouth:=Vector3(box.get_center().x,box.position.y-.01,box.position.z)
		points.append(poses[id]*mouth)
	return points

func trial_presentation(rows: Array[int],connection_ids: Array[String],loose_ids: Array[String]):
	var presentation=TrialPresentation.new()
	presentation.type_error_ids.assign(loose_ids)
	for id in connection_ids:
		if Rules.row_for(id)<0:presentation.structural_ids.append(id)
	presentation.seam_rows.assign(rows)
	for row in rows:
		var pose: Transform3D=poses["plank_%da"%row]
		pose.origin=pose*G.Shell.point(Vector3(Rules.seam(str(current.layouts[row])),-.115,row*.78+.39))
		presentation.seam_poses.append(pose)
	presentation.connection_points.assign(connection_leak_points(connection_ids))
	for id in Rules.IDS:
		if current.placed.has(id) and resting.get(id,false):
			var direction: Vector3=Vector3.FORWARD if id=="cross_upper" and current.placed[id].opening=="B" else loose_directions.get(id,Vector3.UP)
			presentation.loose_parts.append(TrialPresentation.LoosePart.new(id,pieces[id],poses[id],direction))
	return presentation


func _trial_receivers(id: String) -> Array:
	var row:=Rules.row_for(id)
	if row==0:return [{"node":fixed.starter,"pose":fixed.starter.transform}]
	if row>0:
		var previous: String="plank_%d%s"%[row-1,"a" if id.ends_with("a") else "b"]
		return [{"node":pieces[previous],"pose":poses[previous]}]
	var key: String="cross_lower" if id=="cross_upper" else ("three_lower" if id.begins_with("three") else "bulk_base")
	var receivers: Array=[{"node":fixed[key],"pose":fixed[key].transform}]
	if id=="three_upper" and current.placed.has("three_middle"):receivers.append({"node":pieces.three_middle,"pose":poses.three_middle})
	return receivers

func toggle_connection_detail() -> void:
	if not transparent:
		_detail_frame={"center":framing._frame_center,"focus":framing._zoom_focus,"size":framing._inspection_size,"zoom":framing.zoom_factor,"orbit_center":observation_orbit._center,"angles":observation_orbit.angles}
		transparent=true
		framing.zoom_factor=1.0
		_fit_inspection()
	else:
		transparent=false
		if not _detail_frame.is_empty():
			framing._frame_center=_detail_frame.center;framing._zoom_focus=_detail_frame.focus
			framing._inspection_size=_detail_frame.size;framing.zoom_factor=_detail_frame.zoom
			observation_orbit._center=_detail_frame.orbit_center
			observation_orbit.angles=_detail_frame.angles;observation_orbit.target_angles=_detail_frame.angles
			observation_orbit._apply_camera()
			camera.size=maxf(framing._inspection_size,.8)*framing.zoom_factor
			_detail_frame.clear()
