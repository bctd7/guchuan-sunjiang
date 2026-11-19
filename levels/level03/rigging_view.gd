extends Node3D
const G = preload("res://models/ship/rigging/ship_geometry.gd")
const Rules = preload("res://levels/level03/connection_rules.gd")
const OFFSETS = {"zrail":Vector3(0,0,1.65),"leg":Vector3(0,-1.65,0),"mast":Vector3(0,1.6,0),"apron":Vector3(0,1.1,0),"top":Vector3(0,1.4,0),"lbrace":Vector3(1.65,0,0),"rudder":Vector3(0,2.6,0),"blade":Vector3(0,0,-1.5)}
const CENTERS = {"zrail":Vector3(.5,.6,.5),"leg":Vector3(.5,.45,.5),"mast":Vector3(0,1.5,0),"apron":Vector3(0,.20,0),"top":Vector3(0,.5,0),"lbrace":Vector3(0,-.10,0),"rudder":Vector3(2.3,.7,0),"blade":Vector3(2.3,-.75,0)}
var screen_surface: SubViewportContainer
var camera: Camera3D
var stages: Array[Node3D] = []
var pieces: Dictionary = {}
var markers: Dictionary = {}
var animations: Dictionary = {}
var rudder_pivot: Node3D
var preview: Node3D
var _preview_key := ""
var _selected: String = Rules.ORDER[0]
var launch_scene: Node3D
var warning_motion: Tween
var warning_part: Node3D
var warning_start: Transform3D
var _stage := -1
var _placed: Array = []
var cutaway := false
var focus_center := Vector3.ZERO
var _wood := G.wood()
var _light := G.wood(Color("dcc29b"))
func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("fff7e9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fffaf0")
	env.ambient_light_energy = .60
	world.environment = env
	add_child(world)
	for rotation in [Vector3(-48,-28,0),Vector3(-25,140,0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = .70 if rotation.y < 0 else .25
		add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = .05
	camera.current = true
	add_child(camera)
	for i in 3:
		var stage := Node3D.new()
		stage.name = "Workbench"+str(i+1)
		add_child(stage)
		stages.append(stage)
	_build_mast_base()
	_build_spar_seat()
	_build_rudder_frame()
	for id in Rules.ORDER:
		var p: Node3D = G.piece(id,Rules.SPECS[id].joint)
		var parent: Node3D = stages[int(Rules.SPECS[id].stage)]
		if id in ["rudder","blade"]:
			parent = rudder_pivot
			p.position = Vector3(-2.3,0,0)
		parent.add_child(p)
		pieces[id] = p
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .13
		sphere.height = .26
		marker.mesh = sphere
		marker.position = CENTERS[id]
		var mat := StandardMaterial3D.new()
		# Keep the existing screen-space hit proxy; StepGuide owns its visible cue.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1,1,1,0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat
		stages[int(Rules.SPECS[id].stage)].add_child(marker)
		markers[id] = marker
func _build_mast_base() -> void:
	var s := stages[0]
	G.box(s,Vector3(-3,-2.9,-.68),Vector3(3,-2.35,.68),_wood,"Keel")
	G.solid(s,[[Vector3(-.40,-2.35,-.40),Vector3(.40,.55,.40)]],[[Vector3(-.45,-.20,-.19),Vector3(.45,.7,.19)],[Vector3(-.45,.38,-.45),Vector3(-.25,.7,.45)],[Vector3(.25,.38,-.45),Vector3(.45,.7,.45)]],_wood,"KeelMountedFork")

func _build_spar_seat() -> void:
	var s := stages[1]
	G.zong(s,"xrail",_wood)
	G.cylinder(s,.37,4.2,Vector3(3.9,-1.35,.5),_wood,"MastAtSparHeight")
	G.lashing(s,Vector3(3.9,-.25,.5),.37)
	G.lashing(s,Vector3(3.9,-2.90,.5),.37)

func _build_rudder_frame() -> void:
	var s := stages[2]
	G.solid(s,[[Vector3(-.65,-1.5,-.62),Vector3(.65,1.5,.62)]],[[Vector3(-.16,-.31,-.26),Vector3(.7,.31,.26)],[Vector3(-.7,-.31,-.26),Vector3(0,-.06,.26)]],_wood,"SternPostSteppedSocket")
	for i in 5:
		var edge := -.80+.32*i
		G.box(s,Vector3(-2,-1.7,edge),Vector3(.8,-1.5,edge+.307),_wood,"SternDeckPlank")
	G.box(s,Vector3(-2,-1.95,-.8),Vector3(-1.75,1.7,.8),_light,"SternSideContext")
	rudder_pivot = Node3D.new()
	rudder_pivot.name = "OnlyRoundShaftAndBladeRotate"
	rudder_pivot.position = Vector3(2.3,0,0)
	s.add_child(rudder_pivot)
func sync_state(state) -> void:
	_clear_warning()
	_selected = state.selected
	_placed = state.placed.duplicate()
	var new_stage: int = state.stage_idx
	for i in 3: stages[i].visible = i == new_stage and not is_instance_valid(launch_scene)
	for id in pieces:
		pieces[id].visible = state.placed.has(id)
		if not animations.has(id): pieces[id].position = _base(id)
		markers[id].visible = int(Rules.SPECS[id].stage) == new_stage and id == state.selected and not state.placed.has(id)
	rudder_pivot.rotation_degrees.y = state.rudder_angle
	var key: String = state.selected+":"+state.candidate+":"+str(state.placed.has(state.selected))
	if key != _preview_key:
		_preview_key = key
		if is_instance_valid(preview):
			preview.get_parent().remove_child(preview)
			preview.queue_free()
			preview = null
		if not state.placed.has(state.selected):
			var kind: String = state.candidate if not state.candidate.is_empty() else str(Rules.SPECS[state.selected].joint)
			preview = G.piece(state.selected,kind)
			preview.name = "RealShipCandidate_"+state.selected
			stages[new_stage].add_child(preview)
			preview.position = OFFSETS[state.selected]
			if state.selected == "blade": preview.get_node("SideCap").position.z = 2.8
	if is_instance_valid(preview):
		if _selected == "mast":
			preview.position.x = .45 if state.setting == 0 else 0.0
		elif _selected == "rudder":
			# Line up the lower end above the bearing even when the axle is tilted.
			var tip := Vector3(2.3,-1.75,0)
			var tilt := Basis(Vector3.BACK,deg_to_rad(20) if state.setting == 1 else 0.0)
			var approach: Vector3 = OFFSETS.rudder
			if state.setting == 1:
				approach.y += .45
			preview.transform = Transform3D(tilt, approach + tip - tilt * tip)
		elif _selected == "leg":
			preview.rotation.z = PI if state.setting == 0 else 0.0
			preview.position.x = 1.0 if state.setting == 0 else 0.0
			preview.position.y = 2.7 if state.setting == 0 else OFFSETS.leg.y
	if _stage != new_stage:
		_stage = new_stage
		cutaway = false
		focus_current()
	elif not state.placed.has(state.selected): focus_current()
func _base(id: String) -> Vector3:
	return Vector3(-2.3,0,0) if id in ["rudder","blade"] else Vector3.ZERO
func trial_target(state) -> Transform3D:
	if not is_instance_valid(preview):return Transform3D.IDENTITY
	var target := preview.transform
	target.origin = Vector3.ZERO
	if state.selected == "mast" and state.setting == 0:
		target.origin = Vector3(.45,.73,0)
	elif state.selected == "rudder" and state.setting == 1:
		target.origin = preview.position - Vector3.UP * .58
	elif state.selected == "leg" and state.setting == 0:
		target.origin = Vector3(1,2,0)
	return target

func follow_blade_drag() -> void:
	if _selected == "blade" and is_instance_valid(preview):
		preview.get_node("SideCap").position.z = 1.3 - preview.position.z

func animate_place(id: String, released_offset: Variant = null) -> void:
	var p: Node3D = pieces[id]
	p.visible = true
	var offset: Vector3 = OFFSETS[id] if released_offset == null else released_offset
	p.position = _base(id) + offset
	var remaining := clampf(offset.length() / Vector3(OFFSETS[id]).length(),.12,1.0)
	var tween := create_tween()
	animations[id] = tween
	if id == "blade":
		p.get_node("SideCap").position.z = 1.3 - offset.z
		tween.tween_property(p,"position",_base(id),.8 * remaining)
		# Keep the opposite half at world Z=+1.3 while the open back half slides
		# in from -Z. The cap must never ride through the axle with the blade.
		tween.parallel().tween_property(p.get_node("SideCap"),"position:z",1.3,.8 * remaining)
		tween.tween_property(p.get_node("SideCap"),"position:z",0.0,.6)
	else:
		tween.tween_property(p,"position",_base(id),remaining).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		preload("res://audio/seating_audio.gd").play(self)
		animations.erase(id))
func focus_current() -> void:
	var center: Vector3
	var direction: Vector3
	var span: float
	if _stage == 1:
		center = Vector3(2.0,.75,2.2)
		direction = Vector3(8,5,10)
		span = 7.8
		if _selected == "leg":
			center = Vector3(1.6,-.9,1.8)
			direction = Vector3(7,-4.8,9)
			span = 8.0
	elif _stage == 0:
		center = Vector3(0,1.2 if _selected == "mast" else 0.0,0)
		direction = Vector3(7,3.5,10)
		span = 12.0 if _selected == "mast" else 7.0
	else:
		center = Vector3(1.0,.1,-.15)
		direction = Vector3(10,4.2,5)
		span = 6.9
	if cutaway:
		center = CENTERS[_selected]
		direction = Vector3(5,-3,7) if _selected in ["leg","top"] else Vector3(5,3,7)
		span = 3.2
	# Camera center shifts toward the GUI-free right side and leaves the gallery below.
	focus_center = center
	camera.position = center+direction
	camera.look_at(center)
	camera.size = span
	camera.h_offset = 0
	camera.v_offset = 0
func toggle_closeup() -> void:
	cutaway = not cutaway
	focus_current()
func socket_screen_position(id: String) -> Vector2:
	var point:=camera.unproject_position(markers[id].global_position)
	if is_instance_valid(screen_surface):
		return screen_surface.get_global_transform_with_canvas()*(point*screen_surface.size/Vector2(get_viewport().size))
	return Vector2(345,190)+point
func pick_socket(position: Vector2) -> String:
	for id in markers:
		if markers[id].is_visible_in_tree() and socket_screen_position(id).distance_to(position) <= 48: return id
	return ""

func _clear_warning() -> void:
	if warning_motion:
		warning_motion.kill()
		warning_motion = null
	if is_instance_valid(warning_part):
		warning_part.transform = warning_start
	warning_part = null

func show_failed_fit() -> void:
	if not is_instance_valid(preview): return
	_clear_warning()
	warning_part = preview
	if _selected == "leg":
		warning_part = pieces.zrail
	warning_start = warning_part.transform
	warning_motion = warning_part.create_tween()
	warning_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match _selected:
		"mast":
			var foot := Vector3(0,1.10,0)
			var contact := Vector3(preview.position.x,1.83,0)
			var lean := Basis(Vector3.BACK,deg_to_rad(-22))
			warning_motion.tween_property(preview,"position",contact - foot,.16)
			warning_motion.tween_property(preview,"transform",Transform3D(lean,contact - lean * foot),.30)
		"leg":
			# The sail loads the free end while the joint stays at the corner.
			var corner := Vector3(.5,.5,.5)
			var sag := Basis(Vector3.RIGHT,deg_to_rad(14))
			warning_motion.tween_property(warning_part,"transform",Transform3D(sag,corner - sag * corner),.35)
		"rudder":
			# The tilted tip enters only a short way before it catches on the rim.
			warning_motion.tween_property(preview,"position:y",preview.position.y - .58,.26)
	warning_motion.tween_interval(.22)
	warning_motion.tween_property(warning_part,"transform",warning_start,.32)

func start_launch() -> Tween:
	for stage in stages: stage.hide()
	launch_scene = preload("res://levels/level03/harbor_launch.gd").new()
	add_child(launch_scene)
	camera.position = Vector3(-3.0,4.1,11)
	camera.look_at(Vector3(0,1.85,0))
	camera.size = 6.5
	return launch_scene.sail_out()

func clear_launch() -> void:
	if is_instance_valid(launch_scene):
		remove_child(launch_scene)
		launch_scene.queue_free()
		launch_scene = null
		focus_current()
