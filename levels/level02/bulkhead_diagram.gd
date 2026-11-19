extends Control
## Full-frame story illustration of wooden watertight compartments.
const ART = preload("res://assets/images/level02/watertight_bulkhead_story.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(_fit_image)
	_fit_image()

func _fit_image() -> void:
	custom_minimum_size.y = size.x * float(ART.get_height()) / float(ART.get_width())
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	var image_size := Vector2(ART.get_size())
	var draw_size := image_size * minf(size.x / image_size.x, size.y / image_size.y)
	draw_texture_rect(ART, Rect2((size - draw_size) * .5, draw_size), false)
