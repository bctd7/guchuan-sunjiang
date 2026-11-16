extends RefCounted
const Openings=preload("res://levels/level02/opening_rules.gd")
const Rules = preload("res://levels/level02/connection_rules.gd")
const Assembly = preload("res://levels/level02/assembly_policy.gd")
signal changed
var placed: Dictionary = {}
var starter_locks: Dictionary = {}
var selected := "plank_0a"
var observed: Dictionary = {}
var layouts: Dictionary = {0:"A",1:"B",2:"A"}
var joint := ""
var opening := ""
var layout := "A"
var completed := false
var failed := false
var _failure: Dictionary = {}
var checked := false
func starter_top(id: String="") -> bool:
	return str(starter_locks.get(selected if id.is_empty() else id,{}).get("phase",""))=="top"
func starter_middle_seated(id: String) -> bool:
	return starter_locks.has(id)
func remember_starter_middle(id: String) -> void:
	starter_locks[id]={"phase":"middle_seated","opening":opening,"layout":layout}
	changed.emit()
func begin_starter_top(id: String) -> void:
	if failed or not starter_locks.has(id):return
	starter_locks[id].phase="top"
	changed.emit()
func starter_completed(id: String) -> bool:
	return bool(placed.get(id,{}).get("starter_lock",false))
func next_id() -> String:
	for id in Rules.IDS:
		if not placed.has(id): return id
	return ""
func select(id: String) -> void:
	if failed: return
	selected=id
	joint=""
	opening=""
	var row := Rules.row_for(id)
	layout=str(layouts.get(row,"")) if row>=0 else "A"
	if starter_locks.has(id):
		joint="three_way_lap";opening=starter_locks[id].opening;layout=starter_locks[id].layout
	changed.emit()
func observe() -> void:
	if failed: return
	observed[selected]=true
	changed.emit()
func choose_joint(id: String) -> void:
	if failed: return
	if observed.has(selected):
		if joint!=id:
			opening="";starter_locks.erase(selected)
		joint=id
	changed.emit()
func choose_opening(id: String) -> void:
	if failed or starter_top() or not observed.has(selected) or not Openings.OPTIONS.has(id):return
	opening=id
	changed.emit()
func choose_layout(id: String) -> void:
	if failed: return
	if observed.has(selected) and Rules.row_for(selected)>0: layout=id
	changed.emit()
func can_attempt(id: String) -> Dictionary:
	if failed: return Rules.result(false,"failed","本关未通过，请重新开始或回到关卡目录。")
	if completed: return Rules.result(false,"completed","已完成，可重新搭建。")
	if id != selected: return Rules.result(false,"socket","位置不匹配：请拖动当前选择的木料。")
	if placed.has(id): return Rules.result(false,"duplicate","此处已放置。")
	if id != next_id(): return Rules.result(false,"order","先从底向舷铺板，再安装隔舱支撑。")
	if not observed.has(id): return Rules.result(false,"observe","先点放大观察，查看实际槽口与端缝。")
	if not Rules.JOINT_NAMES.has(joint): return Rules.result(false,"joint","先选择一种榫型，再挑选试装木料。")
	if opening.is_empty():return Rules.result(false,"opening","先转动观察槽口，再选开口位置匹配的木料。")
	var row := Rules.row_for(id)
	if row>=0 and layout.is_empty(): return Rules.result(false,"layout","先比较端缝位置，选择排布 A 或 B。")
	if row>=0 and id.ends_with("b") and layout!=str(layouts[row]): return Rules.result(false,"pair","同列两板须使用同一种排布。")
	return Rules.result(true,"ready","可以沿槽口推入木料。")
func installation_result(id: String) -> Dictionary:
	# Called only after a committed gesture. can_attempt stays neutral so that
	# choosing, inspecting and shallow testing wrong stock remain possible.
	var permitted=can_attempt(id)
	if not permitted.ok: return permitted
	var decision: Dictionary=Assembly.outcome(Assembly.CONTINUE,"顶件可以继续试装。") if starter_top(id) else Assembly.assess(id,joint,opening)
	return {"ok":true,"code":"assessed","mode":decision.mode,"message":decision.message}

func finish_installation(id: String) -> Dictionary:
	# The coordinator calls this only after the final seating tween. A pending
	# middle is not a completed three-part joint and must remain playable.
	if failed:return _failure.duplicate(true)
	if not placed.has(id):return Rules.result(false,"unfinished","这处接头还没有装完。")
	if Rules.row_for(id)==0 and str(placed[id].joint)!=Rules.expected(id):
		return fail_installation(id,"这组接头虽能嵌合，却不能形成船板的连续接边。请重新选择。","assembly_mismatch")
	return Rules.result(true,"seated","这处木料已装入。")

