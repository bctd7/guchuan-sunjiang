extends Control
## Noninteractive projected path. Actual input is picked from timber triangles.
var view: Node3D
var enabled := false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func configure(ship_view: Node3D,active: bool) -> void:
	view=ship_view
	enabled=active
	queue_redraw()
func _draw() -> void:
	if not enabled or not is_instance_valid(view) or view.preview_id.is_empty(): return
	var inverse:=get_global_transform_with_canvas().affine_inverse()
	var grip: Vector2=inverse*view.drag_grab_screen()
	var path: Vector2=inverse.basis_xform(view.drag_input_path_screen())
	var direction:=path.normalized()
	var color:=Color("b07828") if view.preview_progress>=.72 else Color("347778")
	var tip:=grip+direction*66
	draw_dashed_line(grip+direction*18,tip,color,3,7)
	draw_line(tip,tip-direction.rotated(.55)*14,color,3,true)
	draw_line(tip,tip-direction.rotated(-.55)*14,color,3,true)

func _process(_delta: float) -> void:
	if enabled and is_visible_in_tree():queue_redraw()
