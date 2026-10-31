extends Node3D
## View-only geometry: gameplay owns connection decisions and state.
## All joints are teaching constructions, not claims about historical ships.

const IDS := ["keel", "rib_l1", "rib_r1", "rib_l2", "rib_r2", "rib_l3", "rib_r3", "bow", "stern", "beam1", "beam3"]
const LABELS := {"keel":"龙骨基座", "rib_l1":"左肋 1", "rib_r1":"右肋 1", "rib_l2":"左肋 2", "rib_r2":"右肋 2", "rib_l3":"左肋 3", "rib_r3":"右肋 3", "bow":"前段燕尾", "stern":"后段燕尾", "beam1":"前横撑", "beam3":"后横撑"}
const Backdrop = preload("res://levels/level01/workshop_backdrop.gd")
var backdrop: CanvasLayer
const Lengths=preload("res://levels/level01/length_geometry.gd")
const Candidate = preload("res://levels/level01/candidate_geometry.gd")
const TrialFit = preload("res://levels/level01/trial_fit.gd")
const Geometry = preload("res://levels/level01/ship_geometry.gd")
const Rules = preload("res://levels/level01/connection_rules.gd")
const STATIONS = Geometry.STATIONS
var camera: Camera3D
var slots: Dictionary = {}
var pieces: Dictionary = {}
## Detached construction originals outlive campaign reparenting/detachment.
var _baselines: Dictionary = {}
var ghosts: Dictionary = {}
var markers: Dictionary = {}
var labels: Dictionary = {}
var animations: Dictionary = {}
## Accepted state can refresh synchronously before its insertion is revealed.
## Planned pieces stay hidden at their entry pose; animations owns visible motion.
var planned_insertions: Dictionary = {}
const INSERTION_LEAD := .14
const INSERTION_DURATION := 1.50
const INSERTION_SETTLE := .12
var geometry: RefCounted
var _wood: StandardMaterial3D
var _wood_light: StandardMaterial3D
var _endgrain: StandardMaterial3D
var _ghost: StandardMaterial3D

func _ready() -> void:
	# Match the established workshop's natural wood palette.
	_wood = Geometry.material(Color("b89569"))
	_wood_light = Geometry.material(Color("dcc29b"))
	_endgrain = Geometry.material(Color("9e805d"))
	Geometry.add_subtle_grain(_wood, Vector3(5.0,5.0,.35))
	Geometry.add_subtle_grain(_wood_light, Vector3(.35,5.0,5.0))
	_ghost = Geometry.material(Color(0.23, 0.55, 0.57, 0.12))
	_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	geometry = Geometry.new(_wood,_wood_light,_endgrain)
	_build_environment()
	_build_parts()
	_build_targets()
	show_overview()
	sync_state(Rules.initial_connections(), "ribs", "rib_l1")

func configure(external_camera: Camera3D) -> void:
	if is_instance_valid(camera):
		camera.current = false
	camera = external_camera
	camera.current = true
	show_overview()

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -10
	environment.background_color = Color("eee7d9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fffaf0")
	environment.ambient_light_energy = 0.32
	environment_node.environment = environment
	add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-53, -28, 0)
	light.light_color = Color("fffbf5")
	light.light_energy = 0.65
	light.shadow_enabled = true
	light.shadow_opacity = .48
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_color = Color("edf2e5")
	fill.light_energy = 0.20
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.05
	camera.far = 100
	add_child(camera)
	backdrop=Backdrop.new()
	add_child(backdrop)
	visibility_changed.connect(func(): backdrop.visible=is_visible_in_tree())
	var shadow_material=Geometry.material(Color(0,0,0,0))
	shadow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shadow_to_opacity=true
	geometry.box(self,Vector3(200,.12,200),Vector3(0,-.32,0),shadow_material)
	# Workshop supports make the long central member easy to identify.
	for station in [-2.7, 2.7]:
		geometry.box(self, Vector3(2.1, 0.20, 0.40), Vector3(0, -0.13, station), Geometry.material(Color("b6b09b")))
		for side in [-0.85, 0.85]:
			geometry.box(self, Vector3(0.22, 0.30, 0.40), Vector3(side, -0.18, station), Geometry.material(Color("9d9989")))

