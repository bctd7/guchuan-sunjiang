extends "res://tests/inspection_workspace_tests.gd"
const Dimensions=preload("res://levels/level02/opening_dimensions.gd")
const Reference=preload("res://levels/level02/opening_reference.gd")
var first_reference_height:=0.0
var first_card_height:=0.0
var first_font_size:=0
func capture(name: String) -> void:
 if not gpu:return
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var folder:="res://tests/evidence/direct-comparison"
 DirAccess.make_dir_recursive_absolute(folder)
 var path:=folder+"/"+name+".png"
 check(surface.get_texture().get_image().save_png(path)==OK,"capture "+name);images.append(path)
func seed_stage(target: String,middle: String="C") -> void:
 level._restart()
 for id in level.Rules.IDS:
  if id==target:break
  level.state.select(id);level.state.observe();level.state.choose_joint(level.Rules.expected(id));level.state.choose_opening(middle if id=="three_middle" else level.state.Openings.target(id))
  check(level.state.attempt(id).ok,"presentation prefix "+id)
 level.state.select(target)
 await button(level.panel.observe_button)
 level.state.choose_joint(level.Rules.expected(target));level.state.choose_opening(level.state.Openings.target(target))
 await settle(.1)
func check_text_fits(label: Label,scope: String) -> void:
 var font:=label.get_theme_font("font")
 for line in label.text.split("\n"):
  check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+.5,"candidate dimensions fit their visible label "+scope)
func check_rendered_stock(gallery,scope: String) -> void:
 if not gpu:return
 RenderingServer.force_draw(false)
 for option in gallery.previews:
  var preview=gallery.previews[option]
  var bitmap: Image=preview.viewport.get_texture().get_image()
  var wood:=0;var samples:=0
  for y in range(0,bitmap.get_height(),3):
   for x in range(0,bitmap.get_width(),3):
    var color:=bitmap.get_pixel(x,y);samples+=1
    if color.r+color.g+color.b<2.55:wood+=1
  check(wood>samples*.05,"actual wood remains rendered, not just dimension marks "+scope+"/"+option)
