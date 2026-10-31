extends RefCounted
const IDS := ["plank_0a","plank_0b","plank_1a","plank_1b","plank_2a","plank_2b","cross_upper","three_middle","three_upper","bulkhead"]
const LABELS := ["底列 · 尾板","底列 · 首板","中列 · 尾板","中列 · 首板","舷列 · 尾板","舷列 · 首板","隔舱十字上框","三向中撑","三向顶撑","隔舱板"]
const JOINT_NAMES := {"tongue_groove":"企口榫","cross_lap":"搭扣榫","three_way_lap":"扣合榫"}
static func label_for(id: String) -> String:
	return LABELS[IDS.find(id)] if IDS.has(id) else id
static func expected(id: String) -> String:
	if id.begins_with("plank"): return "tongue_groove"
	if id == "cross_upper" or id == "bulkhead": return "cross_lap"
	return "three_way_lap"
static func row_for(id: String) -> int:
	return int(id.split("_")[1].left(1)) if id.begins_with("plank") else -1
static func seam(layout: String) -> float:
	return -1.4 if layout == "A" else 1.4
static func aligned(a: String,b: String) -> bool:
	return absf(seam(a)-seam(b)) < 0.8
static func result(ok: bool,code: String,message: String) -> Dictionary:
	return {"ok":ok,"code":code,"message":message}