func _build_parts() -> void:
	for id in IDS:
		var part := Node3D.new()
		part.name = id
		add_child(part)
		pieces[id] = part
		geometry.build(part,id)
		_baselines[id] = part.duplicate() as Node3D
		var preview := part.duplicate() as Node3D
		preview.name = id + "_preview"
		add_child(preview)
		_apply_material(preview, _ghost)
		ghosts[id] = preview

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for baseline in _baselines.values():
			if is_instance_valid(baseline): baseline.free()
		_baselines.clear()

func duplicate_part(id: String) -> Node3D:
	if not _baselines.has(id): return null
	return _baselines[id].duplicate() as Node3D

func _build_targets() -> void:
	var positions := {"keel":Vector3(0,.85,0),"bow":Vector3(0,1.2,-4.6),"stern":Vector3(0,1.2,4.6),"beam1":Vector3(0,2.8,-2.7),"beam3":Vector3(0,2.8,2.7)}
	for index in range(1,4):
		positions["rib_l%d" % index] = Vector3(-1.45,1.10,STATIONS[index-1])
		positions["rib_r%d" % index] = Vector3(1.45,1.10,STATIONS[index-1])
	for id in IDS:
		var anchor := Node3D.new()
		anchor.position = positions[id]
		add_child(anchor)
		slots[id] = anchor
		var badge := Label3D.new()
		badge.text = "●"
		badge.font_size = 96
		badge.pixel_size = .009
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.no_depth_test = true
		badge.modulate = Color("2d8086")
		badge.outline_size = 12
		badge.outline_modulate = Color("fff5dc")
		anchor.add_child(badge)
		markers[id] = badge
		var label := Label3D.new()
		label.text = LABELS[id]
		label.font_size = 36
		label.pixel_size = .009
		label.position.y = .48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color("28545b")
		label.outline_size = 8
		label.outline_modulate = Color("fff5dc")
		anchor.add_child(label)
		labels[id] = label

func sync_state(placed: Dictionary, stage: String, selected: String) -> void:
	if pieces.is_empty(): return
	for id in IDS:
		var part: Node3D = pieces[id]
		var length := str(placed[id].get("length","correct")) if placed.has(id) else "correct"
		var joint := str(placed[id].get("joint","")) if placed.has(id) else ""
		apply_fit_geometry(part,id,joint,length)
		part.visible = placed.has(id) and not planned_insertions.has(id)
		if not animations.has(id) and not planned_insertions.has(id):
			part.position = Vector3.ZERO
			part.rotation = Vector3.ZERO
			if placed.has(id): _apply_fit_pose(id,length,joint)
		var active := _stage_for(id) == stage
		ghosts[id].visible = not placed.has(id) and (active or stage == "complete")
		# The fixed foundation has no placement target, even if a stale caller selects it.
		slots[id].visible = id in Rules.REPRESENTATIVE_IDS and id == selected and not placed.has(id)
		if stage == "complete": slots[id].visible = false
		markers[id].modulate = Color("c29439") if placed.has(id) else (Color("29a79a") if id == selected else Color("507f88"))
		labels[id].text = str(LABELS[id]) + (" ✓" if placed.has(id) else "")
		if placed.has(id) and not TrialFit.is_stable(id,length,joint):
			markers[id].modulate = Color("ca6041")
			labels[id].text = str(LABELS[id]) + " · 连接待检查"

func _stage_for(id: String) -> String:
	if id == "keel": return "keel"
	if id.begins_with("rib_"): return "ribs"
	return "braces"

func prepare_place(id: String, length: String = "correct", joint: String = "") -> void:
	if not pieces.has(id): return
	if animations.has(id): (animations[id] as Tween).kill()
	animations.erase(id)
	var part: Node3D = pieces[id]
	apply_fit_geometry(part,id,joint,length)
	part.transform=trial_pose(id,length,joint)
	part.position += trial_entry_offset(id,length,joint)
	part.hide()
	Lengths.set_fasteners_visible(part,false)
	planned_insertions[id]={"length":length,"joint":joint}

func discard_prepared_place(id: String) -> void:
	planned_insertions.erase(id)

