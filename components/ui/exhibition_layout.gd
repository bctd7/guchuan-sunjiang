extends RefCounted
## Retain the authored workshop coordinates inside the 1920×1080 design canvas.
## Uniform scaling is shared by chrome and 3D safe-area projection.
const WORKSHOP_SIZE := Vector2(1440,900)
static func factor(dimensions: Vector2) -> float:
	return minf(dimensions.x/WORKSHOP_SIZE.x,dimensions.y/WORKSHOP_SIZE.y)
static func origin(dimensions: Vector2) -> Vector2:
	return (dimensions-WORKSHOP_SIZE*factor(dimensions))*.5
static func fit(control: Control,dimensions: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.size=WORKSHOP_SIZE
	control.scale=Vector2.ONE*factor(dimensions)
	control.position=origin(dimensions)
static func project_rect(rect: Rect2,dimensions: Vector2) -> Rect2:
	return Rect2(origin(dimensions)+rect.position*factor(dimensions),rect.size*factor(dimensions))
