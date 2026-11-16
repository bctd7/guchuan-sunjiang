extends Control
## Measurement brackets on the actual mating face, not labels floating in the
## assembly scene. Rotating a card hides these face-on measurements.
var preview: SubViewportContainer
var measurements: Dictionary={}
var segments: Array=[]
var front: Basis
var center:=Vector3.ZERO
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))
func configure(value: SubViewportContainer,data: Dictionary,_geometry: String) -> void:
	preview=value;measurements=data;segments.clear()
	preview.camera.far=100.0
	if data.is_empty():return
	front=preview.camera.basis;center=preview.orbit._center
	var width: float=data.width
	if data.kind=="groove":
		segments.append([Vector3(.30,-data.stock*.5,-.025),Vector3(.30,data.offset,-.025)])
	elif data.kind=="notch":
		var bottom: float=-.09 if data.stock>.25 else -.12
		segments.append([Vector3(.14,bottom-.025,-width*.5),Vector3(.14,bottom-.025,width*.5)])
		segments.append([Vector3(.14,bottom,0),Vector3(.14,bottom+data.depth,0)])
	elif data.kind=="upper_channel":
		var normal:=Vector3(sin(PI/3),0,cos(PI/3))
		var center:=Vector3(data.offset,data.stock-.12+.035,0)
		segments.append([center-normal*width*.5,center+normal*width*.5])
	elif data.kind=="double_notch":
		# The slot shoulders are oblique to this member. Keep its centre mark;
		# width is read directly from the cut geometry in the accompanying label.
		var axis:=Vector3(cos(-PI/3),0,sin(-PI/3))
		segments.append([axis*data.offset+Vector3(0,-.15,0),axis*data.offset+Vector3(0,-.12,0)])
	queue_redraw()
func _process(_delta: float) -> void:
	if is_instance_valid(preview) and measurements.get("kind","")=="groove":
		# Look at the real board end. The integral key farther down the board
		# must not obscure the groove through this narrow, face-on card.
		# Rotation and the independent magnifier still expose the whole model.
		preview.camera.far=preview.camera.position.x-.20 if preview.camera.basis.is_equal_approx(front) else 100.0
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(preview) or measurements.is_empty():return
	if not preview.camera.basis.is_equal_approx(front):return
	var ink:=Color("405343")
	var ratio:=size/Vector2(preview.viewport.size)
	for segment in segments:
		var a: Vector2=preview.camera.unproject_position(segment[0])*ratio
		var b: Vector2=preview.camera.unproject_position(segment[1])*ratio
		var side: Vector2=(b-a).normalized().orthogonal()*3
		draw_line(a,b,ink,1.5,true)
		draw_line(a-side,a+side,ink,1.5,true);draw_line(b-side,b+side,ink,1.5,true)