func fail_installation(id: String,message: String,code: String="assembly_failed") -> Dictionary:
	if failed:return _failure.duplicate(true)
	if completed:return Rules.result(false,"completed","本关已经完成。")
	failed=true
	completed=false
	checked=false
	_failure=Rules.result(false,code,message)
	_failure["piece_id"]=id
	changed.emit()
	return _failure.duplicate(true)

func failure_result() -> Dictionary:
	return _failure.duplicate(true)

func attempt(id: String) -> Dictionary:
	var decision:=installation_result(id)
	if not decision.ok:return decision
	if decision.mode==Assembly.BLOCKED:return Rules.result(false,"assembly_blocked",decision.message)
	if Rules.row_for(id)==0 and joint=="three_way_lap" and not starter_top(id):
		remember_starter_middle(id)
		return Rules.result(true,"middle_seated","中件已就位，继续装入顶件。")
	var row := Rules.row_for(id)
	if row>=0: layouts[row]=layout
	placed[id]={"joint":joint,"layout":layout,"opening":opening,"automatic":false}
	if starter_top(id):placed[id]["starter_lock"]=true
	starter_locks.erase(id)
	checked=false
	changed.emit()
	return Rules.result(true,"placed","木料已试装，整船装齐后再试浪。")
func prepare_repeat(representative: String) -> Dictionary:
	if failed or completed:return Rules.result(false,"locked","当前不能补齐木料。")
	var id: String=Rules.REPEATS.get(representative,"")
	if id.is_empty() or not placed.has(representative) or next_id()!=id:return Rules.result(false,"repeat_order","先完成本列代表件，再补齐同列船板。")
	var data: Dictionary=placed[representative]
	selected=id;joint=data.joint;opening=data.opening;layout=data.layout
	changed.emit()
	return Rules.result(true,"repeat_ready","正在检查同列另一块船板的装入路径。")

func place_repeat(representative: String) -> Dictionary:
	if failed or completed:return Rules.result(false,"locked","当前不能补齐木料。")
	var id: String=Rules.REPEATS.get(representative,"")
	if id.is_empty() or not placed.has(representative) or next_id()!=id:return Rules.result(false,"repeat_order","先完成本列代表件，再补齐同列船板。")
	var data: Dictionary=placed[representative].duplicate(true)
	data["automatic"]=true;data["demonstrated_by"]=representative
	placed[id]=data;starter_locks.erase(id);checked=false;changed.emit()
	return Rules.result(true,"repeated","同列另一块沿用本次榫型、开口和端缝，正在自动补齐。")
func connection_seated(id: String) -> bool:
	if not placed.has(id) or str(placed[id].joint)!=Rules.expected(id) or not Openings.matches(id,str(placed[id].opening)):return false
	var row:=Rules.row_for(id)
	if row>0:return connection_seated("plank_%d%s"%[row-1,"a" if id.ends_with("a") else "b"])
	if id=="three_upper":return connection_seated("three_middle")
	return true

func next_automatic(representative: String) -> String:
	if failed or completed or not placed.has(representative):return ""
	return next_id() if next_id() in Rules.AUTO_GROUPS.get(representative,[]) else ""

func prepare_automatic(representative: String) -> Dictionary:
	var id:=next_automatic(representative)
	if id.is_empty():return Rules.result(false,"group_order","先完成当前接头，再补齐本组。")
	var data: Dictionary=placed[representative]
	if data.joint!=Rules.expected(representative):return Rules.result(false,"group_joint","这组接头不能继续补齐。")
	selected=id;joint=data.joint;opening=data.opening
	layout=str(layouts.get(Rules.row_for(id),"A"))
	changed.emit()
	return Rules.result(true,"group_ready","正在补齐同组木料。")

func place_automatic(representative: String) -> Dictionary:
	var id:=next_automatic(representative)
	if id.is_empty() or selected!=id:return Rules.result(false,"group_order","当前不能补齐木料。")
	var source: Dictionary=placed[representative]
	if joint!=Rules.expected(representative) or joint!=source.joint or opening!=source.opening:return Rules.result(false,"group_choice","同组木料需要沿用本次选择。")
	placed[id]={"joint":joint,"opening":opening,"layout":layout,"automatic":true,"demonstrated_by":representative}
	checked=false;changed.emit()
	return Rules.result(true,"group_repeated","同组木料沿用本次选择，正在依次装入。")
func row_has_boards(row: int) -> bool:
	for side in ["a","b"]:
		var id: String="plank_%d%s"%[row,side]
		if not connection_seated(id):return false
	return true
