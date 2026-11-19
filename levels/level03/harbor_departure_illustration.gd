extends TextureRect

func _init() -> void:
	texture = preload("res://assets/images/level03/harbor_departure_story.png")
	expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
