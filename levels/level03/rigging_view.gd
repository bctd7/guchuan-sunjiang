extends Node3D
const G = preload("res://models/ship/rigging/ship_geometry.gd")
const Rules = preload("res://levels/level03/connection_rules.gd")
const OFFSETS = {"zrail":Vector3(0,0,1.65),"leg":Vector3(0,-1.65,0),"mast":Vector3(0,1.6,0),"apron":Vector3(0,1.1,0),"top":Vector3(0,1.4,0),"lbrace":Vector3(1.65,0,0),"rudder":Vector3(0,2.6,0),"blade":Vector3(0,0,-1.5)}
const CENTERS = {"zrail":Vector3(.5,.6,.5),"leg":Vector3(.5,.45,.5),"mast":Vector3(2.7,.8,2.5),"apron":Vector3(0,.20,0),"top":Vector3(0,.5,0),"lbrace":Vector3(0,-.10,0),"rudder":Vector3(2.3,.7,0),"blade":Vector3(2.3,-.75,0)}
var screen_surface: SubViewportContainer
var camera: Camera3D
var stages: Array[Node3D] = []
var pieces: Dictionary = {}
var markers: Dictionary = {}
var animations: Dictionary = {}
var rudder_pivot: Node3D
var preview: Node3D
var _preview_key := ""
var _selected := "zrail"
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
	env.background_color = Color("eee7d9")
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
	G.zong(s,"xrail",_wood)
	G.box(s,Vector3(0,0,4.4),Vector3(4.4,1,5.2),_wood,"FarFrameRail")
	G.box(s,Vector3(4.4,0,0),Vector3(5.2,1,5.2),_wood,"FarFrameEnd")
	# Structural crossbed has a real blind square socket with a solid bottom.
	G.solid(s,[[Vector3(1,0,2),Vector3(4.4,1,3)]],[[Vector3(2.4,.35,2.2),Vector3(3.0,1.1,2.8)]],_wood,"MastBedSquareSocket")
	for point in [Vector3(4.6,-1.0,.5),Vector3(4.6,-1.0,4.6),Vector3(.5,-1.0,4.6)]:
		G.box(s,point-Vector3(.16,1,.16),point+Vector3(.16,1,.16),_light,"TemporarySideSupport")
	# Deliberately no deck or tabletop beneath the moving corner leg.
func _build_spar_seat() -> void:
	var s := stages[1]
	G.solid(s,[[Vector3(-.40,-2.8,-.40),Vector3(.40,.55,.40)]],[[Vector3(-.45,-.20,-.19),Vector3(.45,.7,.19)],[Vector3(-.45,.38,-.45),Vector3(-.25,.7,.45)],[Vector3(.25,.38,-.45),Vector3(.45,.7,.45)]],_wood,"MastTopForkAndTwinTenons")
	G.cylinder(s,.38,1.2,Vector3(0,-3.3,0),_wood,"LowerMastContext")
func _build_rudder_frame() -> void:
	var s := stages[2]
	G.solid(s,[[Vector3(-.65,-1.5,-.62),Vector3(.65,1.5,.62)]],[[Vector3(-.16,-.31,-.26),Vector3(.7,.31,.26)],[Vector3(-.7,-.31,-.26),Vector3(0,-.06,.26)]],_wood,"SternPostSteppedSocket")
	G.box(s,Vector3(-2,-1.7,-.8),Vector3(.8,-1.5,.8),_wood,"SternDeckEdge")
	G.box(s,Vector3(-2,-1.95,-.8),Vector3(-1.75,1.7,.8),_light,"SternSideContext")
	rudder_pivot = Node3D.new()
	rudder_pivot.name = "OnlyRoundShaftAndBladeRotate"
	rudder_pivot.position = Vector3(2.3,0,0)
	s.add_child(rudder_pivot)
func sync_state(state) -> void:
	_selected = state.selected
	_placed = state.placed.duplicate()
	var new_stage: int = state.stage_idx
	for i in 3: stages[i].visible = i == new_stage
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
		if not state.placed.has(state.selected):
			var kind: String = state.candidate if not state.candidate.is_empty() else str(Rules.SPECS[state.selected].joint)
			preview = G.piece(state.selected,kind)
			preview.name = "RealShipCandidate_"+state.selected
			stages[new_stage].add_child(preview)
			preview.position = OFFSETS[state.selected]
			if state.selected == "blade": preview.get_node("SideCap").position.z = 2.8
	if _stage != new_stage:
		_stage = new_stage
		cutaway = false
		focus_current()
	elif not state.placed.has(state.selected): focus_current()
func _base(id: String) -> Vector3:
	return Vector3(-2.3,0,0) if id in ["rudder","blade"] else Vector3.ZERO
func animate_place(id: String) -> void:
	var p: Node3D = pieces[id]
	p.visible = true
	p.position = _base(id)+OFFSETS[id]
	var tween := create_tween()
	animations[id] = tween
	if id == "blade":
		p.get_node("SideCap").position.z = 2.8
		tween.tween_property(p,"position",_base(id),.8)
		# Keep the opposite half at world Z=+1.3 while the open back half slides
		# in from -Z. The cap must never ride through the axle with the blade.
		tween.parallel().tween_property(p.get_node("SideCap"),"position:z",1.3,.8)
		tween.tween_property(p.get_node("SideCap"),"position:z",0.0,.6)
	else:
		tween.tween_property(p,"position",_base(id),1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		preload("res://shared/seating_audio.gd").play(self)
		animations.erase(id))
func focus_current() -> void:
	var center: Vector3
	var direction: Vector3
	var span: float
	if _stage == 0:
		center = Vector3(2.0,.75,2.2)
		direction = Vector3(8,5,10)
		span = 9.3
		if _selected == "leg":
			center = Vector3(1.6,-.25,1.8)
			direction = Vector3(7,-4.8,9)
			span = 8.6
	elif _stage == 1:
		center = Vector3(0,-.3,0)
		direction = Vector3(7,3.5,10)
		span = 6.6
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
