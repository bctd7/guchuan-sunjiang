extends CanvasLayer
## Chapter-two seaside plate; grading matches chapter one's muted timber palette.
const IMAGE=preload("res://levels/level02/assets/seaside_shipyard.png")
const TREATMENT=preload("res://levels/level02/assets/seaside_background.gdshader")
func _ready() -> void:
	layer=-10
	var image:=TextureRect.new()
	image.texture=IMAGE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var treatment:=ShaderMaterial.new()
	treatment.shader=TREATMENT
	image.material=treatment
	add_child(image)
