extends RefCounted
const Rules = preload("res://levels/level02/connection_rules.gd")
signal changed
var placed: Dictionary = {}
var selected := "plank_0a"
var observed: Dictionary = {}
var layouts: Dictionary = {0:"A"}
var joint := ""
var layout := ""
var completed := false
var checked := false
func next_id() -> String:
	for id in Rules.IDS:
		if not placed.has(id): return id
	return ""
func select(id: String) -> void:
	selected=id
	joint=""
	var row := Rules.row_for(id)
	layout=str(layouts.get(row,"")) if row>=0 else "A"
	changed.emit()
func observe() -> void:
	observed[selected]=true
	changed.emit()
func choose_joint(id: String) -> void:
	if observed.has(selected): joint=id
	changed.emit()
func choose_layout(id: String) -> void:
	if observed.has(selected) and Rules.row_for(selected)>0: layout=id
	changed.emit()
func attempt(id: String) -> Dictionary:
	if completed: return Rules.result(false,"completed","已完成，可重新搭建。")
	if id != selected: return Rules.result(false,"socket","位置不匹配：请点所选构件的圆点。")
	if placed.has(id): return Rules.result(false,"duplicate","此处已放置。")
	if id != next_id(): return Rules.result(false,"order","先从底向舷铺板，再安装隔舱支撑。")
	if not observed.has(id): return Rules.result(false,"observe","先点放大观察，查看实际槽口与端缝。")
	if joint != Rules.expected(id): return Rules.result(false,"joint","榫型不匹配：对照真实槽口，再选候选。")
	var row := Rules.row_for(id)
	if row>=0 and layout.is_empty(): return Rules.result(false,"layout","先比较端缝位置，选择排布 A 或 B。")
	if row>=0 and id.ends_with("b") and layout!=str(layouts[row]): return Rules.result(false,"pair","同列两板须使用同一种排布。")
	if row>=0: layouts[row]=layout
	placed[id]={"joint":joint,"layout":layout}
	checked=false
	changed.emit()
	return Rules.result(true,"placed","已合入。下一件仍需先观察槽口。")
func bad_row() -> int:
	for r in [1,2]:
		if layouts.has(r) and layouts.has(r-1) and placed.has("plank_%da" % r) and Rules.aligned(str(layouts[r-1]),str(layouts[r])): return r
	return -1
func validate() -> Dictionary:
	checked=true
	changed.emit()
	if placed.size()!=Rules.IDS.size(): return Rules.result(false,"incomplete","尚有构件未安装。请按顺序完成 10 件。")
	if bad_row()>=0: return Rules.result(false,"leak","端缝对齐形成连续薄弱线：红缝处有漏水风险。点修正端缝，重排该列。")
	completed=true
	changed.emit()
	return Rules.result(true,"complete","合壳完成！已形成局部船壳与隔舱。仍需填缝、密封及实体试水。")
func undo() -> void:
	if placed.is_empty(): return
	var id: String = Rules.IDS[placed.size()-1]
	placed.erase(id)
	completed=false
	checked=false
	select(id)
func repair() -> void:
	var row := bad_row()
	if row<0: return
	var start := row*2
	for i in range(start,Rules.IDS.size()): placed.erase(Rules.IDS[i])
	for r in [row,2]:
		if r>=row: layouts.erase(r)
	checked=false
	completed=false
	select(Rules.IDS[start])
func reset() -> void:
	placed.clear()
	observed.clear()
	layouts={0:"A"}
	completed=false
	checked=false
	select("plank_0a")
