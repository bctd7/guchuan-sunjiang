extends RefCounted
## Read the actual interface for the current assembly, not just the task name.
## A/B/C never changes the measured receiver. Adapted starter joints use their
## actual local connection, not the later standard joint's dimensions.
const Dimensions=preload("res://components/ui/measurements/opening_dimensions.gd")
const Contact=preload("res://models/ship/hull/trial_contact.gd")
const Starter=preload("res://models/ship/hull/starter_joint.gd")
const Section=preload("res://models/ship/hull/opening_section.gd")

static func build(view,state) -> Dictionary:
 var id: String=state.selected
 var geometry_id: String=view.opening_geometry_id(id)
 var receiving: Dictionary=view.receiving_dimensions(id)
 var data:={"title":"先看看接合处","subtitle":"","kind":"beam","span":.60,"step":10,"value":0.0,"label":"","caption":"","note":""}
 if id.begins_with("plank_0") and geometry_id=="cross_upper":
  var measured:=starter_cross_section(view,id)
  data.merge({"title":"缺口要跨过这段座木","subtitle":"按搭扣的装入方向比较","value":measured.width,"depth":measured.depth,"label":"宽约%d格"%roundi(measured.width*100),"caption":"座木宽约%d格，开槽约%d格深。"%[roundi(measured.width*100),roundi(measured.depth*100)],"note":"对照下方缺口的宽度和挖入深度。","source":"starter_cross_section"},true)
  return data
 if id.begins_with("plank_0") and geometry_id in ["three_middle","starter_lock_top"]:
  # These tops are individually carved to their middle and the real starter
  # rail. There is no single 28-grid target shared by all three matched pairs.
  data.merge({"title":"这两件配套扣合","subtitle":"每组两件，缺口相互对应。","kind":"paired","caption":"先侧推中件，再下压配套件。","note":"选择下方木料后，在左侧试装。","source":"starter_matched_pair"},true)
  return data
 if geometry_id!=id:
  # A foreign joint at later receivers has no corresponding width/depth
  # target. Do not compare different axes or borrow a future member's sizes.
  # Keep the actual receiver's form available while the player tries the fit.
  var form: String={"tongue":"现有板边是一条连续凸条。","beam":"这里是两根木料的交叉处。","slide_channel":"现有槽口从侧面开口。","upper_channel":"这里是两根已装木料的交叉处。"}.get(str(receiving.get("kind","")),"看看现有木料的接合面。")
  data.merge({"title":"先对照这里的接合形状","subtitle":form,"kind":"shape","caption":"转动木料，让两边缺口相向。","note":"沿箭头试装，观察实际接触的位置。","source":"actual_receiver_shape"},true)
  return data
 if id.begins_with("plank"):
  var center: float=receiving.stock*.5+receiving.offset
  data.merge({"title":"槽口要对齐板边凸条","subtitle":"从板端看凸条的位置","kind":"tongue","value":center,"stock":receiving.stock,"width":receiving.width,"depth":receiving.depth,"label":"板边","caption":"凸条在板厚中间。","note":"比较下方槽口：靠上、居中，还是靠下。"},true)
 elif id in ["cross_upper","bulkhead"]:
  data.merge({"title":"缺口要包住这根横梁","subtitle":"比较开口多宽、挖入多深","value":receiving.width,"label":"宽%s格"%Dimensions.number(receiving.width),"caption":"横梁宽%s格，需要嵌入%s格。"%[Dimensions.number(receiving.width),Dimensions.number(receiving.depth)],"note":"开口稍宽一些，才能套住横梁。"},true)
 elif id=="three_middle":
  # The differing upper mouths receive the next top; the common lower guide
  # gives no information for choosing between those mouths.
  var top: Dictionary=Dimensions.read(view.pieces.three_upper)
  data.merge({"title":"给最后一根木料留出缺口","subtitle":"比较开口宽度、开在什么位置","value":top.stock,"label":"宽%s格"%Dimensions.number(top.stock),"caption":"最后一根木料宽%s格，要从中间落下。"%Dimensions.number(top.stock),"note":"开口稍宽一些，并开在中间。"},true)
 elif id=="three_upper":
  var lower: Dictionary=Dimensions.read(view.fixed.three_lower,"receiving_dimensions")
  var middle: Dictionary=receiving if state.placed.has("three_middle") else Dimensions.read(view.pieces.three_middle,"receiving_dimensions")
  var equal_widths:=is_equal_approx(middle.flange,lower.stock)
  data.merge({"title":"缺口要对准两根木料","subtitle":"比较开口宽度、开在什么位置","kind":"layers","value":middle.flange,"lower_width":lower.stock,"label":"宽%s格"%Dimensions.number(middle.flange),"lower_label":"" if equal_widths else "宽%s格"%Dimensions.number(lower.stock),"caption":"两根都宽%s格，交叉位置在中间。"%Dimensions.number(middle.flange) if equal_widths else "两处开口分别包住对应的木料。","note":"已装中件：开口%s格，%s。"%[Dimensions.number(middle.width),Dimensions.position(middle.offset)]},true)
  var local_frame:=Transform3D(Basis.IDENTITY,-view.THREE_CENTER)
  var parts:=Contact.meshes(view.fixed.three_lower,local_frame*view.fixed.three_lower.transform)
  var middle_pose: Transform3D=view.poses.three_middle if state.placed.has("three_middle") else Transform3D(Basis.IDENTITY,view.THREE_CENTER)
  parts.append_array(Contact.meshes(view.pieces.three_middle,local_frame*middle_pose))
  # This side exposes both a narrow previous channel and a channel shifted
  # away from the crossing; the opposite side can conceal the latter.
  data["sections"]=Section.contours(parts,Vector3(sin(PI/3),0,cos(PI/3)),-.14,Vector3(-cos(PI/3),0,sin(PI/3)))
 return data

static func starter_cross_section(view,id: String) -> Dictionary:
 var rail: Node3D=view.fixed.starter
 var parts:=Contact.meshes(rail,rail.transform)
 var center: float=Starter.CENTERS[0 if id.ends_with("a") else 1]
 var cut:=section_bounds(parts,center)
 var shoulder:=section_bounds(parts,center-Starter.SOCKET_WIDTH*.5-.01)
 # Measure across the fixed seat at the actual crossing. The depth is the
 # removed rail above its housing floor, compared with the adjacent shoulder.
 return {"width":cut.size.x,"depth":maxf(0,shoulder.end.y-cut.end.y)}

static func section_bounds(parts: Array,x: float) -> Rect2:
 var points: Array[Vector2]=[]
 for part in parts:
  var faces: PackedVector3Array=part.mesh.get_faces()
  for index in range(0,faces.size(),3):
   for edge in 3:
    var a: Vector3=part.pose*faces[index+edge]
    var b: Vector3=part.pose*faces[index+(edge+1)%3]
    if absf(a.x-x)<.000001:points.append(Vector2(a.z,a.y))
    if (a.x<x and b.x>x) or (a.x>x and b.x<x):
     var point: Vector3=a.lerp(b,(x-a.x)/(b.x-a.x));points.append(Vector2(point.z,point.y))
 if points.is_empty():return Rect2()
 var bounds:=Rect2(points[0],Vector2.ZERO)
 for point in points:bounds=bounds.expand(point)
 return bounds
