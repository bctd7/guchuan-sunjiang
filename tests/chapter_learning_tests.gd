extends SceneTree
## Headless control-signal and state-preservation checks, not human GUI testing.
const Learning = preload("res://components/teaching/teaching_portal.gd")
const ModelPreview = preload("res://components/teaching/classroom/display/lesson_model_preview.gd")
const Workshop = preload("res://components/teaching/classroom/classroom.gd")
const GROUPS := [
	["dovetail", "blind_tenon", "through_tenon"],
	["cross_lap", "tongue_groove", "three_way_lap"],
	["zong_corner", "clamp_head", "l_through"]
]
var passed := 0
var failed := 0

class SourceView extends Node3D:
	var camera: Camera3D
	var state := {"placed": ["rib_l0"], "observed": ["bow"], "selected": "beam1", "revision": 17}
	var piece: Node3D
	func _ready() -> void:
		camera = Camera3D.new()
		add_child(camera)
		camera.position = Vector3(4, 3, 8)
		camera.make_current()
		piece = Node3D.new()
		piece.position = Vector3(1.3, .7, -.4)
		piece.rotation = Vector3(.2, .4, -.1)
		add_child(piece)

class SourceInput extends Node:
	var cancel_count := 0
	func cancel() -> void:
		cancel_count += 1
	func _input(_event: InputEvent) -> void: pass
	func _unhandled_input(_event: InputEvent) -> void: pass
	func _unhandled_key_input(_event: InputEvent) -> void: pass

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(description)

