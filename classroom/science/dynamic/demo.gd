extends Node
const Presenter = preload("res://classroom/science/dynamic/presenter.gd")
var science: CanvasLayer
func _ready() -> void:
	science = Presenter.new()
	add_child(science)
	var landing := CanvasLayer.new()
	add_child(landing)
	var entry := Button.new()
	entry.text = "打开燕尾榫二维受力演示"
	entry.position = Vector2(24,24)
	entry.pressed.connect(func(): science.open_for_joint())
	landing.add_child(entry)
	science.open_for_joint()