func run() -> void:
 gpu=OS.get_cmdline_user_args().has("--gpu");root.set_flag(Window.FLAG_NO_FOCUS,true)
 if gpu:root.mode=Window.MODE_MINIMIZED
 surface=SubViewport.new();surface.size=Vector2i(1440,900);surface.own_world_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
 campaign=load("res://campaign/campaign.tscn").instantiate();surface.add_child(campaign);await settle(.2)
 # Inspect the real, active chapter-one UI, not its obsolete comparison file.
 await button(campaign.chapter_buttons[1]);level=campaign.instances[1];await button(level.learning.start_button)
 await button(level.panel.inspect_button);await button(level.inspector.joint_buttons.blind_tenon)
 first_reference_height=level.inspector.comparison.custom_minimum_size.y
 first_card_height=level.inspector.length_gallery.buttons.correct.custom_minimum_size.y
 first_font_size=level.inspector.length_gallery.captions.correct.get_theme_font_size("font_size")
 await capture("chapter-1-reference")
 await button(level.inspector.close_button);await button(campaign.back_button)
 await button(campaign.chapter_buttons[2]);level=campaign.instances[2];await button(level.learning.start_button)
 for target in ["plank_0a","plank_1a","plank_2a","cross_upper","bulkhead","three_middle","three_upper"]:
  await seed_stage(target)
  var gallery=level.panel.opening_gallery
  var panel=level.panel.opening_measure
  var fixed: Dictionary=panel.reference.duplicate(true)
  check(panel.custom_minimum_size.y==first_reference_height,"reference panel follows chapter-one layout height "+target)
  for option in ["A","B","C"]:
   var d: Dictionary=gallery.measurements[option]
   var label: Label=gallery.caption_labels[option]
   check(label.is_visible_in_tree() and label.text.begins_with(option+" · "),"all three cards show their deciding features before selection "+target+"/"+option)
   var height: float=gallery.buttons[option].custom_minimum_size.y
   check(height>=first_card_height and label.get_theme_font_size("font_size")==first_font_size,"candidate row preserves chapter-one base size and readable type "+target)
   check(height==first_card_height and label.text.split("\n").size()<=2,"key features fit chapter-one row height "+target)
   if d.kind=="groove":
    var position_text: String="居中" if is_zero_approx(d.offset) else ("靠上" if d.offset>0 else "靠下")
    check(label.text.contains(Dimensions.number(d.stock*.5+d.offset)+"格") and label.text.contains("槽口高度"),"board height uses the same bottom-edge datum as the reference")
   else:check(label.text.contains("宽"+Dimensions.number(d.width)),"visible opening width retains actual mesh measurement")
   if d.kind in ["upper_channel","double_notch"]:
    check(label.text.contains("居中" if is_zero_approx(d.offset) else "偏旁") and not label.text.contains("深") and not label.text.contains("/"),"lock choices retain only width and physical opening location")
   check_text_fits(label,target+"/"+option)
   check(is_equal_approx(gallery.previews.A.camera.size,gallery.previews[option].camera.size),"A/B/C share orthographic scale "+target)
   if target.begins_with("plank"):
    var model=gallery.previews[option].model_root.get_child(0)
    var low: AABB=model.get_child(1).transform*model.get_child(1).get_aabb()
    var high: AABB=model.get_child(2).transform*model.get_child(2).get_aabb()
    check(is_equal_approx(d.width,high.position.y-low.end.y) and is_equal_approx(d.depth,low.size.z),"groove labels agree with actual box faces")
    check(is_equal_approx(d.offset,(high.position.y+low.end.y)*.5),"groove position agrees with its actual shoulders")
   if target in ["cross_upper","bulkhead"]:
    var model=gallery.previews[option].model_root.get_child(0)
    var first: AABB=model.get_child(1).transform*model.get_child(1).get_aabb()
    var second: AABB=model.get_child(2).transform*model.get_child(2).get_aabb()
    check(is_equal_approx(d.width,second.position.z-first.end.z) and is_equal_approx(d.depth,first.size.y),"lap width/depth labels agree with actual mating faces")
  check(gallery.captions.A!=gallery.captions.B and gallery.captions.B!=gallery.captions.C and gallery.captions.A!=gallery.captions.C,"all candidates have distinct deciding features even without their A/B/C codes "+target)
  for option in ["A","B","C"]:
   if target in level.Rules.MANUAL_IDS:await button(gallery.buttons[option])
   else:level.state.choose_opening(option);await settle(.03)
   check(level.state.opening==option and gallery.buttons[option].button_pressed,"actual pointer chooses candidate "+target+"/"+option)
   check(panel.reference==fixed,"target ruler is fixed across A/B/C "+target)
  if target.begins_with("plank"):
   check(is_equal_approx(fixed.value,.09) and is_equal_approx(fixed.width,.06) and fixed.caption.contains("中间"),"plank reference shows actual tongue at the middle of board thickness")
  elif target in ["cross_upper","bulkhead"]:
   check(is_equal_approx(fixed.value,.28) and fixed.caption.contains("12格"),"cross reference supplies the actual mating width and depth")
  elif target=="three_middle":
   check(is_equal_approx(fixed.value,Dimensions.read(level.view.pieces.three_upper).stock) and fixed.caption.contains("中间"),"middle compares opening width/location with the actual next top")
  else:
   check(fixed.kind=="layers" and is_equal_approx(fixed.value,.28) and is_equal_approx(fixed.lower_width,.28) and fixed.caption.contains("中间") and not fixed.caption.contains("深"),"top shows the two real stock widths and location, omitting identical candidate depths")
  var before:=mesh_signature(level.view.pieces[target]);var placed: Dictionary=level.state.placed.duplicate(true)
  Reference.build(level.view,level.state)
  check(mesh_signature(level.view.pieces[target])==before and level.state.placed==placed and level.state.opening=="C","display reads do not alter geometry or assembly")
  for dimensions in [Vector2i(1440,900),Vector2i(960,600)]:
   surface.size=dimensions;await settle(.1)
   var actions: Rect2=level.panel.workspace.actions.get_global_rect()
   for control in [level.panel.workspace.actions,level.panel.workspace.note,level.panel.workspace.get_child(1)]:
    check(surface.get_visible_rect().grow(.5).encloses(control.get_global_rect()),"whole page fits viewport "+target+"/"+str(dimensions))
   check(gallery.get_global_rect().end.y<=actions.position.y,"target and three candidates fit above actions "+target)
   for option in gallery.buttons:
    for control in [gallery.caption_labels[option],gallery.previews[option],gallery.inspect_buttons[option]]:
     check(gallery.buttons[option].get_global_rect().grow(.5).encloses(control.get_global_rect()),"complete candidate content fits row "+option)
   var font=panel.get_theme_default_font()
   check(font.get_string_size(fixed.title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=panel.size.x-24,"reference title fits at chapter-one font size "+target)
   for line in [fixed.subtitle,fixed.caption,fixed.note]:check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=panel.size.x-24,"reference text fits at chapter-one font size "+target)
   if gpu:
    check_rendered_stock(gallery,target+"/"+str(dimensions))
    var model_scale: float=gallery.previews.A.size.y/gallery.previews.A.camera.size
    check(is_equal_approx(panel.pixel_scale,model_scale),"target and actual wood use the same pixel scale "+target)
    for option in gallery.previews:
     var marks=gallery.marks[option]
     var segments: Array=marks.segments
     if segments.is_empty():continue
     var first: Array=segments[0]
     var measured_pixels: float=(gallery.previews[option].camera.unproject_position(first[0])-gallery.previews[option].camera.unproject_position(first[1])).length()
     var d: Dictionary=gallery.measurements[option]
     if d.kind=="groove":check(is_equal_approx(measured_pixels,(d.stock*.5+d.offset)*model_scale),"height bracket uses actual board edge and groove centre "+option)
     elif d.kind in ["notch","upper_channel"]:check(is_equal_approx(measured_pixels,d.width*model_scale),"width bracket spans the real opening "+option)
    check(not panel.target_rectangles.is_empty(),"target is rendered on the ruler")
    var shown: Rect2=panel.target_rectangles[0]
    if fixed.kind=="tongue":
     var tongue: Rect2=panel.target_rectangles[1]
     check(is_equal_approx(shown.size.y,fixed.stock*panel.pixel_scale) and is_equal_approx(tongue.get_center().y,shown.end.y-fixed.value*panel.pixel_scale) and is_equal_approx(tongue.size.y,fixed.width*panel.pixel_scale),"upright board-end reference preserves real thickness, tongue position and tongue thickness")
    else:check(is_equal_approx(shown.size.x,fixed.value*panel.pixel_scale),"reference target ends agree with the ruler")
   if target in level.Rules.MANUAL_IDS:await capture(target+"-"+str(dimensions.x))
  surface.size=Vector2i(1440,900);await settle(.1)
 await seed_stage("plank_0a")
 var fixed_reference: Dictionary=level.panel.opening_measure.reference.duplicate(true)
 for kind in ["cross_lap","three_way_lap","tongue_groove"]:
  await button(level.panel.joint_buttons[kind]);await settle(.1)
  var family_reference: Dictionary=level.panel.opening_measure.reference.duplicate(true)
  if kind=="cross_lap":
   check(family_reference.kind=="beam" and family_reference.source=="starter_cross_section" and absf(family_reference.value-.33255)<.0001 and absf(family_reference.depth-.09062)<.0001,"first cross compares its real seat width and housing depth, not the tongue or the later 28-grid beam")
  elif kind=="three_way_lap":
   check(family_reference.kind=="paired" and family_reference.source=="starter_matched_pair" and not family_reference.caption.contains("28"),"first matched pair does not claim a standard later top as its reference")
  else:check(family_reference==fixed_reference,"returning to groove restores the actual tongue reference")
  for option in ["A","B","C"]:
   await button(level.panel.opening_buttons[option])
   check(level.panel.opening_measure.reference==family_reference,"real local receiver stays stable across adapted A/B/C "+kind+"/"+option)
   check_text_fits(level.panel.opening_gallery.caption_labels[option],"first-"+kind+"/"+option)
  check(level.panel.opening_measure.custom_minimum_size.y==(104 if kind=="three_way_lap" else 156),"matched-pair note does not reserve a meaningless ruler "+kind)
  await capture("first-"+kind)
  check_rendered_stock(level.panel.opening_gallery,"first-"+kind)
  surface.size=Vector2i(960,600);await settle(.1)
  var font=level.panel.opening_measure.get_theme_default_font()
  for line in [family_reference.subtitle,family_reference.caption,family_reference.note]:
   check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,16 if family_reference.kind=="paired" and line==family_reference.caption else 13).x<=level.panel.opening_measure.size.x-24,"adapted receiver comparison fits small window "+kind)
  await capture("first-"+kind+"-960")
  check_rendered_stock(level.panel.opening_gallery,"first-"+kind+"-960")
  surface.size=Vector2i(1440,900);await settle(.1)
 await button(level.panel.opening_gallery.inspect_buttons.A)
 check(level.panel.magnifier.visible and level.state.opening=="C","magnifying another card preserves selected candidate")
 check(level.panel.magnifier.preview.camera.far>50,"magnifier retains full wood beyond the board-end observation slice")
 await button(level.panel.magnifier.close_button)
 var profiles: Dictionary={}
 for middle in ["A","B","C"]:
  await seed_stage("three_upper",middle)
  var actual: Dictionary=level.panel.opening_measure.dimensions
  check(is_equal_approx(actual.width,.13 if middle=="A" else .284) and is_equal_approx(actual.offset,.30 if middle=="B" else 0.0),"reference retains installed middle dimensions "+middle)
  check(level.panel.opening_measure.reference.note.contains("开口"+Dimensions.number(actual.width)+"格") and level.panel.opening_measure.reference.note.contains("中间" if is_zero_approx(actual.offset) else "一侧"),"visible target note retains actual previous opening width and location "+middle)
  profiles[middle]=JSON.stringify(level.panel.opening_measure.reference.sections)
  check(not level.panel.opening_measure.reference.sections.is_empty(),"actual installed solids supply the top receiving profile "+middle)
  await capture("top-reference-middle-"+middle)
 check(profiles.A!=profiles.C and profiles.B!=profiles.C,"a wrong middle changes the visible receiving contour, not only a text note")
 for target in ["cross_upper","three_middle","three_upper"]:
  await seed_stage(target)
  var expected: Dictionary=level.panel.opening_measure.reference.duplicate(true)
  for kind in ["tongue_groove","cross_lap","three_way_lap"]:
   if kind==level.Rules.expected(target):continue
   await button(level.panel.joint_buttons[kind])
   check(level.panel.opening_measure.reference.kind=="shape" and level.panel.opening_measure.reference.source=="actual_receiver_shape","foreign joint does not present unrelated widths/depths as comparable "+target+"/"+kind)
   var real_receiver: Dictionary=level.view.receiving_dimensions(target)
   check(level.panel.opening_measure.dimensions==real_receiver,"alternative joint preserves the actual physical receiver "+target+"/"+kind)
  await button(level.panel.joint_buttons[level.Rules.expected(target)])
  check(level.panel.opening_measure.reference==expected,"return to native joint restores its measured reference "+target)
 check(not root.has_focus() if gpu else true,"GPU capture does not steal focus")
 campaign.free();surface.free()
 var report={"passed":passed,"failed":failures.size(),"failures":failures,"images":images,"renderer":DisplayServer.get_name(),"host_had_focus":root.has_focus() if gpu else false,"scope":"Actual chapter-one reference and rows; face-on real candidate wood, shared reference/candidate pixel scale and datum, measured brackets, complete foreground rendering after type switches, seven stages, two viewport sizes, retained wrong middle profiles and full-model magnifier. Presentation only."}
 DirAccess.make_dir_recursive_absolute("res://tests/evidence/direct-comparison")
 FileAccess.open("res://tests/evidence/direct-comparison/dimensions-"+("gpu" if gpu else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("OPENING_DIMENSIONS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