func run() -> void:
	root.size = Vector2i(1440, 900)
	for chapter in range(1, 4):
		await check_chapter_group_and_round_trip(chapter)
	await check_hidden_sources_and_disabled_input_are_preserved()
	await check_standalone_workshop_keeps_all_nine_original_lessons()
	print("CHAPTER LEARNING (headless control signals, no human GUI claim): %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func check_chapter_group_and_round_trip(chapter: int) -> void:
	var level := Node.new()
	root.add_child(level)
	var view := SourceView.new()
	level.add_child(view)
	var panel := CanvasLayer.new()
	level.add_child(panel)
	var interaction := SourceInput.new()
	level.add_child(interaction)
	var learning := Learning.new()
	level.add_child(learning)
	var state_before: Dictionary = view.state.duplicate(true)
	var piece_id := view.piece.get_instance_id()
	var pose_before: Transform3D = view.piece.transform
	var camera_pose: Transform3D = view.camera.transform
	learning.bind_source(view, panel, interaction, view.camera, interaction.cancel)
	learning.configure(chapter)
	await process_frame
	check(learning.lesson_ids == GROUPS[chapter - 1], "chapter %d has exact ordered group" % chapter)
	check(learning.lesson_buttons.keys() == GROUPS[chapter - 1], "chapter %d exposes exactly three lesson signals" % chapter)
	check(learning.opened and learning.modal_open(), "introduction is the first visible modal")
	check(learning.start_button.text == "开始本关", "first entry offers start chapter")
	check(not view.visible and not panel.visible, "source view and source panel suspended")
	check(not interaction.is_processing_input() and not interaction.is_processing_unhandled_input(), "source input cannot pass through introduction")
	check(interaction.cancel_count == 1, "source pointer ownership cancelled once per modal visit")
	check(learning.previews.size() == 3, "three original-model previews")
	for id in GROUPS[chapter - 1]:
		var preview = learning.previews[id]
		check_original_model_preview(preview, id)
		var definition_before: Dictionary = preview.definition.duplicate(true)
		var mesh_poses: Dictionary = {}
		for part_id in preview.mesh_nodes:
			mesh_poses[part_id] = preview.mesh_nodes[part_id].transform
		check(view.state == state_before and view.piece.get_instance_id() == piece_id and view.piece.transform == pose_before, "original model previews preserve source state and piece " + id)
		learning.lesson_buttons[id].pressed.emit()
		await process_frame
		check(not learning.opened and learning.modal_open(), "lesson replaces introduction " + id)
		check(is_instance_valid(learning.workshop), "original classroom instantiated " + id)
		var catalog_ids: Array = []
		for definition in learning.workshop.catalog: catalog_ids.append(str(definition.id))
		check(catalog_ids == GROUPS[chapter - 1], "classroom catalog scoped and ordered " + id)
		check(learning.workshop.picker.item_count == 3, "picker has only this chapter's three lessons " + id)
		check(learning.workshop.picker.selected == GROUPS[chapter - 1].find(id), "picker matches clicked lesson " + id)
		check(str(learning.workshop.assembly.definition.id) == id, "clicked lesson loads original assembly " + id)
		for definition in learning.workshop.assembly.definition.parts:
			check(learning.workshop.assembly.parts.has(str(definition.id)), "original assembly part exists " + id + "/" + str(definition.id))
		check(root.get_camera_3d() == learning.workshop.camera, "classroom camera active " + id)
		check(learning.back_button.visible, "internal introduction return button available " + id)
		# Original educational presenter remains accessible in the scoped instance.
		learning.workshop.science_entry.pressed.emit()
		var education = learning.workshop.dynamic_science if id == "dovetail" else learning.workshop.force_gallery
		check(education.opened, "original educational content opens " + id)
		learning.back_button.pressed.emit()
		await process_frame
		check(learning.opened and learning.modal_open() and learning.workshop == null, "internal back closes classroom and restores introduction " + id)
		check(root.get_camera_3d() == view.camera, "source camera selected after classroom closes " + id)
		check(view.state == state_before and view.piece.get_instance_id() == piece_id and view.piece.transform == pose_before, "introduction return preserves owner state and piece " + id)
		check(learning.previews[id] == preview and preview.definition == definition_before, "classroom round trip preserves read-only preview definition " + id)
		for part_id in mesh_poses:
			check(preview.mesh_nodes[part_id].transform == mesh_poses[part_id], "classroom round trip preserves preview mesh pose " + id + "/" + str(part_id))
	check(interaction.cancel_count == 1, "all lessons share one source suspension")
	learning.start_button.pressed.emit()
	await process_frame
	check(not learning.opened and not learning.modal_open(), "start returns to level")
	check(view.visible and panel.visible, "source visibility restored")
	check(interaction.is_processing_input() and interaction.is_processing_unhandled_input() and interaction.is_processing_unhandled_key_input(), "all original input flags restored")
	check(root.get_camera_3d() == view.camera and view.camera.transform == camera_pose, "current source camera pose restored without reset")
	check(view.state == state_before and view.piece.get_instance_id() == piece_id and view.piece.transform == pose_before, "start modifies no source state or piece")
	learning.show_intro()
	check(learning.start_button.text == "返回本关搭建", "revisit accurately offers return to chapter assembly")
	learning.start_button.pressed.emit()
	check(view.state == state_before and view.piece.transform == pose_before, "revisit round trip is read only")
	level.free()
	await process_frame

func check_original_model_preview(preview, id: String) -> void:
	var original_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	var original: Dictionary = {}
	for definition in original_catalog:
		if definition.id == id: original = definition
	check(preview is SubViewportContainer and preview.get_script() == ModelPreview, "preview uses real model viewport " + id)
	check(not original.is_empty() and preview.definition == original, "preview preserves full original catalog definition " + id)
	check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE and preview.viewport.gui_disable_input, "preview ignores pointer and viewport input " + id)
	check(preview.viewport.transparent_bg and preview.viewport.own_world_3d, "preview has transparent isolated world " + id)
	check(preview.camera.get_viewport() == preview.viewport and preview.viewport.get_camera_3d() == preview.camera, "preview camera belongs to its isolated viewport " + id)
	check(preview.mesh_nodes.size() == original.parts.size(), "preview contains every original model part " + id)
	var preview_methods: Array[String] = []
	var preview_script: Script = preview.get_script()
	for method in preview_script.get_script_method_list(): preview_methods.append(str(method.name))
	check(not preview.has_method("attempt_place") and not preview.has_method("load_joint") and not preview_methods.has("_input") and not preview_methods.has("_unhandled_input"), "preview has no classroom assembly or input controls " + id)
	for spec in original.parts:
		var part_id := str(spec.id)
		check(preview.mesh_nodes.has(part_id), "preview original part exists " + id + "/" + part_id)
		var visual: MeshInstance3D = preview.mesh_nodes[part_id]
		var source_mesh: Mesh=preview.original_meshes[part_id]
		check(source_mesh.resource_path==str(spec.mesh) and source_mesh==load(str(spec.mesh)), "preview retains original mesh reference " + id + "/" + part_id)
		check(visual.mesh!=source_mesh and visual.mesh.get_faces()==source_mesh.get_faces(), "display normal repair preserves every original triangle position " + id + "/" + part_id)
		check(visual.position.is_equal_approx(Vector3(spec.start_position[0], spec.start_position[1], spec.start_position[2])), "preview preserves original start position " + id + "/" + part_id)
		var rotation: Array = spec.get("start_rotation", [0, 0, 0])
		check(visual.rotation_degrees.is_equal_approx(Vector3(rotation[0], rotation[1], rotation[2])), "preview preserves original start rotation " + id + "/" + part_id)
		check(visual.get_script() == null and visual.get_child_count() == 0, "preview mesh has no mutable lesson behavior " + id + "/" + part_id)

func check_hidden_sources_and_disabled_input_are_preserved() -> void:
	var level := Node.new()
	root.add_child(level)
	var view := SourceView.new()
	level.add_child(view)
	view.hide()
	var panel := CanvasLayer.new()
	level.add_child(panel)
	panel.hide()
	var interaction := SourceInput.new()
	level.add_child(interaction)
	interaction.set_process_input(false)
	interaction.set_process_unhandled_input(false)
	interaction.set_process_unhandled_key_input(false)
	var learning := Learning.new()
	level.add_child(learning)
	learning.bind_source(view, panel, interaction, view.camera, interaction.cancel)
	learning.configure(1)
	learning.start_button.pressed.emit()
	check(not view.visible and not panel.visible, "preexisting hidden source visibility preserved")
	check(not interaction.is_processing_input() and not interaction.is_processing_unhandled_input() and not interaction.is_processing_unhandled_key_input(), "preexisting disabled input preserved")
	level.free()
	await process_frame

func check_standalone_workshop_keeps_all_nine_original_lessons() -> void:
	var standalone := Workshop.new()
	root.add_child(standalone)
	await process_frame
	check(standalone.lesson_filter.is_empty(), "standalone default filter remains empty")
	check(standalone.catalog.size() == 9 and standalone.picker.item_count == 9, "standalone classroom retains nine original lessons")
	var original_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	check(standalone.catalog == original_catalog, "standalone catalog matches original definitions without content edits")
	standalone.free()
	await process_frame
