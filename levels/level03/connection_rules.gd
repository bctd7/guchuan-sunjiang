extends RefCounted
## Pure rules. Scene geometry never grants an installation.
const ORDER = ["apron", "top", "mast", "zrail", "leg", "lbrace", "rudder", "blade"]
const STAGES = [["apron","top","mast"],["zrail","leg"],["lbrace","rudder","blade"]]
const TITLES = ["龙骨桅座 · 夹头榫", "桅顶帆桁 · 粽角榫", "船尾舵架 · 穿榫"]
const SPECS = {
	"apron":{"label":"桅座横牙条", "joint":"clamp_head", "stage":0, "deps":[], "hint":"龙骨上的叉口向上敞开。选一根能夹在两片叉口中间的牙条。"},
	"top":{"label":"桅座承托板", "joint":"clamp_head", "stage":0, "deps":["apron"], "hint":"板底的两个槽要套住叉口两侧，中央的方槽留给桅脚。"},
	"mast":{"label":"桅杆方脚", "observation_label":"桅杆安装", "joint":"square_foot", "stage":0, "deps":["top"], "hint":"比较三件木料的底端，再看看承托板上的槽口。"},
	"zrail":{"label":"帆桁横木", "joint":"zong_corner", "stage":1, "deps":["mast"], "hint":"把帆桁的斜肩与桅顶横档合上，再从另一面锁住接头。"},
	"leg":{"label":"帆桁角撑", "joint":"zong_corner", "stage":1, "deps":["zrail"], "hint":"帆的重量向下压。看看哪一面能托住帆桁，再把角撑推入。"},
	"lbrace":{"label":"舵架固定横撑", "joint":"l_through", "stage":2, "deps":["leg"], "hint":"较小的榫尖穿出船尾柱，较宽的榫肩留在槽里。"},
	"rudder":{"label":"圆舵轴", "joint":"round_axle", "stage":2, "deps":["lbrace"], "hint":"先调舵轴的角度，再让它顺着圆孔穿过去。"},
	"blade":{"label":"侧装舵叶", "joint":"sleeve_pin", "stage":2, "deps":["rudder"], "hint":"从侧面合上两半夹套，用木销把舵叶固定在舵轴上。"}
}
const SETTINGS = {
	"mast": {"question":"木件应如何与槽口配合，桅杆才能站稳？", "options":["搭在槽口边沿", "对准槽口中央"], "correct":1, "retry":"桅脚搭在槽沿，桅杆向一边倒了。把方脚移到方槽中央再落下。"},
	"leg": {"question":"帆的重量向下压。角撑放在哪一侧？", "options":["从上面压住", "从下面托住"], "correct":1, "retry":"角撑放在上侧，帆桁下方悬空。换一侧试试。"},
	"rudder": {"question":"船尾的轴孔竖直。怎样放入舵轴？", "options":["竖直对孔 · 0°", "斜放 · 20°"], "correct":0, "retry":"舵轴斜着顶住孔壁，无法转舵。把轴扶直再试。"}
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
	if joint.is_empty(): return _result(false,"unselected","先观察候选木件，再选一种。")
	if joint != SPECS[id].joint: return _result(false,"wrong_joint","榫头形状与这处槽口不合，已拒绝装入。换一种再试。")
	return _result(true,"placed",str(SPECS[id].label)+"已按正确方向装好。")
static func _result(ok: bool, code: String, message: String) -> Dictionary:
	return {"ok":ok,"code":code,"message":message}
