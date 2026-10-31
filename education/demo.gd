extends Node3D
## Independent review scene. Assembled pose buttons are explicit fixture setup,
## not an alternate gameplay API and not a force solver.
const Assembly = preload("res://core/assembly.gd")
const Presenter = preload("res://education/presenter.gd")
var assembly: Node3D
var presenter: Node3D
var catalog: Array
var joint_picker: OptionButton
var part_picker: OptionButton
var camera: Camera3D

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	assembly = Assembly.new()
	add_child(assembly)
	presenter = Presenter.new()
	add_child(presenter)
	presenter.configure(assembly)
	camera = Camera3D.new()
	camera.position = Vector3(6,4,7)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("eee9de")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	add_child(light)
	var layer := CanvasLayer.new()
	add_child(layer)
	var left := VBoxContainer.new()
	left.position = Vector2(20,20)
	layer.add_child(left)
	var label := Label.new()
	label.text = "结构科普 · 独立审核场景\n只演示几何趋势，不计算真实受力"
	label.add_theme_color_override("font_color",Color("304638"))
	left.add_child(label)
	joint_picker = OptionButton.new()
	for item in catalog: joint_picker.add_item(item.name)
	joint_picker.item_selected.connect(load_joint)
	left.add_child(joint_picker)
	part_picker = OptionButton.new()
	part_picker.item_selected.connect(func(index: int):
		var entries: Array = presenter.profiles[assembly.definition.id]
		assembly.select_part(entries[index].part))
	left.add_child(part_picker)
	var seated_button := Button.new()
	seated_button.text = "审核夹具：全部置于到位姿态"
	seated_button.pressed.connect(seat_fixture)
	left.add_child(seated_button)
	var reset_button := Button.new()
	reset_button.text = "审核夹具：恢复分离姿态"
	reset_button.pressed.connect(assembly.reset)
	left.add_child(reset_button)
	var xray := CheckButton.new()
	xray.text = "现有透视（非剖切）"
	xray.toggled.connect(assembly.set_xray)
	left.add_child(xray)
	var panel: Control = presenter.create_panel()
	panel.position = Vector2(1120,20)
	layer.add_child(panel)
	load_joint(0)

func load_joint(index: int) -> void:
	assembly.load_definition(catalog[index])
	part_picker.clear()
	for entry in presenter.profiles[catalog[index].id]: part_picker.add_item(assembly.specs[entry.part].name)
	assembly.select_part(presenter.profiles[catalog[index].id][0].part)
	seat_fixture()

func seat_fixture() -> void:
	for id in assembly.parts: assembly.parts[id].transform = assembly.assembled_pose(id)
	assembly.changed.emit()
