extends HBoxContainer
signal chosen(kind: String)
const G = preload("res://models/ship/rigging/ship_geometry.gd")
const Rules = preload("res://levels/level03/connection_rules.gd")
const EndCrop = preload("res://models/ship/mesh_end_crop.gd")
var buttons: Dictionary = {}
var viewports: Dictionary = {}
var specimens: Dictionary = {}
var _id := ""
const CROPS = {
	"zrail":AABB(Vector3(-.05,-.05,-.05),Vector3(1.10,1.10,1.5)),
	"leg":AABB(Vector3(-.05,-.20,-.05),Vector3(1.10,1.25,1.10)),
	"mast":AABB(Vector3(-.5,1.06,-.5),Vector3(1.0,1.0,1.0)),
	"apron":AABB(Vector3(-.8,-.75,-.4),Vector3(1.6,1.15,.8)),
	"top":AABB(Vector3(-.8,.35,-.6),Vector3(1.6,.41,1.2)),
	"lbrace":AABB(Vector3(-.85,-.55,-.5),Vector3(1.75,1.1,1.0)),
	"rudder":AABB(Vector3(1.9,.3,-.4),Vector3(.8,1.0,.8)),
	"blade":AABB(Vector3(1.9,-1.75,-1.35),Vector3(.8,1.2,1.75))
}
signal inspect_requested(kind: String)
var previews: Dictionary={}
var inspect_buttons: Dictionary={}
func configure(id: String) -> void:
	if id==_id:return
	_id=id
	for child in get_children():remove_child(child);child.queue_free()
	buttons.clear();viewports.clear();specimens.clear();previews.clear();inspect_buttons.clear()
	add_theme_constant_override("separation",8);custom_minimum_size.y=174
	for kind in Rules.candidates(id):
		var card=preload("res://components/ui/selection_card.gd").new();add_child(card)
		buttons[kind]=card;previews[kind]=card.preview;inspect_buttons[kind]=card.inspect_button
		viewports[kind]=card.preview.viewport
		card.caption.text="选"+Rules.NAMES[kind]
		card.pressed.connect(func():chosen.emit(kind))
		card.inspect_requested.connect(func():inspect_requested.emit(kind))
		var part=G.piece(id,kind)
		# Cropping reads global transforms; mount the source before sampling it.
		card.preview.viewport.add_child(part)
		var specimen=Node3D.new();specimen.name="ActualShipCandidate_"+id+"_"+kind
		specimen.set_meta("ship_member",id);specimen.set_meta("candidate_kind",kind)
		EndCrop.copy_into(part,specimen,CROPS[id]);part.free();specimens[kind]=specimen
		var direction=Vector3(4,-3 if id in ["zrail","top"] else 3,6)
		if id=="zrail":direction=Vector3(5,-4,-6)
		if id=="lbrace":direction=Vector3(1.5,2,7)
		card.preview.show_model(specimen,CROPS[id].get_center(),direction,1.8,2.8)
		card.preview.frame_model(specimen,direction)
func select(kind: String) -> void:
	for id in buttons:buttons[id].set_pressed_no_signal(id==kind)