func animate_place(id: String, length: String = "correct", joint: String = "") -> void:
	if not pieces.has(id): return
	if not planned_insertions.has(id): prepare_place(id,length,joint)
	var part: Node3D = pieces[id]
	planned_insertions.erase(id)
	part.show()
	ghosts[id].visible = false
	var tween := create_tween()
	animations[id] = tween
	# A short entry hold and an even, readable approach make every member visible.
	tween.tween_interval(INSERTION_LEAD)
	tween.tween_property(part,"transform",trial_pose(id,length,joint),INSERTION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(INSERTION_SETTLE)
	tween.tween_callback(func():
		animations.erase(id)
		_apply_fit_pose(id,length,joint))

func insertion_offset(id: String) -> Vector3:
	return trial_entry_offset(id)

func cancel_animations() -> void:
	for tween in animations.values():
		if is_instance_valid(tween): tween.kill()
	animations.clear()
	for id in planned_insertions:
		(pieces[id] as Node3D).hide()
	planned_insertions.clear()

func connection_center(id: String) -> Vector3:
	if id.begins_with("rib_"):
		return Vector3(-.40 if id.begins_with("rib_l") else .40,.38,STATIONS[int(id.right(1))-1])
	if id == "bow" or id == "stern": return Vector3(0,.42,-4.0 if id == "bow" else 4.0)
	if id.begins_with("beam"): return Vector3(2.78,2.34,-2.7 if id == "beam1" else 2.7)
	return Vector3(0,.35,0)

func final_pose(id: String, length: String = "correct") -> Transform3D:
	return Lengths.seated_pose(id,length)

func trial_pose(id: String, length: String = "correct", joint: String = "") -> Transform3D:
	return TrialFit.pose(id,length,joint)

func trial_entry_offset(id: String, length: String = "correct", joint: String = "") -> Vector3:
	return TrialFit.entry_offset(id,length,joint)

func apply_fit_geometry(part: Node3D, id: String, joint: String, length: String = "correct") -> void:
	if not is_instance_valid(part) or not _baselines.has(id): return
	joint = TrialFit.resolved_joint(id,joint)
	var signature := id+"/"+joint+"/"+length
	if str(part.get_meta("fit_signature","")) == signature: return
	# Candidate's source guard remains intact: edits happen on a disposable
	# baseline clone, then its private children replace the visible member.
	var clone := duplicate_part(id)
	Lengths.apply(clone,id,length)
	Candidate.apply(clone,id,joint,self)
	for child in part.get_children():
		part.remove_child(child)
		child.free()
	for child in clone.get_children():
		clone.remove_child(child)
		part.add_child(child)
	for key in ["length_geometry","candidate_tip_path","candidate_axis"]:
		if part.has_meta(key): part.remove_meta(key)
		if clone.has_meta(key): part.set_meta(key,clone.get_meta(key))
	part.set_meta("fit_signature",signature)
	clone.free()

func apply_length_geometry(part: Node3D, id: String, length: String = "correct") -> void:
	apply_fit_geometry(part,id,"",length)

func _apply_length_pose(id: String, length: String) -> void:
	_apply_fit_pose(id,length,"")

func _apply_fit_pose(id: String, length: String, joint: String) -> void:
	var part: Node3D=pieces[id]
	part.transform=trial_pose(id,length,joint)
	Lengths.set_fasteners_visible(part,TrialFit.resolved_joint(id,joint)==TrialFit.expected_joint(id))

func show_instability(placed: Dictionary) -> Tween:
	cancel_animations()
	var affected: Array[String]=[]
	for id in placed:
		if id!="keel" and not TrialFit.is_stable(id,str(placed[id].get("length","correct")),str(placed[id].get("joint",""))): affected.append(id)
	var tween:=create_tween()
	animations["inspection"]=tween
	var update:=func(weight: float):
		for id in affected:
			var base: Transform3D=trial_pose(id,str(placed[id].get("length","correct")),str(placed[id].get("joint","")))
			var direction:=Vector3.RIGHT
			if id.begins_with("rib_"): direction=Vector3.LEFT if id.begins_with("rib_l") else Vector3.RIGHT
			elif id in ["bow","stern"]: direction=Vector3.BACK if id=="stern" else Vector3.FORWARD
			pieces[id].position=base.origin+direction*(.10 if id.begins_with("beam") else .045)*weight
	for repeat in 3:
		tween.tween_method(update,0.0,1.0,.20).set_trans(Tween.TRANS_SINE)
		tween.tween_method(update,1.0,0.0,.20).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): animations.erase("inspection"))
	return tween

