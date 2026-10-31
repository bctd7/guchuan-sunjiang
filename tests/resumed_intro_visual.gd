extends "res://tests/resumed_level01_visual.gd"
func _initialize() -> void:
	previews_only=true
	call_deferred("run")
