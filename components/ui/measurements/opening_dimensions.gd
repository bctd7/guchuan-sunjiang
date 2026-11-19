extends RefCounted
## Presentation reads measurements emitted by the mesh builders, never answers.
static func read(node: Node,key: String="mating_dimensions") -> Dictionary:
	return preload("res://models/ship/hull/ship_geometry.gd").dimensions(node,key)

static func number(value: float) -> String:
	return String.num(value*100.0,1).trim_suffix(".0")

static func caption(d: Dictionary) -> String:
	if d.is_empty():return ""
	var width:=number(d.width)
	# Show the dimensions that distinguish the real candidates. Common cuts
	# still exist in the geometry, but do not help the player choose a piece.
	match str(d.kind):
		"groove":
			return "槽口居中" if is_zero_approx(d.offset) else ("槽口靠上" if d.offset>0 else "槽口靠下")
		"notch":
			return "开口宽%s格\n挖入%s格"%[width,number(d.depth)]
		"upper_channel","double_notch":
			return "开口宽%s格\n%s"%[width,position(d.offset)]
	return ""

static func position(offset: float) -> String:
	return "开在中间" if is_zero_approx(offset) else "开在一侧"

static func candidate_lines(id: String,d: Dictionary) -> String:
	if d.is_empty():return id
	match str(d.kind):
		"groove":return "%s · %s格\n槽口高度"%[id,number(d.stock*.5+d.offset)]
		"notch":return "%s · 宽%s\n深%s格"%[id,number(d.width),number(d.depth)]
		"upper_channel","double_notch":return "%s · 宽%s\n%s"%[id,number(d.width),"缺口居中" if is_zero_approx(d.offset) else "缺口偏旁"]
	return id
