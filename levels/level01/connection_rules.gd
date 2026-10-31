extends RefCounted
## Pure level-one connection rules. No scene, input, rendering or animation state.
## These joints are a teaching layout, not a claim about historical ship construction.

const IDS: Array[String] = ["keel", "rib_l1", "rib_r1", "rib_l2", "rib_r2", "rib_l3", "rib_r3", "bow", "stern", "beam1", "beam3"]
const RIB_IDS: Array[String] = ["rib_l1", "rib_r1", "rib_l2", "rib_r2", "rib_l3", "rib_r3"]
const BRACE_IDS: Array[String] = ["bow", "stern", "beam1", "beam3"]
## Ten installed members are taught through three representative demonstrations.
const BUILD_IDS: Array[String] = ["rib_l1", "rib_r1", "rib_l2", "rib_r2", "rib_l3", "rib_r3", "bow", "stern", "beam1", "beam3"]
const REPRESENTATIVE_IDS: Array[String] = ["rib_l1", "bow", "beam1"]
const JOINT_TYPES: Array[String] = ["blind_tenon", "dovetail", "through_tenon"]
const LENGTHS: Array[String] = ["short", "correct", "long"]
const AUTO_GROUPS := {
	"rib_l1": ["rib_r1", "rib_l2", "rib_r2", "rib_l3", "rib_r3"],
	"bow": ["stern"],
	"beam1": ["beam3"]
}
const AUTO_BATCHES := {
	"rib_l1": [["rib_r1"], ["rib_l2"], ["rib_r2"], ["rib_l3"], ["rib_r3"]],
	"bow": [["stern"]],
	"beam1": [["beam3"]]
}
const SPECS := {
	"keel": {"id":"keel", "label":"龙骨长料", "name":"龙骨长料", "joint":"base", "stage":"keel", "side":"center"},
	"rib_l1": {"id":"rib_l1", "label":"前段左船肋", "name":"前段左船肋", "joint":"blind_tenon", "stage":"ribs", "side":"left", "pair":"rib_r1"},
	"rib_r1": {"id":"rib_r1", "label":"前段右船肋", "name":"前段右船肋", "joint":"blind_tenon", "stage":"ribs", "side":"right", "pair":"rib_l1"},
	"rib_l2": {"id":"rib_l2", "label":"中段左船肋", "name":"中段左船肋", "joint":"blind_tenon", "stage":"ribs", "side":"left", "pair":"rib_r2"},
	"rib_r2": {"id":"rib_r2", "label":"中段右船肋", "name":"中段右船肋", "joint":"blind_tenon", "stage":"ribs", "side":"right", "pair":"rib_l2"},
	"rib_l3": {"id":"rib_l3", "label":"后段左船肋", "name":"后段左船肋", "joint":"blind_tenon", "stage":"ribs", "side":"left", "pair":"rib_r3"},
	"rib_r3": {"id":"rib_r3", "label":"后段右船肋", "name":"后段右船肋", "joint":"blind_tenon", "stage":"ribs", "side":"right", "pair":"rib_l3"},
	"bow": {"id":"bow", "label":"前龙骨延长段", "name":"前龙骨延长段", "joint":"dovetail", "stage":"braces", "side":"center"},
	"stern": {"id":"stern", "label":"后龙骨延长段", "name":"后龙骨延长段", "joint":"dovetail", "stage":"braces", "side":"center"},
	"beam1": {"id":"beam1", "label":"前段横梁", "name":"前段横梁", "joint":"through_tenon", "stage":"braces", "side":"center"},
	"beam3": {"id":"beam3", "label":"后段横梁", "name":"后段横梁", "joint":"through_tenon", "stage":"braces", "side":"center"}
}
const JOINT_LABELS := {"base":"龙骨基座", "blind_tenon":"半榫", "dovetail":"燕尾榫", "through_tenon":"透榫"}

static func all_ids() -> Array[String]:
	return IDS.duplicate()

static func initial_connections() -> Dictionary:
	# A fresh record per state instance: never share mutable foundation data.
	return {"keel":{"socket":"keel", "joint":"base", "length":"correct", "fixed":true}}

static func piece_spec(id: String) -> Dictionary:
	return SPECS.get(id, {}).duplicate(true)

static func expected_joint(id: String) -> String:
	return str(SPECS.get(id, {}).get("joint", ""))

static func stage_for(id: String) -> String:
	return str(SPECS.get(id, {}).get("stage", ""))

static func result(ok: bool, code: String, message: String) -> Dictionary:
	return {"ok":ok, "code":code, "message":message}

static func ribs_correct(placed: Dictionary) -> bool:
	for id in RIB_IDS:
		if not connection_correct(id, placed):
			return false
	return true

static func ribs_attached(placed: Dictionary) -> bool:
	for id in RIB_IDS:
		if not connection_attached(id, placed):
			return false
	return true

static func connection_attached(id: String, placed: Dictionary) -> bool:
	if not SPECS.has(id) or not placed.has(id) or not placed[id] is Dictionary:
		return false
	var data: Dictionary = placed[id]
	if str(data.get("socket", "")) != id:
		return false
	if id == "keel":
		return str(data.get("joint", "")) == "base" and str(data.get("length", "")) == "correct" and data.get("fixed", false) == true
	return str(data.get("joint", "")) in JOINT_TYPES and str(data.get("length", "")) in LENGTHS

