extends RefCounted
## One teaching visit owns one source snapshot. Repeated suspend/restore is safe.
var suspended := false
var view: Node3D
var panel: CanvasLayer
var interaction: Node
var camera: Camera3D
var view_visible := true
var panel_visible := true
var input_flags: Array[bool] = []

func suspend(source_view: Node3D, source_panel: CanvasLayer, source_input: Node, viewport: Viewport) -> void:
	if suspended: return
	suspended = true
	view = source_view
	panel = source_panel
	interaction = source_input
	camera = viewport.get_camera_3d()
	if is_instance_valid(view):
		view_visible = view.visible
		view.hide()
	if is_instance_valid(panel):
		panel_visible = panel.visible
		panel.hide()
	if is_instance_valid(interaction):
		input_flags.assign([interaction.is_processing_input(), interaction.is_processing_unhandled_input(), interaction.is_processing_unhandled_key_input(), interaction.is_processing_shortcut_input()])
		if interaction.has_method("cancel"): interaction.cancel()
		interaction.set_process_input(false)
		interaction.set_process_unhandled_input(false)
		interaction.set_process_unhandled_key_input(false)
		interaction.set_process_shortcut_input(false)

func restore_camera() -> void:
	if is_instance_valid(view):
		var source_camera = view.get("camera")
		if source_camera is Camera3D:
			source_camera.make_current()
			return
	if is_instance_valid(camera): camera.make_current()

func restore() -> void:
	if not suspended: return
	suspended = false
	if is_instance_valid(view): view.visible = view_visible
	if is_instance_valid(panel): panel.visible = panel_visible
	if is_instance_valid(interaction) and input_flags.size() == 4:
		interaction.set_process_input(input_flags[0])
		interaction.set_process_unhandled_input(input_flags[1])
		interaction.set_process_unhandled_key_input(input_flags[2])
		interaction.set_process_shortcut_input(input_flags[3])
	restore_camera()