func socket_screen_position(id: String) -> Vector2:
	if not slots.has(id) or not is_instance_valid(camera): return Vector2(-1000,-1000)
	return camera.unproject_position((slots[id] as Node3D).global_position)

func pick_socket(screen_pos: Vector2) -> String:
	var closest := ""
	var best_distance := 48.0
	for id in IDS:
		if not (slots[id] as Node3D).visible: continue
		var distance := socket_screen_position(id).distance_to(screen_pos)
		if distance < best_distance:
			best_distance = distance
			closest = id
	return closest

func focus_socket(id: String) -> void:
	if not slots.has(id): return
	var center := (slots[id] as Node3D).position
	if id.begins_with("rib_"):
		center.x = -.45 if id.begins_with("rib_l") else .45
		center.y = .45
	var look_center := center + Vector3(-.65,0,.50)
	_camera_to(look_center + Vector3(6,4.8,8),look_center,4.9)

func show_overview(top_down: bool = false) -> void:
	var center := Vector3(0,1,0)
	if top_down:
		camera.position = center + Vector3(0,18,0)
		camera.look_at(center,Vector3.FORWARD)
	else:
		_camera_to(center + Vector3(11,9,6),center,11.5)
	_fit_overview()

func show_automatic_overview(ids: Array, length: String = "correct", joint: String = "") -> void:
	var center := Vector3(0,1,0)
	_camera_to(center + Vector3(11,9,6),center,11.5)
	for id in ids:
		if pieces.has(id) and not pieces[id].visible: apply_fit_geometry(pieces[id],id,joint,length)
	_fit_overview(ids,length,joint)

func workshop_clear_rect() -> Rect2:
	var viewport_size:=get_viewport().get_visible_rect().size
	return Rect2(Vector2(365,190)*viewport_size/Vector2(1440,900),Vector2(1045,550)*viewport_size/Vector2(1440,900))

func _fit_overview(insertion_ids: Array = [], insertion_length: String = "correct", insertion_joint: String = "") -> void:
	# Fit the actual final ship section into the clear area beside the compact UI.
	# Reserve the whole group's entry paths once; the camera stays still per group.
	var points: Array[Vector3]=[]
	for part in pieces.values(): _model_corners(part,part.transform,points)
	for id in insertion_ids:
		if not pieces.has(id): continue
		var pose: Transform3D=trial_pose(id,insertion_length,insertion_joint)
		_model_corners(pieces[id],pose,points)
		pose.origin+=trial_entry_offset(id,insertion_length,insertion_joint)
		_model_corners(pieces[id],pose,points)
	if points.is_empty(): return
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for point in points:
		var local: Vector3=camera.global_transform.affine_inverse()*(global_transform*point)
		low=low.min(Vector2(local.x,local.y))
		high=high.max(Vector2(local.x,local.y))
	var viewport_size:=get_viewport().get_visible_rect().size
	var clear:=workshop_clear_rect()
	var span:=high-low
	camera.size=maxf(span.y/(clear.size.y/viewport_size.y),span.x/(clear.size.x/viewport_size.y))*1.06
	var desired: Vector2=(clear.get_center()-viewport_size/2)/viewport_size.y*camera.size
	var middle: Vector2=(low+high)/2
	camera.position+=camera.basis.x*(middle.x-desired.x)+camera.basis.y*(middle.y+desired.y)

func _model_corners(node: Node, parent_pose: Transform3D, points: Array[Vector3]) -> void:
	for child in node.get_children():
		if not child is Node3D: continue
		var pose: Transform3D=parent_pose*child.transform
		if child is MeshInstance3D:
			var box: AABB=child.mesh.get_aabb()
			for i in 8: points.append(pose*box.get_endpoint(i))
		_model_corners(child,pose,points)

func reset_view() -> void:
	show_overview()

func _camera_to(from: Vector3, target: Vector3, view_size: float) -> void:
	if not is_instance_valid(camera): return
	# Deliberately immediate: pointer target projection must remain deterministic.
	camera.position = from
	camera.look_at(target,Vector3.UP)
	camera.size = view_size

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): _apply_material(child,material)
