extends RefCounted
## Boat-stock variants. Teaching models remain independent in ship_geometry.
## Every candidate keeps its stock axis and mating mouth on the real receiver.
const G=preload("res://models/ship/hull/ship_geometry.gd")
const WIDTH:=.28
const HALF:=.12
const CUT_WIDTH:=.284
const LOOSE_CUT_WIDTH:=.46
const SLIDE_NECK_WIDTH:=.18
const LAYER_HEIGHT:=.08
const ANGLES: Array[float]=[PI/3.0,0.0,-PI/3.0]
static func middle_upper_offset(option: String) -> float:
	return .30 if option=="B" else 0.0
static func middle_upper_width(option: String) -> float:
	return .13 if option=="A" else CUT_WIDTH
static func top_cut_width(option: String) -> float:
	return .18 if option=="B" else CUT_WIDTH
static func top_cut_offset(option: String) -> float:
	return .10 if option=="C" else 0.0

static func cross_member(host: Node3D,upper: bool,material: Material,option: String="C",length:=1.86) -> void:
	host.set_meta("wood_axis",Vector3.BACK if upper else Vector3.RIGHT)
	# A shallow shoulder stops on the actual lower notch floor. A wide cut can
	# seat, but retains visible clearance along the lower beam's side cheeks.
	var floor: float=-.06 if upper and option=="A" else 0.0
	var mouth: float=LOOSE_CUT_WIDTH if upper and option=="B" else CUT_WIDTH
	host.set_meta("mating_dimensions",{"kind":"notch","width":mouth,"depth":floor+HALF,"offset":0.0,"stock":HALF*2})
	if not upper:host.set_meta("receiving_dimensions",{"kind":"beam","width":WIDTH,"depth":HALF,"offset":0.0,"stock":HALF*2})
	if upper:
		G.box(host,Vector3(WIDTH,HALF-floor,length),Vector3(0,(HALF+floor)*.5,0),material)
	else:G.box(host,Vector3(length,HALF,WIDTH),Vector3(0,-HALF*.5,0),material)
	for side in [-1,1]:
		var start: float=-length*.5 if side<0 else mouth*.5
		var finish: float=-mouth*.5 if side<0 else length*.5
		var depth: float=floor+HALF if upper else HALF
		var size:=Vector3(WIDTH,depth,finish-start) if upper else Vector3(finish-start,depth,WIDTH)
		var center:=Vector3(0,(floor-HALF)*.5,(start+finish)*.5) if upper else Vector3((start+finish)*.5,HALF*.5,0)
		G.box(host,size,center,material)

static func rectangle(angle: float,width:=WIDTH,length:=2.0) -> PackedVector2Array:
	var polygon:=PackedVector2Array([Vector2(-length*.5,-width*.5),Vector2(length*.5,-width*.5),Vector2(length*.5,width*.5),Vector2(-length*.5,width*.5)])
	for i in polygon.size():polygon[i]=polygon[i].rotated(angle)
	return polygon

static func three_polygons(index: int,layer: int,option: String) -> Array[PackedVector2Array]:
	# The middle has a wide flange under a narrower neck. The lower's lips
	# retain that flange vertically, so this is a real side-entry joint.
	var stock_width: float=SLIDE_NECK_WIDTH if index==1 and layer==2 else WIDTH
	var polygons: Array[PackedVector2Array]=[rectangle(ANGLES[index],stock_width)]
	for other in 3:
		if other==index:continue
		if not ((index<other and layer>index) or (index>other and layer<=other)):continue
		var width:=CUT_WIDTH
		if index==0 and other==1 and layer==2:width=SLIDE_NECK_WIDTH+.004
		var shift:=Vector2.ZERO
		# Both middle distractors still fit the LOWER member. Only the upper
		# receiving channel differs, so the error emerges when fitting the top.
		if index==1 and other==2:
			width=middle_upper_width(option)
			shift=Vector2(cos(ANGLES[index]),sin(ANGLES[index]))*middle_upper_offset(option)
		if index==2 and option!="A":
			width=top_cut_width(option)
			shift=Vector2(cos(ANGLES[index]),sin(ANGLES[index]))*top_cut_offset(option)
		var cut:=rectangle(ANGLES[other],width,3.0)
		for i in cut.size():cut[i]+=shift
		if index==1 and other==0:
			# The middle member enters lengthwise from the open end of the hull.
			# Its underside rebate runs out to the leading end, so the lower
			# member can pass through the real channel during the entire slide.
			var swept:=cut.duplicate()
			for point in cut:swept.append(point-Vector2(3,0))
			cut=Geometry2D.convex_hull(swept)
			if cut[0].is_equal_approx(cut[-1]):cut.remove_at(cut.size()-1)
		var next: Array[PackedVector2Array]=[]
		for polygon in polygons:
			for result in Geometry2D.clip_polygons(polygon,cut):
				if result.size()>=3:next.append(result)
		polygons=next
	return polygons

static func three_member(host: Node3D,index: int,material: Material,option: String="C",top_height:=HALF) -> void:
	host.set_meta("wood_axis",Vector3(cos(ANGLES[index]),0,sin(ANGLES[index])))
	if index==0:
		host.set_meta("receiving_dimensions",{"kind":"slide_channel","width":SLIDE_NECK_WIDTH+.004,"flange":CUT_WIDTH,"depth":LAYER_HEIGHT*2,"offset":0.0,"stock":WIDTH})
	elif index==1:
		var dimensions:={"kind":"upper_channel","width":middle_upper_width(option),"depth":top_height-(-HALF+LAYER_HEIGHT*2),"offset":middle_upper_offset(option),"neck":SLIDE_NECK_WIDTH,"flange":WIDTH,"stock":top_height+HALF}
		host.set_meta("mating_dimensions",dimensions)
		host.set_meta("receiving_dimensions",dimensions.duplicate())
	else:
		host.set_meta("mating_dimensions",{"kind":"double_notch","width":top_cut_width(option),"depth":LAYER_HEIGHT*2,"shallow_depth":LAYER_HEIGHT,"offset":top_cut_offset(option),"stock":WIDTH})
	for layer in 3:
		for polygon in three_polygons(index,layer,option):
			G.prism(host,polygon,-HALF+layer*LAYER_HEIGHT,top_height if layer==2 else -HALF+(layer+1)*LAYER_HEIGHT,material)

static func bulkhead_foot(host: Node3D,material: Material,option: String) -> void:
	# The panel repeats the cross frame's actual cut: A shallow, B wide, C snug.
	var floor: float=-.06 if option=="A" else 0.0
	var mouth: float=LOOSE_CUT_WIDTH if option=="B" else CUT_WIDTH
	host.set_meta("mating_dimensions",{"kind":"notch","width":mouth,"depth":HALF+floor,"offset":0.0,"stock":HALF*2})
	G.box(host,Vector3(WIDTH,HALF-floor,.5368),Vector3(0,(HALF+floor)*.5,0),material)
	for side in [-1,1]:
		var form:=Node3D.new();host.add_child(form);form.rotation.z=PI/2
		var bottom_outer: float=mouth*.5+.008
		var poly:=PackedVector2Array([Vector2(-HALF,side*mouth*.5),Vector2(-HALF,side*bottom_outer),Vector2(minf(floor,-.045),side*bottom_outer),Vector2(floor,side*.2684),Vector2(floor,side*mouth*.5)])
		G.prism(form,poly,-WIDTH*.5,WIDTH*.5,material)
