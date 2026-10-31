extends "res://tests/zong_input_tests.gd"
func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.zong-reference-rebuild-20261023/"+label+".png")
