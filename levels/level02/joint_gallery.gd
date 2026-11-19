extends HBoxContainer
const Lighting=preload("res://levels/level02/timber_lighting.gd")
## Three real ship-material candidate previews; assembled from current G solids.
const Appearance=preload("res://models/ship/hull/wood_appearance.gd")
const G=preload("res://models/ship/hull/ship_geometry.gd")
const Boat=preload("res://models/ship/hull/boat_joints.gd")
signal chosen(id: String)
signal inspect_requested(id: String)
var inspect_buttons: Dictionary={}
const Workspace=preload("res://components/ui/inspection_workspace.gd")
const Preview=preload("res://components/preview/rotatable_preview.gd")
var previews: Dictionary={}
const DETAILS={"tongue_groove":"舌槽沿板边相接","cross_lap":"两件缺口相向落合","three_way_lap":"中件侧推，顶件锁合"}
const CAPTIONS={"tongue_groove":"选企口榫","cross_lap":"选搭扣榫 · 交叉嵌合","three_way_lap":"选扣合榫 · 侧推锁合"}
const TYPES=["tongue_groove","cross_lap","three_way_lap"]
var buttons: Dictionary={}
var captions: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",28)
	custom_minimum_size.y=174

func build_cards() -> void:
	if not buttons.is_empty():
		return
	for id in TYPES:
		var button=preload("res://components/ui/selection_card.gd").new();add_child(button);buttons[id]=button
		button.pressed.connect(func():chosen.emit(id))
		var preview=button.preview;previews[id]=preview;preview.set_lighting_profile(Lighting)
		captions[id]=button.caption;inspect_buttons[id]=button.inspect_button
		button.caption.text = CAPTIONS[id]
		button.inspect_requested.connect(func():inspect_requested.emit(id))
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
		var direction := Vector3(4, 6, 2.3) if id == "three_way_lap" else Vector3(2.3, 3, 4)
		preview.show_model(root, Vector3.ZERO, direction, 2.3, 3.6)
		preview.frame_model(root, direction)
		button.tooltip_text=DETAILS[id]

func choose(id: String) -> void:
	for key in buttons:buttons[key].set_pressed_no_signal(key==id)