static func connection_correct(id: String, placed: Dictionary) -> bool:
	return connection_attached(id, placed) and str(placed[id].get("joint", "")) == expected_joint(id) and str(placed[id].get("length", "")) == "correct"

static func evaluate(piece_id: String, socket_id: String, joint_type: String, length: String, placed: Dictionary, completed: bool = false) -> Dictionary:
	if not SPECS.has(piece_id):
		return result(false, "unknown_piece", "请先选择一件木料。")
	if not SPECS.has(socket_id):
		return result(false, "unknown_socket", "这里没有连接槽，请点选标记的槽位。")
	if piece_id == "keel":
		return result(false, "fixed_foundation", "龙骨已固定，无需安装。请从船肋开始。")
	if completed:
		return result(false, "complete", "骨架已经验收通过。可以撤回一步或重新挑战。")
	if placed.has(piece_id):
		return result(false, "already_placed", "这件木料已经装好，请先撤回再调整。")
	if placed.has(socket_id):
		return result(false, "occupied", "这个槽位已有木料，不能重复装入。")
	if piece_id != socket_id:
		return result(false, "wrong_socket", "位置不匹配，拼不上！请找与木料名称相同的槽位。")
	var expected := expected_joint(piece_id)
	var chosen := expected if joint_type.is_empty() else joint_type
	if not chosen in JOINT_TYPES:
		return result(false, "unsupported_joint", "请选择有效的榫型：半榫、燕尾榫或透榫。")
	if not length in LENGTHS:
		return result(false, "unsupported_length", "长度选项无效，请选择偏短、合适或偏长。")
	if not placed.has("keel"):
		return result(false, "needs_keel", "固定龙骨缺失，请点“重新搭建”恢复基座。")
	if not connection_correct("keel", placed):
		return result(false, "invalid_connection", "固定龙骨损坏，请重新搭建以恢复基础。")
	if stage_for(piece_id) == "braces" and not ribs_attached(placed):
		return result(false, "needs_ribs", "先装好三组左右对称的船肋，再加固连接。")
	return result(true, "placed", "构件已试装，可以继续搭建；完成后检查结构是否稳固。")

static func validate(placed: Dictionary) -> Dictionary:
	if not placed.has("keel"):
		return result(false, "needs_keel", "固定龙骨缺失，请点“重新搭建”恢复基座。")
	if not connection_correct("keel", placed):
		return result(false, "invalid_connection", "固定龙骨损坏，请重新搭建以恢复基础。")
	# Every known type and length can be tried. Gather choices now, but
	# diagnose their fit only after the entire skeleton is attached.
	var unstable_pieces: Array[String] = []
	var unstable_groups: Array[String] = []
	var group_labels: Array[String] = []
	var unstable_reasons: Dictionary = {}
	var reasons: Array[String] = []
	for id in BUILD_IDS:
		if not placed.has(id): continue
		if not connection_attached(id, placed):
			return result(false, "invalid_connection", "存在无效的接合记录，请撤回对应组并重新安装。")
		if connection_correct(id, placed): continue
		unstable_pieces.append(id)
		var piece_reasons: Array[String] = []
		if str(placed[id].get("joint", "")) != expected_joint(id):
			piece_reasons.append("wrong_joint")
		if str(placed[id].get("length", "")) != "correct":
			piece_reasons.append("wrong_length")
		unstable_reasons[id] = piece_reasons
		for reason in piece_reasons:
			if not reason in reasons: reasons.append(reason)
		for representative in REPRESENTATIVE_IDS:
			if id == representative or id in AUTO_GROUPS[representative]:
				if not representative in unstable_groups:
					unstable_groups.append(representative)
					group_labels.append({"rib_l1":"船肋组", "bow":"前后连接组", "beam1":"横梁组"}[representative])
	if not ribs_attached(placed):
		return result(false, "asymmetric", "船肋还不完整。三组左右船肋全部咬合，骨架才会稳定。")
	for id in IDS:
		if not placed.has(id):
			return result(false, "incomplete", "还需要%s。完成全部连接后再验收。" % SPECS[id].label)
		if not connection_attached(id, placed):
			return result(false, "invalid_connection", "连接记录无效，请重新检查。")
	if placed.size() != IDS.size():
		return result(false, "invalid_connection", "存在不属于本关的连接，请重新检查。")
	if not unstable_pieces.is_empty():
		var code := "unstable_fit" if "wrong_joint" in reasons else "unstable_length"
		var problem := "榫型和长度不合" if "wrong_joint" in reasons and "wrong_length" in reasons else ("榫型不合" if "wrong_joint" in reasons else "长度不合")
		var outcome := result(false, code, "%s因%s出现松动。本关未通过，请重新开始。" % ["、".join(group_labels), problem])
		outcome["unstable_pieces"] = unstable_pieces
		outcome["unstable_groups"] = unstable_groups
		outcome["unstable_reasons"] = unstable_reasons
		outcome["reasons"] = reasons
		return outcome
	return result(true, "complete", "龙骨立架成功！左右对称，连接牢靠，可以准备铺船板了。")
