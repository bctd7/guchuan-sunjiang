extends RefCounted
## Optional audio: scenes and tests remain playable without the autoload/resources.
static func play(owner: Node) -> void:
	var audio=owner.get_node_or_null("/root/GameAudio")
	if audio!=null:audio.seat(owner)
static func cancel(owner: Node) -> void:
	var audio=owner.get_node_or_null("/root/GameAudio")
	if audio!=null:audio.cancel(owner)

static func bind_results(owner: Node, success: CanvasItem, failure: CanvasItem = null) -> void:
	var audio=owner.get_node_or_null("/root/GameAudio")
	if audio==null:return
	audio.watch_result(success,"success")
	if failure!=null:audio.watch_result(failure,"failure")
