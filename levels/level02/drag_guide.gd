extends Control
var guidance_blocker: Control
## Noninteractive projected path. Actual input is picked from timber triangles.
var view: Node3D
var enabled := false
var selection_ready := false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func configure(ship_view: Node3D,active: bool) -> void:
	view=ship_view
	enabled=active
	queue_redraw()
func _draw() -> void:
	if is_instance_valid(guidance_blocker) and guidance_blocker.is_visible_in_tree():return
	if not enabled or not selection_ready or not is_instance_valid(view) or view.preview_id.is_empty(): return
	var inverse:=get_global_transform_with_canvas().affine_inverse()
	var grip: Vector2=inverse*view.drag_grab_screen()
	var path: Vector2=inverse.basis_xform(view.drag_input_path_screen())
	var direction:=path.normalized()
	preload("res://levels/shared/step_guide.gd").draw_direction(self,grip,direction)

func _process(_delta: float) -> void:
	if enabled and is_visible_in_tree():queue_redraw()
