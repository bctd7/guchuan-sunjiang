extends HBoxContainer
signal chosen(kind: String)
const G = preload("res://models/ship/rigging/ship_geometry.gd")
const Rules = preload("res://levels/level03/connection_rules.gd")
const EndCrop = preload("res://levels/shared/mesh_end_crop.gd")
var buttons: Dictionary = {}
var viewports: Dictionary = {}
var specimens: Dictionary = {}
var _id := ""
const CROPS = {
	"zrail":AABB(Vector3(-.05,-.05,-.05),Vector3(1.10,1.10,1.5)),
	"leg":AABB(Vector3(-.05,-.20,-.05),Vector3(1.10,1.25,1.10)),
	"mast":AABB(Vector3(2.20,.3,2.0),Vector3(1.0,1.0,1.0)),
	"apron":AABB(Vector3(-.8,-.75,-.4),Vector3(1.6,1.15,.8)),
	"top":AABB(Vector3(-.8,.35,-.6),Vector3(1.6,.41,1.2)),
	"lbrace":AABB(Vector3(-.85,-.55,-.5),Vector3(1.75,1.1,1.0)),
	"rudder":AABB(Vector3(1.9,.3,-.4),Vector3(.8,1.0,.8)),
	"blade":AABB(Vector3(1.9,-1.75,-1.35),Vector3(.8,1.2,1.75))
}
func configure(id: String) -> void:
	if id == _id: return
	_id = id
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	viewports.clear()
	specimens.clear()
	add_theme_constant_override("separation",14)
	for kind in Rules.candidates(id):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(column)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.custom_minimum_size = Vector2(180,118)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320,118)
		viewport.own_world_3d = true
		container.add_child(viewport)
		viewports[kind] = viewport
		var part := G.piece(id,kind)
		part.name = "ActualShipCandidate_"+id+"_"+kind
		viewport.add_child(part)
		var specimen := Node3D.new()
		specimen.name = part.name+"_ActualEndCrop"
		specimen.set_meta("ship_member",id)
		specimen.set_meta("candidate_kind",kind)
		viewport.add_child(specimen)
		EndCrop.copy_into(part,specimen,CROPS[id])
		part.queue_free()
		specimens[kind] = specimen
		var world := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("e8e0ce")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("fffaf0")
		env.ambient_light_energy = .7
		world.environment = env
		viewport.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-25,0)
		viewport.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(40,145,0)
		fill.light_energy = .65
		viewport.add_child(fill)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = 1.65
		viewport.add_child(camera)
		var center: Vector3 = CROPS[id].get_center()
		var below: bool = id in ["zrail","top"]
		var direction := Vector3(4,-3 if below else 3,6)
		if id == "zrail": direction = Vector3(5,-4,-6)
		if id == "lbrace": direction = Vector3(1.5,2,7)
		camera.position = center+direction
		camera.look_at(center)
		var min_point := Vector2(INF,INF)
		var max_point := Vector2(-INF,-INF)
		for mesh_node in specimen.get_children():
			for vertex in mesh_node.mesh.get_faces():
				var point: Vector3 = camera.to_local(vertex)
				min_point = min_point.min(Vector2(point.x,point.y))
				max_point = max_point.max(Vector2(point.x,point.y))
		var span := max_point-min_point
		camera.size = maxf(span.y,span.x/2.65)*1.25
		var offset := (max_point+min_point)*.5
		camera.position += camera.basis*Vector3(offset.x,offset.y,0)
		camera.current = true
		var button := Button.new()
		button.text = Rules.NAMES[kind]
		button.custom_minimum_size.y = 44
		button.toggle_mode = true
		column.add_child(button)
		buttons[kind] = button
		button.pressed.connect(func(): chosen.emit(kind))
func select(kind: String) -> void:
	for id in buttons: buttons[id].set_pressed_no_signal(id == kind)
