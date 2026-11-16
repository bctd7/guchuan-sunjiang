extends HBoxContainer
const Lighting=preload("res://levels/level02/timber_lighting.gd")
## Three real ship-material candidate previews; assembled from current G solids.
const Appearance=preload("res://levels/level02/wood_appearance.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Boat=preload("res://models/ship/hull/boat_joints.gd")
signal chosen(id: String)
signal inspect_requested(id: String)
var inspect_buttons: Dictionary={}
const Workspace=preload("res://levels/shared/inspection_workspace.gd")
const Preview=preload("res://levels/shared/rotatable_preview.gd")
var previews: Dictionary={}
const DETAILS={"tongue_groove":"舌槽沿板边相接","cross_lap":"两件缺口相向落合","three_way_lap":"中件侧推，顶件锁合"}
const TYPES=["tongue_groove","cross_lap","three_way_lap"]
var buttons: Dictionary={}
var captions: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",8)
	custom_minimum_size.y=174
	for id in TYPES:
		var button:=Button.new();button.toggle_mode=true;button.custom_minimum_size=Vector2(100,174);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(button);buttons[id]=button
		Workspace.neutral_selection(button)
		button.pressed.connect(func():chosen.emit(id))
		var column:=VBoxContainer.new();column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=3;column.offset_right=-3;column.offset_top=3;column.offset_bottom=-3;column.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(column)
		var preview:=Preview.new();preview.custom_minimum_size=Vector2(100,120);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(preview);previews[id]=preview
		preview.set_lighting_profile(Lighting)
		preview.activated.connect(func():
			if not button.disabled:chosen.emit(id))
		var root:=Node3D.new()
		var a=G.material(Color("b89569"))
		var b=G.material(Color("dcc29b"))
		var base:=Node3D.new();base.name="LowerStock";root.add_child(base)
		var moving=Node3D.new();moving.name="UpperStock"
		root.add_child(moving)
		var offset=Vector3(0,.55,0)
		if id=="cross_lap":
			Boat.cross_member(base,false,a,"C",1.86)
			Boat.cross_member(moving,true,b,"C",1.86)
		elif id=="tongue_groove":
			base.set_meta("wood_axis",Vector3.RIGHT);moving.set_meta("wood_axis",Vector3.RIGHT)
			G.plank(base,-1,1,0,a)
			G.plank(moving,-1,1,1,b)
			offset=Vector3(0,0,.35)
		else:
			Boat.three_member(base,0,a,"C")
			var mid=Node3D.new();mid.name="MiddleStock"
			root.add_child(mid)
			Boat.three_member(mid,1,b,"C")
			mid.position.x=1.3
			Boat.three_member(moving,2,G.material(Color("9e805d")),"A")
			offset=Vector3(0,.65,0)
		moving.position=offset
		if id=="cross_lap":
			root.set_meta("joint_demo",{"parts":[{"path":"LowerStock","caption":"下件槽口","axis":Vector3.RIGHT,"normal":Vector3.UP},{"path":"UpperStock","caption":"上件槽口","axis":Vector3(0,0,1),"normal":Vector3.DOWN}],"order":["UpperStock"],"description":"两件各开半深凹口，交叉搭接。","closed_text":"两件木料在同一处交搭，半深凹口相互容纳。"})
		elif id=="tongue_groove":
			root.set_meta("joint_demo",{"parts":[{"path":"LowerStock","caption":"槽边","axis":Vector3.RIGHT,"normal":Vector3(0,0,1)},{"path":"UpperStock","caption":"凸舌","axis":Vector3.RIGHT,"normal":Vector3(0,0,-1)}],"order":["UpperStock"],"closed_positions":{"UpperStock":Vector3.ZERO},"description":"两块板保持平行，沿板宽方向靠拢，凸舌进入长槽。","closed_text":"凸舌进入上下槽壁之间，板边肩面相接。"})
		elif id=="three_way_lap":
			root.set_meta("joint_demo",{"parts":[{"path":"LowerStock","caption":"下件导槽","axis":Vector3(.5,0,sin(PI/3)),"normal":Vector3.UP},{"path":"MiddleStock","caption":"中件滑槽","axis":Vector3.RIGHT,"normal":Vector3.DOWN},{"path":"UpperStock","caption":"顶件锁口","axis":Vector3(.5,0,-sin(PI/3)),"normal":Vector3.DOWN}],"order":["MiddleStock","UpperStock"],"closed_positions":{"MiddleStock":Vector3.ZERO,"UpperStock":Vector3.ZERO},"description":"中件先从侧面沿槽滑入，顶件再向下落入交叉口，挡住中件的退出方向。","closed_text":"中件侧推到位后，顶件落下，槽肩阻挡中件沿原路退出。"})
		Appearance.apply(root)
		preview.configure(root,Vector3(0,.40 if id=="three_way_lap" else .18,.7 if id=="tongue_groove" else 0),Vector3(4,6,2.3) if id=="three_way_lap" else Vector3(2.3,3,4),2.3,3.6)
		button.tooltip_text=DETAILS[id]
		var footer:=HBoxContainer.new();footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(footer)
		var caption:=Label.new();caption.text="选"+{"tongue_groove":"企口榫","cross_lap":"搭扣榫 · 上下落合","three_way_lap":"扣合榫 · 侧推锁合"}[id];caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.custom_minimum_size.y=32;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(caption);captions[id]=caption
		var inspect:=Button.new();inspect.text="放大";inspect.custom_minimum_size=Vector2(56,44);inspect.add_theme_font_size_override("font_size",16);footer.add_child(inspect);inspect_buttons[id]=inspect
		inspect.pressed.connect(func():inspect_requested.emit(id))
func choose(id: String) -> void:
	for key in buttons:buttons[key].set_pressed_no_signal(key==id)

func configure_task(_expected: String) -> void:
	for id in TYPES:
		var label: String={"tongue_groove":"企口榫","cross_lap":"搭扣榫 · 交叉嵌合","three_way_lap":"扣合榫 · 侧推锁合"}[id]
		captions[id].text="选"+label
		buttons[id].tooltip_text=DETAILS[id]
