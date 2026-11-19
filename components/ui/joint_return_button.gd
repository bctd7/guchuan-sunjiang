extends RefCounted
## Shared return control for individual joint science presentations.
static func create(action: Callable) -> Button:
	var button := Button.new()
	button.text = "返回"
	button.custom_minimum_size = Vector2(144,64)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size",28)
	button.pressed.connect(action)
	return button
