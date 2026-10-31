extends Control
## Full-frame story art; not an archaeological reconstruction or assembly geometry.
const ART = preload("res://levels/level01/assets/seven_stars_story.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_fit_image)
	_fit_image()

func _fit_image() -> void:
	# The whole illustration stays visible, including all seven coins and the mirror.
	custom_minimum_size.y = size.x * float(ART.get_height()) / float(ART.get_width())
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	var image_size := Vector2(ART.get_size())
	var draw_size := image_size * minf(size.x / image_size.x, size.y / image_size.y)
	draw_texture_rect(ART, Rect2((size - draw_size) * .5, draw_size), false)
