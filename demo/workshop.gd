extends Node3D
const Assembly = preload("res://core/assembly.gd")
const Interaction = preload("res://core/interaction.gd")
const SciencePresenter = preload("res://education/presenter.gd")
const DynamicScience = preload("res://education/dynamic/presenter.gd")
const WorkshopLook = preload("res://demo/workshop_look.gd")
const ForceGallery = preload("res://education/force_gallery/presenter.gd")
var force_gallery: CanvasLayer
var education_input_suspended := false
var education_previous_process_mode: int
var dynamic_science: CanvasLayer
var science_entry: Button
var science_presenter: Node3D
var assembly: JoineryAssembly
var interaction: JoineryInteraction
var catalog: Array
## Optional embedding scope. Empty keeps the complete original nine lessons.
var lesson_filter: Array[String] = []
var picker: OptionButton
var status: Label
var buttons: Dictionary = {}
var camera: Camera3D
const WorkshopPanel = preload("res://demo/workshop_panel.gd")
var workshop_panel: PanelContainer
var entry_view_poses: Dictionary = {}

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://models/catalog.json"))
	if not lesson_filter.is_empty():
		var scoped_catalog: Array = []
		for id in lesson_filter:
			for definition in catalog:
				if str(definition.id) == id:
					scoped_catalog.append(definition)
					break
		if not scoped_catalog.is_empty(): catalog = scoped_catalog
	assembly = Assembly.new()
	add_child(assembly)
	camera = Camera3D.new()
	camera.fov = 42
	add_child(camera)
	interaction = Interaction.new()
	interaction.orbit.center_framing_contents = true
	add_child(interaction)
	interaction.configure(assembly, camera)
	WorkshopLook.install(self)
	science_presenter = SciencePresenter.new()
	add_child(science_presenter)
	science_presenter.configure(assembly)
	dynamic_science = DynamicScience.new()
	add_child(dynamic_science)
	force_gallery = ForceGallery.new()
	add_child(force_gallery)
	WorkshopLook.style_lesson(dynamic_science)
	WorkshopLook.style_lesson(force_gallery)
	dynamic_science.lesson_visibility_changed.connect(_education_visibility_changed)
	force_gallery.lesson_visibility_changed.connect(_education_visibility_changed)
	_build_ui()
	get_viewport().size_changed.connect(_update_framing)
	assembly.changed.connect(refresh)
	assembly.feedback.connect(show_feedback)
	load_joint(0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorkshopUI"
	add_child(layer)
	workshop_panel = WorkshopPanel.new()
	layer.add_child(workshop_panel)
	workshop_panel.configure(catalog)
	picker = workshop_panel.picker
	science_entry = workshop_panel.science_entry
	status = workshop_panel.status
	buttons = workshop_panel.buttons
	workshop_panel.joint_selected.connect(load_joint)
	workshop_panel.science_requested.connect(_open_education)
	workshop_panel.xray_requested.connect(assembly.set_xray)
	workshop_panel.view_requested.connect(_reset_view)
	workshop_panel.reset_requested.connect(func():
		interaction.cancel()
		assembly.reset()
		_update_framing())
	workshop_panel.resized.connect(_update_framing)

func load_joint(index: int) -> void:
	if dynamic_science.opened: dynamic_science.close()
	if force_gallery.opened: force_gallery.close()
	interaction.cancel()
	assembly.load_definition(catalog[index])
	WorkshopLook.apply_materials(assembly)
	entry_view_poses.clear()
	for part_id in assembly.parts: entry_view_poses[part_id] = assembly.parts[part_id].transform
	assembly.set_xray(assembly.xray)
	_update_framing()
	for spec in assembly.definition.parts:
		if not spec.get("fixed", false):
			assembly.select_part(str(spec.id))
			break
	refresh()

func refresh() -> void:
	if not is_instance_valid(workshop_panel): return
	var joint_id := str(assembly.definition.get("id",""))
	science_entry.visible = joint_id == "dovetail" or force_gallery.profiles.has(joint_id)
	science_entry.text = str(assembly.definition.get("name",""))+"受力演示"
	var id := assembly.selected
	buttons.xray.set_pressed_no_signal(assembly.xray)
	var complete := not assembly.parts.is_empty()
	for part_id in assembly.parts:
		if assembly.states[part_id] != "locked": complete = false
	status.text = "已完成" if complete else "待拼装"
	if not id.is_empty() and assembly.is_guided(id):
		status.text = "拼装中 · %d%%" % roundi(100.0*float(assembly.progress[id])/assembly.path_length(id))

func reason_text(reason: String) -> String:
	return {"collision_blocked":"碰撞阻挡","invalid_path_pose":"路径姿态不符","ready":"可校准","guided":"已校准","permanent_lock":"已固定","withdrawn":"已退回","distance":"未到入口","angle":"方向未对齐","dependency":"先装前置木件","occupied":"接口已占用","busy":"拼装中","pair":"接口不匹配","locked":"已固定","remove_dependents_first":"已固定"}.get(reason,reason)

func show_feedback(message: String) -> void:
	status.text = reason_text(message)

func _update_framing(request_fit: bool = true) -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0 or size.y <= 0: return
	var margin := 12.0 if size.x < 800 else 20.0
	var left := workshop_panel.get_global_rect().end.x+margin
	var rect := Rect2(Vector2(left/size.x,margin/size.y),Vector2(maxf(.1,1.0-(left+margin)/size.x),maxf(.1,1.0-margin*2/size.y)))
	interaction.orbit.framing_rect = rect
	interaction.orbit.screen_center_x = rect.get_center().x
	interaction.orbit.screen_center_y = rect.get_center().y
	if request_fit: interaction.request_fit()

func _reset_view() -> void:
	interaction.cancel()
	interaction.yaw = .68
	interaction.pitch = .42
	_update_framing(false)
	# Recompute the entry framing for the current viewport, without moving parts.
	interaction.orbit.fit_model(0.0,entry_view_poses)
	var entry_distance: float = interaction.distance
	# Current loose pieces may need more room; a completed model may not pull in.
	interaction.orbit.fit_model(entry_distance)

func _open_education() -> void:
	var joint_id := str(assembly.definition.get("id",""))
	if joint_id == "dovetail":
		if force_gallery.opened: force_gallery.close()
		dynamic_science.open_for_joint(joint_id)
	else:
		if dynamic_science.opened: dynamic_science.close()
		force_gallery.show_joint(joint_id)

func _education_visibility_changed(_is_open: bool) -> void:
	var any_open: bool = dynamic_science.opened or force_gallery.opened
	if any_open and not education_input_suspended:
		education_previous_process_mode = interaction.process_mode
		interaction.cancel()
		interaction.process_mode = Node.PROCESS_MODE_DISABLED
		education_input_suspended = true
	elif not any_open and education_input_suspended:
		interaction.process_mode = education_previous_process_mode
		education_input_suspended = false
