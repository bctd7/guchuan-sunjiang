extends Control
## State-derived, input-transparent emphasis. Every contour uses one clock/style.
const GOLD := Color("b67b29")
const PERIOD := 2.3
const STROKE := 4
const HALO := 10
const OUTSET := 2.0
const RADIUS := 22.0
var target: Control
var blocker: Control:
	set(value):
		if is_instance_valid(blocker):
			blocker.visibility_changed.disconnect(_sync_activity)
		blocker = value
		if is_instance_valid(blocker):
			blocker.visibility_changed.connect(_sync_activity)
		_sync_activity()
var point_provider: Callable
var _buttons: Array = []
var _focus_styles: Dictionary={}
var outline := StyleBoxFlat.new()
func _ready() -> void:
	outline.draw_center=false
	outline.set_border_width_all(STROKE)
	outline.corner_detail=12
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus_mode=Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(_sync_activity)
	_sync_activity()

func show_target(area: Control = null, buttons: Array = []) -> void:
	var selected := [area] if area is Button else buttons
	if target == area and _buttons == selected and not point_provider.is_valid():
		return
	_restore()
	target = area
	_buttons = selected
	point_provider = Callable()
	_sync_activity()

func show_point(provider: Callable) -> void:
	show_target()
	point_provider = provider
	_sync_activity()

func _sync_activity() -> void:
	if not is_inside_tree():
		return
	var running := _available() and (not _buttons.is_empty() or point_provider.is_valid())
	set_process(running)
	if not running:
		_restore()
	queue_redraw()
static func pulse() -> float:
	return .5-.5*cos(TAU*float(Time.get_ticks_msec())/1000.0/PERIOD)
static func ink() -> Color:
	return Color(GOLD,.72+.28*pulse())
static func glow() -> float:
	return .14+.36*pulse()
func _available() -> bool:
	return is_visible_in_tree() and not (is_instance_valid(blocker) and blocker.is_visible_in_tree())
func highlighted_controls() -> Array[Control]:
	var result: Array[Control]=[]
	if not _available() or not is_instance_valid(target) or not target.is_visible_in_tree():return result
	for card in _buttons:
		if is_instance_valid(card) and card.is_visible_in_tree() and not card.disabled:
			result.append(card)
	return result
func _restore() -> void:
	for button in _focus_styles:
		if not is_instance_valid(button):continue
		if _focus_styles[button]==null:button.remove_theme_stylebox_override("focus")
		else:button.add_theme_stylebox_override("focus",_focus_styles[button])
	_focus_styles.clear()
func _process(_delta: float) -> void:
	if not _available():
		_restore();queue_redraw();return
	var cards:=highlighted_controls()
	for button in _focus_styles.keys():
		if not is_instance_valid(button):
			_focus_styles.erase(button)
		elif not cards.has(button):
			if _focus_styles[button]==null:button.remove_theme_stylebox_override("focus")
			else:button.add_theme_stylebox_override("focus",_focus_styles[button])
			_focus_styles.erase(button)
	for button in cards:
		if not _focus_styles.has(button):
			_focus_styles[button]=button.get_theme_stylebox("focus") if button.has_theme_stylebox_override("focus") else null
			button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	queue_redraw()
func _draw() -> void:
	if not _available():return
	if point_provider.is_valid():
		var point: Vector2=get_global_transform_with_canvas().affine_inverse()*point_provider.call()
		draw_ring(self,point)
		return
	var cards := highlighted_controls()
	var halo := HALO
	if cards.size() > 1 and target is BoxContainer:
		var gap := target.get_theme_constant("separation")
		halo = clampi(floori(gap * 0.5 - OUTSET - 1.0), 0, HALO)
	for card in cards:
		var contour: Control=card.get_meta("guide_outline",card)
		var rect=get_global_transform_with_canvas().affine_inverse()*contour.get_global_rect()
		outline.border_color=ink()
		outline.shadow_color=Color(GOLD,glow())
		outline.shadow_size=halo
		outline.set_corner_radius_all(18)
		var base=card.get_theme_stylebox("normal")
		if base is StyleBoxFlat:
			outline.corner_radius_top_left=base.corner_radius_top_left+int(OUTSET)
			outline.corner_radius_top_right=base.corner_radius_top_right+int(OUTSET)
			outline.corner_radius_bottom_left=base.corner_radius_bottom_left+int(OUTSET)
			outline.corner_radius_bottom_right=base.corner_radius_bottom_right+int(OUTSET)
		draw_style_box(outline,rect.grow(OUTSET))
static func draw_ring(canvas: Control,point: Vector2) -> void:
	for spread in range(HALO,0,-2):
		canvas.draw_arc(point,RADIUS,0,TAU,64,Color(GOLD,glow()/float(HALO)),STROKE+spread*2,true)
	canvas.draw_arc(point,RADIUS,0,TAU,64,ink(),STROKE,true)
static func draw_direction(canvas: Control,grip: Vector2,direction: Vector2) -> void:
	draw_ring(canvas,grip)
	var tip:=grip+direction*76
	var segments: Array[Vector2]=[grip+direction*(RADIUS+6),tip,tip-direction.rotated(.55)*17,tip,tip-direction.rotated(-.55)*17,tip]
	for i in range(0,segments.size(),2):
		for spread in range(HALO,0,-2):
			canvas.draw_line(segments[i],segments[i+1],Color(GOLD,glow()/float(HALO)),STROKE+spread*2,true)
		canvas.draw_line(segments[i],segments[i+1],ink(),STROKE,true)
static func action(button: Button, available: bool) -> void:
	button.modulate.a=1.0 if available else 0.0
	button.mouse_filter=Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	button.focus_mode=Control.FOCUS_ALL if available else Control.FOCUS_NONE
	if not available:
		button.disabled=true
		if button.has_focus():button.release_focus()