func aligned_rows() -> Array[int]:
	var rows: Array[int]=[]
	for row in [1,2]:
		# Diagnose actual plank-end seams only, not imaginary boards replaced by another type.
		if row_has_boards(row-1) and row_has_boards(row) and Rules.aligned(str(layouts[row-1]),str(layouts[row])):rows.append(row)
	return rows
func bad_row() -> int:
	var rows:=aligned_rows()
	return rows[0] if not rows.is_empty() else -1
func leaking_rows() -> Array[int]:
	var rows: Array[int]=[]
	for upper in aligned_rows():
		for row in [upper-1,upper]:
			if not rows.has(row):rows.append(row)
	return rows
func mismatched_joints() -> Array[String]:
	var issues: Array[String]=[]
	for id in Rules.IDS:
		if placed.has(id) and str(placed[id].joint)!=Rules.expected(id):issues.append(id)
	return issues
func connection_issues() -> Array[String]:
	var issues:=mismatched_joints()
	for id in mismatched_openings():
		if not issues.has(id):issues.append(id)
	return issues
func mismatched_openings() -> Array[String]:
	var issues: Array[String]=[]
	for id in Rules.IDS:
		if placed.has(id) and str(placed[id].joint)==Rules.expected(id) and not Openings.matches(id,str(placed[id].get("opening",""))):issues.append(id)
	return issues
func structural_issues() -> Array[String]:
	var issues: Array[String]=[]
	for id in connection_issues():
		if Rules.row_for(id)<0:issues.append(id)
	return issues
func hull_issues() -> Array[String]:
	var issues: Array[String]=[]
	for id in connection_issues():
		if Rules.row_for(id)>=0:issues.append(id)
	return issues
func validate() -> Dictionary:
	if failed: return _failure.duplicate(true)
	if placed.size()!=Rules.IDS.size(): return Rules.result(false,"incomplete","尚有构件未安装。请按顺序完成 10 件。")
	checked=true
	var wrong_types:=mismatched_joints()
	var wrong_openings:=mismatched_openings()
	if bad_row()>=0 or not wrong_types.is_empty() or not wrong_openings.is_empty():
		failed=true
		completed=false
		var reasons: PackedStringArray=[]
		if not wrong_types.is_empty():reasons.append("榫型不匹配 %d 处"%wrong_types.size())
		if not wrong_openings.is_empty():reasons.append("槽口位置不合 %d 处"%wrong_openings.size())
		if bad_row()>=0:reasons.append("上下排端缝对齐")
		var wet: bool=bad_row()>=0 or not hull_issues().is_empty()
		var loose: bool=not structural_issues().is_empty()
		var consequence: String="船板漏水，内部支撑松动" if wet and loose else ("船板接缝漏水" if wet else "内部支撑松动，搭扣未扣牢")
		var code: String="mixed" if wet and loose else ("structure" if loose else ("opening" if not wrong_openings.is_empty() else "leak"))
		_failure=Rules.result(false,code,"；".join(reasons)+"。试浪发现"+consequence+"，请重新开始或回到关卡目录。")
		changed.emit()
		return _failure.duplicate(true)
	completed=true
	changed.emit()
	return Rules.result(true,"complete","合壳完成！船板端缝错开，支撑与隔舱都已就位。")
func undo() -> void:
	if failed: return
	if starter_locks.has(selected):
		var saved: Dictionary=starter_locks[selected]
		starter_locks.erase(selected)
		joint="three_way_lap";opening=saved.opening;layout=saved.layout
		changed.emit();return
	if placed.is_empty(): return
	var id: String = ""
	for member in Rules.IDS:
		if placed.has(member):id=member
	var representative: String=str(placed[id].get("demonstrated_by",id))
	for member in placed.keys():
		if member==representative or placed[member].get("demonstrated_by","")==representative:placed.erase(member)
	id=representative
	completed=false
	checked=false
	select(id)
func reset() -> void:
	failed=false
	_failure.clear()
	placed.clear()
	starter_locks.clear()
	observed.clear()
	layouts={0:"A",1:"B",2:"A"}
	completed=false
	checked=false
	select("plank_0a")

# Read-only presentation groups never replace the ten accepted piece records.
func group_target(index: int) -> String:
	if index<0 or index>=Rules.GROUPS.size():return ""
	var ids: Array=Rules.GROUPS[index]
	if next_id() in ids:return next_id()
	for id in ids:
		if not placed.has(id):return ""
	return str(ids.back())
func next_in_group() -> String:
	var next:=next_id()
	return next if placed.has(selected) and next in Rules.MANUAL_IDS and Rules.group_for(selected)==Rules.group_for(next) else ""
