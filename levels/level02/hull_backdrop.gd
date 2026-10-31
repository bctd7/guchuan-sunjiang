extends CanvasLayer
## Chapter-two-only muted beach illustration. No global environment or classroom edits.
const IMAGE=preload("res://levels/level02/assets/tidal_shipyard.svg")
func _ready() -> void:
	layer=-10
	var image:=TextureRect.new()
	image.texture=IMAGE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(image)
