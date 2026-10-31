extends RefCounted
## Pure rules. Scene geometry never grants an installation.
const ORDER = ["zrail", "leg", "mast", "apron", "top", "lbrace", "rudder", "blade"]
const STAGES = [["zrail","leg","mast"],["apron","top"],["lbrace","rudder","blade"]]
const TITLES = ["桅座框 · 三向锁合", "桅顶夹座 · 承托帆桁", "船尾舵架 · 固定与转动"]
const SPECS = {
	"zrail":{"label":"桅座抹头", "joint":"zong_corner", "stage":0, "deps":[], "hint":"大边已固定。抹头沿 −Z 合上 45° 肩；下面的长短榫槽暂时敞开。"},
	"leg":{"label":"桅座角腿", "joint":"zong_corner", "stage":0, "deps":["zrail"], "hint":"角腿从下向上装；两个垂直长短榫分别进入深浅槽，三向斜肩收合。"},
	"mast":{"label":"桅杆方脚", "joint":"square_foot", "stage":0, "deps":["leg"], "hint":"三向框锁好后，桅杆方脚从上落入桅座方槽。"},
	"apron":{"label":"帆桁牙条", "joint":"clamp_head", "stage":1, "deps":["mast"], "hint":"桅顶是叉腿本体。先把牙条向下夹入叉口；顶端双榫仍然露出。"},
	"top":{"label":"帆桁承托板", "joint":"clamp_head", "stage":1, "deps":["apron"], "hint":"承托板的底部双槽套住叉腿顶端双榫；板上帆桁随板一起固定。"},
	"lbrace":{"label":"舵架固定横撑", "joint":"l_through", "stage":2, "deps":["top"], "hint":"选择阶梯 L 型穿榫。前端小榫穿出，后段大榫留在较深槽内。"},
	"rudder":{"label":"无叶圆舵轴", "joint":"round_axle", "stage":2, "deps":["lbrace"], "hint":"无叶直圆轴从上穿过轴承；顶端止推肩留在孔上。轴径 0.34 / 孔径 0.40。"},
	"blade":{"label":"侧装舵叶", "joint":"sleeve_pin", "stage":2, "deps":["rudder"], "hint":"从船外侧把舵叶半夹套推向轴脚，再合另一半并固定销。夹套/销是可拆机械连接，不是本关三种榫卯。"}
}
const NAMES = {"zong_corner":"粽角榫", "clamp_head":"夹头榫", "l_through":"L 型穿榫", "through_tenon":"普通直透榫", "square_foot":"方脚直榫", "round_axle":"圆轴", "blind_tenon":"短直榫", "sleeve_pin":"侧装夹套 / 销"}
static func candidates(id: String) -> Array:
	if id == "blade": return ["sleeve_pin"]
	if id == "lbrace": return ["through_tenon", "l_through", "blind_tenon"]
	if id in ["mast","rudder"]: return ["square_foot", "round_axle", "l_through"]
	return ["zong_corner", "clamp_head", "l_through"]
static func evaluate(id: String, socket: String, joint: String, placed: Array, stage: int) -> Dictionary:
	if not SPECS.has(id): return _result(false,"unknown","没有选中木件。")
	if placed.has(id): return _result(false,"duplicate","这件已锁合，不会重复安装。可撤回后重试。")
	if socket != id: return _result(false,"wrong_socket","这是另一处槽口，木件没有装入。")
	if int(SPECS[id].stage) != stage: return _result(false,"wrong_stage","先完成当前工作台。")
	for dependency in SPECS[id].deps:
		if not placed.has(dependency): return _result(false,"dependency","先完成前面的木件；装配顺序不能倒置。")
	if joint.is_empty(): return _result(false,"unselected","先观察三件候选的真实榫头，再选一种。")
	if joint != SPECS[id].joint: return _result(false,"wrong_joint","榫头形状与这处槽口不合，已拒绝装入。换一种再试。")
	return _result(true,"placed",str(SPECS[id].label)+"已按正确方向装好。")
static func _result(ok: bool, code: String, message: String) -> Dictionary:
	return {"ok":ok,"code":code,"message":message}
