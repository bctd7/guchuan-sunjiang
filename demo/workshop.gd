extends Node3D
const Assembly = preload("res://core/assembly.gd")
const Interaction = preload("res://core/interaction.gd")
var assembly: JoineryAssembly
var interaction: JoineryInteraction
var catalog: Array
var picker: OptionButton
var part_list: ItemList
var detail: Label
var status: Label
var title: Label
var help: Label
var buttons: Dictionary = {}
var camera: Camera3D
var refreshing := false

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	assembly = Assembly.new()
	add_child(assembly)
	camera = Camera3D.new()
	camera.fov = 42
	add_child(camera)
	interaction = Interaction.new()
	add_child(interaction)
	interaction.configure(assembly, camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e6ebe7")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff3dc")
	environment.environment.ambient_light_energy = 0.32
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-30,0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20,140,0)
	fill.light_energy = 0.22
	add_child(fill)
	_build_ui()
	assembly.changed.connect(refresh)
	assembly.feedback.connect(show_feedback)
	load_joint(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24,24)
	panel.custom_minimum_size = Vector2(330,820)
	layer.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("faf8f1")
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("304638"))
	for type in ["Button", "OptionButton", "CheckButton"]:
		theme.set_color("font_color", type, Color("304638"))
		theme.set_color("font_hover_color", type, Color("213e2e"))
		theme.set_color("font_pressed_color", type, Color("213e2e"))
		theme.set_color("font_disabled_color", type, Color("778278"))
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var background := StyleBoxFlat.new()
			background.bg_color = Color("e1e9dd") if state != "disabled" else Color("eeede6")
			if state == "hover": background.bg_color = Color("d2dfcd")
			if state == "pressed": background.bg_color = Color("bed2b9")
			background.set_corner_radius_all(5)
			background.content_margin_left = 8
			background.content_margin_right = 8
			background.content_margin_top = 5
			background.content_margin_bottom = 5
			theme.set_stylebox(state, type, background)
	var list_background := StyleBoxFlat.new()
	list_background.bg_color = Color("e8ede3")
	list_background.set_corner_radius_all(5)
	theme.set_stylebox("panel", "ItemList", list_background)
	theme.set_color("font_color", "ItemList", Color("304638"))
	theme.set_color("font_selected_color", "ItemList", Color("213e2e"))
	var selection_background := StyleBoxFlat.new()
	selection_background.bg_color = Color("cbdcc5")
	theme.set_stylebox("selected", "ItemList", selection_background)
	theme.set_stylebox("selected_focus", "ItemList", selection_background)
	panel.theme = theme
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var brand := Label.new()
	brand.text = "古船榫匠"
	brand.add_theme_font_size_override("font_size",30)
	box.add_child(brand)
	var subtitle := Label.new()
	subtitle.text = "JOINERY  /  形与合"
	subtitle.add_theme_font_size_override("font_size",14)
	box.add_child(subtitle)
	picker = OptionButton.new()
	for item in catalog: picker.add_item(item.name)
	picker.item_selected.connect(load_joint)
	box.add_child(picker)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 285
	box.add_child(title)
	part_list = ItemList.new()
	part_list.custom_minimum_size = Vector2(285,110)
	part_list.item_selected.connect(func(index: int):
		if not refreshing:
			interaction.activate()
			assembly.select_part(str(assembly.definition.parts[index].id)))
	box.add_child(part_list)
	detail = Label.new()
	detail.custom_minimum_size = Vector2(285,52)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	var rotation_label := Label.new()
	rotation_label.text = "旋转木件  ·  每次 15°"
	box.add_child(rotation_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for pair in [["X", Vector3.RIGHT], ["Y", Vector3.UP], ["Z", Vector3.BACK]]:
		for sign_value in [-1,1]:
			var button := Button.new()
			button.text = pair[0] + ("−" if sign_value < 0 else "+")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func():
				if not assembly.selected.is_empty(): assembly.rotate_part(assembly.selected, pair[1], deg_to_rad(15.0 * sign_value)))
			row.add_child(button)
	_add_button(box, "align", "移至入口 · 辅助对齐", func():
		if not assembly.selected.is_empty(): assembly.set_part_pose(assembly.selected, assembly.entrance_pose(assembly.selected)))
	_add_button(box, "insert", "沿路径装入  ↵", func():
		if not assembly.selected.is_empty(): assembly.insert_part(assembly.selected))
	_add_button(box, "remove", "逆路径拆卸  Del", func():
		if not assembly.selected.is_empty(): assembly.remove_part(assembly.selected))
	var xray := CheckButton.new()
	xray.text = "透视内孔"
	xray.toggled.connect(assembly.set_xray)
	box.add_child(xray)
	_add_button(box, "reset", "重置全部", func():
		interaction.cancel()
		assembly.reset())
	help = Label.new()
	help.text = "拖近蓝色入口 → 变绿后松手装入\n空白拖动环绕 · 滚轮缩放\nEsc 取消 · 失焦自动安全停止"
	help.add_theme_font_size_override("font_size",14)
	box.add_child(help)
	status = Label.new()
	status.custom_minimum_size.x = 285
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "选择木件，观察接口后开始"
	box.add_child(status)
	var badge := Label.new()
	badge.position = Vector2(400,32)
	badge.text = "木作连接实验台    /    模型 · 交互审核版"
	badge.add_theme_color_override("font_color", Color("516857"))
	badge.add_theme_font_size_override("font_size",18)
	layer.add_child(badge)

