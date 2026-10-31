extends Node3D
## Read-only adapter. Sibling of assembly; never changes wood, collisions or state.
signal display_changed
const Geometry = preload("res://classroom/science/contact_geometry.gd")
const EducationPanel = preload("res://classroom/science/panel.gd")
var assembly: Node3D
var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://classroom/science/profiles.json"))
var enabled := false
var show_forces := true
var show_contacts := true
var show_motion := true
var case_index := 0
var visuals: Node3D
var profile: Dictionary = {}
var seated := false
var patch_triangles := 0
var removal_blocked := false
var _mesh_cache: Dictionary = {}

func configure(source: Node3D) -> void:
	if is_instance_valid(assembly) and assembly.changed.is_connected(refresh): assembly.changed.disconnect(refresh)
	assembly = source
	assembly.changed.connect(refresh)
	refresh()

func create_panel() -> Control:
	var panel := EducationPanel.new()
	panel.configure(self)
	return panel

func set_enabled(value: bool) -> void:
	enabled = value
	refresh()

func set_layer(layer_name: String, value: bool) -> void:
	match layer_name:
		"force": show_forces = value
		"contact": show_contacts = value
		"motion": show_motion = value
	refresh()

func set_case(index: int) -> void:
	case_index = clampi(index,0,1)
	refresh()

func focus_profile() -> Dictionary:
	if not is_instance_valid(assembly): return {}
	var entries: Array = profiles.get(assembly.definition.get("id",""),[])
	for item in entries:
		if item.part == assembly.selected: return item
	return entries[-1] if not entries.is_empty() else {}

func refresh() -> void:
	if is_instance_valid(visuals):
		remove_child(visuals)
		visuals.queue_free()
	visuals = Node3D.new()
	add_child(visuals)
	profile = focus_profile()
	seated = false
	removal_blocked = false
	patch_triangles = 0
	if profile.is_empty():
		display_changed.emit()
		return
	var part: Node3D = assembly.parts[profile.part]
	# Only a verified assembled pose of all relevant neighbors enables the schematic.
	seated = part.transform.is_equal_approx(assembly.assembled_pose(profile.part))
	var neighbors: Array = assembly.specs[profile.part].get("dependencies",[]).duplicate()
	for neighbor in profile.get("required_neighbors",[]):
		if not neighbors.has(neighbor): neighbors.append(neighbor)
	for dependency in neighbors:
		seated = seated and assembly.parts[dependency].transform.is_equal_approx(assembly.assembled_pose(dependency))
	for blocker in profile.get("blocked_by",[]):
		if assembly.parts[blocker].transform.is_equal_approx(assembly.assembled_pose(blocker)): removal_blocked = true
	if enabled:
		global_transform = assembly.global_transform
		if show_contacts:
			for spec in profile.faces: _patch(part,spec)
		if seated:
			var wood: MeshInstance3D = part.get_node("Wood")
			var center: Vector3 = part.transform * wood.mesh.get_aabb().get_center()
			var force := Geometry.vector(profile.proposed_force if case_index == 0 else profile.permissible)
			if show_forces:
				_arrow(center-force*1.35,force,0.95,Color("e7a039"),"F? 假设施力",false)
			if show_motion:
				var direction := Geometry.vector(profile.proposed_force if case_index == 0 else profile.permissible)
				var anchor := center + Vector3(0,0,0.9)
				_arrow(anchor,direction,0.9,Color("cc5460") if case_index==0 or removal_blocked else Color("31816a"),"受限 · 间隙闭合后" if case_index==0 else ("先移除上层" if removal_blocked else "可动 · 忽略摩擦"),true)
				if case_index == 0 or removal_blocked: _bar(anchor+direction*0.95,direction,Color("cc5460"))
	display_changed.emit()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth-tested, not x-ray. No edits to original wood material or transparency.
	return material

func _patch(part: Node3D, spec: Dictionary) -> void:
	var wood: MeshInstance3D = part.get_node("Wood")
	var key: String = str(wood.mesh.get_instance_id()) + JSON.stringify(spec)
	var mesh: ArrayMesh
	if _mesh_cache.has(key): mesh = _mesh_cache[key]
	else:
		var vertices := Geometry.extract(wood.mesh,spec)
		if vertices.is_empty(): return
		mesh = ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		_mesh_cache[key] = mesh
	patch_triangles += mesh.surface_get_array_len(0)/3
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(Color("218f9d"))
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.transform = part.transform
	visuals.add_child(visual)

func _segment(a: Vector3, b: Vector3, color: Color, radius: float = 0.018) -> void:
	var direction := b-a
	if direction.length() < 0.00001: return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = direction.length()
	cylinder.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.material_override = _material(color)
	node.position = (a+b)*0.5
	node.quaternion = Quaternion(Vector3.UP,direction.normalized())
	visuals.add_child(node)

func _arrow(origin: Vector3, direction: Vector3, length_value: float, color: Color, caption: String, dashed: bool) -> void:
	direction = direction.normalized()
	if dashed:
		for i in range(4): _segment(origin+direction*length_value*(float(i)/4.0),origin+direction*length_value*(float(i)/4.0+0.14),color)
	else: _segment(origin,origin+direction*length_value,color,0.027)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.085
	cone.height = 0.19
	var head := MeshInstance3D.new()
	head.mesh = cone
	head.material_override = _material(color)
	head.position = origin + direction * length_value
	head.quaternion = Quaternion(Vector3.UP,direction)
	visuals.add_child(head)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 27
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_modulate = Color("faf8f1")
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = origin + direction * (length_value+0.24)
	visuals.add_child(label)

func _bar(point: Vector3, direction: Vector3, color: Color) -> void:
	var side := direction.cross(Vector3.BACK).normalized()
	if side.length() < 0.5: side = Vector3.RIGHT
	_segment(point-side*0.17,point+side*0.17,color,0.024)

func summary() -> String:
	if profile.is_empty(): return "请选择教学模型。"
	var part_name: String = assembly.specs[profile.part].get("name",profile.part)
	var result := "观察对象："+part_name+"\n"
	result += profile.explanation if case_index==0 else profile.freedom
	if case_index == 1 and removal_blocked: result += "\n当前上层仍在位：此方向受限，先移除上层才可退出。"
	result += "\n\n" + ("到位姿态：展示假设施力与几何趋势。" if seated else "尚未到位：只标候选面，隐藏受力/可动箭头，避免把未接触画成承压。")
	result += "\n青色来自原网格面，不是应力大小；接触区存在装配间隙。承压反力若形成，其方向垂直局部接触面。被木件遮住时可用现有透视开关观察。"
	result += "\n\n假设：刚性几何、忽略摩擦/胶/销楔；不模拟变形、不求力或力矩平衡。箭头不按大小缩放，亦非完整受力图。"
	result += "\n本轮完成锁定是交互规则，不证明真实接头不能拔出。九种为木作教学变体，不是九种古船连接的考古认定。"
	return result