func _add_button(box: VBoxContainer, id: String, text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	box.add_child(button)
	buttons[id] = button

func load_joint(index: int) -> void:
	interaction.cancel()
	assembly.load_definition(catalog[index])
	assembly.set_xray(assembly.xray)
	title.text = str(catalog[index].get("variant", ""))
	var bounds := AABB()
	var first := true
	for id in assembly.parts:
		var part: Node3D = assembly.parts[id]
		var mesh: MeshInstance3D = part.get_node("Wood")
		var part_bounds: AABB = part.transform * mesh.get_aabb()
		bounds = part_bounds if first else bounds.merge(part_bounds)
		first = false
	var aspect := 1440.0 / 900.0
	var half_fov := tan(deg_to_rad(camera.fov) * 0.5)
	interaction.distance = maxf(11.5,bounds.size.length() * 0.5 / (half_fov * 0.72) * 1.05)
	var right := Vector3(cos(interaction.yaw),0,-sin(interaction.yaw))
	interaction.target = bounds.get_center() - right * interaction.distance * half_fov * aspect * (380.0 / 1440.0)
	interaction.update_camera()
	status.text = "选择木件，蓝色虚影表示装配入口"
	for spec in assembly.definition.parts:
		if not spec.get("fixed", false):
			assembly.select_part(str(spec.id))
			break
	refresh()

func refresh() -> void:
	if not is_instance_valid(part_list): return
	refreshing = true
	part_list.clear()
	var index := 0
	for spec in assembly.definition.get("parts", []):
		var state: String = assembly.states.get(spec.id, "free")
		var suffix: String = {"free":"待装", "locked":"已固定", "inserting":"装入中", "removing":"拆卸中", "cancelling":"安全退回中", "paused":"受阻暂停，请重置"}.get(state, state)
		part_list.add_item(str(spec.get("name", spec.id)) + "  ·  " + str(suffix))
		if spec.id == assembly.selected: part_list.select(index)
		index += 1
	var id := assembly.selected
	var editable := not id.is_empty() and assembly.is_editable(id)
	buttons.align.disabled = not editable
	buttons.insert.disabled = not editable
	buttons.remove.disabled = id.is_empty() or not assembly.can_remove(id)
	detail.text = "每个木件都有独立接口与装配路径"
	if not id.is_empty():
		var result := assembly.candidate(id)
		if assembly.capture_preview == id: result = {"reason":"release_to_insert"}
		detail.text = str(assembly.specs[id].get("name", id)) + "\n" + reason_text(result.reason)
		if result.has("distance"): detail.text += "  %.2fm / %.0f°" % [result.distance, result.angle]
	refreshing = false

func reason_text(reason: String) -> String:
	if reason == "release_to_insert": return "入口已捕获：松手平滑对齐并装入"
	return {"collision_blocked":"木件受阻：请绕开实体或重新对准入口", "invalid_path_pose":"接口姿态与装配路径不一致", "ready":"接口已对齐，可以装入", "distance":"拖近蓝色入口虚影", "angle":"旋转方向尚未对齐", "dependency":"请先安装前序木件", "occupied":"连接已锁定", "busy":"正在运动", "pair":"接口不匹配", "locked":"装配完成，连接已锁定", "remove_dependents_first":"请先逆序拆下后装木件"}.get(reason, reason)

func show_feedback(message: String) -> void:
	status.text = reason_text(message)
