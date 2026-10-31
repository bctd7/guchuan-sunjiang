extends SceneTree
const Presenter = preload("res://classroom/science/dynamic/presenter.gd")
var failures: Array[String] = []
var assertions := 0
var captures := false
class FakeAssembly extends Node:
	signal changed
	var definition := {"id":"dovetail"}

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	if not captures: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://classroom/science/dynamic/evidence/"+name+".png")

func inside_or_on_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		if Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(point) < 0.05: return true
	return false

# Read actual OBJ triangles: compare the dominant sloped contact face, not bevels.
# The artwork deliberately simplifies the mesh; the 0.02 tolerance is a slope
# approximation (~4.5%), not a force, clearance, or dimensional accuracy claim.
func source_face_slope(path: String) -> float:
	var vertices: Array[Vector3] = []
	var largest := 0.0
	var slope := -1.0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var fields := line.split(" ",false)
		if fields.is_empty(): continue
		if fields[0] == "v":
			vertices.append(Vector3(float(fields[1]),float(fields[2]),float(fields[3])))
		elif fields[0] == "f":
			var a := vertices[int(fields[1].split("/")[0])-1]
			var b := vertices[int(fields[2].split("/")[0])-1]
			var c := vertices[int(fields[3].split("/")[0])-1]
			var normal := (b-a).cross(c-a)
			var center := (a+b+c)/3.0
			if center.x < .2 or center.x > .5 or center.y > .01: continue
			if absf(normal.z) > normal.length()*.001 or absf(normal.x) < .00001: continue
			var candidate := normal.y/normal.x
			if candidate > .3 and candidate < .6 and normal.length() > largest:
				largest = normal.length()
				slope = candidate
	return slope

func check_current_model(d: Control) -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://models/joinery/catalog.json"))
	var joint: Dictionary = {}
	for item in catalog:
		if item.id == "dovetail": joint = item
	check(not joint.is_empty(),"current catalog includes dovetail")
	if joint.is_empty(): return
	for spec in joint.parts:
		var slope := source_face_slope(spec.mesh)
		check(slope > 0,"actual OBJ contains the outward-widening dovetail contact face: " + spec.id)
		check(absf(slope-d.SLOPE) < .02,"simplified drawing slope corresponds to current OBJ within documented approximation: " + spec.id)
		if spec.id == "tail":
			check(not spec.fixed and spec.dependencies == ["groove"],"moving tail belongs to fixed groove")
			check(spec.start_position[2] > 0 and spec.start_position[0] == 0 and spec.start_position[1] == 0,"assembly slides along Z; transverse Y pull is a separate illustrated load case")
		else:
			check(spec.id == "groove" and spec.fixed,"groove is the fixed support")
	check(d.moving_polygon()[4].x-d.moving_polygon()[3].x > 0,"drawing tail widens toward its bottom like model")
	check(is_equal_approx(d.CYCLE,6.0),"single blocked pull repeats every six seconds")

func run() -> void:
	captures = "--capture" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,800)
	var p := Presenter.new()
	root.add_child(p)
	await process_frame
	check(not p.opened and not p.panel.visible and not p.is_processing(),"hidden presenter does not process")
	check(not p.open_for_joint("zong_corner"),"unreviewed joint has no fabricated lesson")
	check(p.open_for_joint(),"dovetail opens")
	check(p.is_processing() and p.diagram.playing,"opening auto-starts")
	p.set_process(false)
	var d: Control = p.diagram
	check_current_model(d)
	check(p.panel.find_children("*","Label",true,false).is_empty(),"no visible text labels")
	check(p.panel.find_children("*","Button",true,false).size() == 1,"only close control")
	d.replay()
	var previous: float = d.displacement()
	for step in range(1800):
		d.advance(1.0/30.0)
		var now: float = d.displacement()
		check(now >= -0.001 and now <= d.STOP+0.001,"bounded motion across cycles")
		check(absf(now-previous) < 1.0,"smooth reset and wrap without jump")
		check(d.CLEARANCE-now*d.SLOPE >= -0.00001,"no tongue penetrates slot")
		if d.reaction_alpha() > 0.01: check(d.touching(),"reaction appears only at contact")
		if d.pulse_progress() >= 0:
			check(d.touching() and d.reaction_alpha() < 0.01 and d.force_alpha() < 0.01,"pulse follows contact and force arrows")
		previous = now
	check(d.completed_cycles >= 8 and d.playing,"repeated cycles keep playing and stay in the blocked pull lesson")
	d.elapsed = 1.4
	check(d.touching() and d.contact_alpha() > 0.5,"contact flash precedes propagation")
	check(d.pulse_progress() < 0,"no pulse during first contact flash")
	for side in [-1,1]:
		var reaction: Vector2 = d.reaction_vector(side)
		check(absf(reaction.dot(Vector2(side*d.SLOPE,1))) < 0.001,"reaction normal to face")
		check(reaction.y > 0 and reaction.x*side < 0,"reaction on moving member down/inward")
		check(inside_or_on_edge(d.contact_point(side)+reaction,d.moving_polygon()),"reaction tip stays in moving member")
		var path: Curve2D = d.force_path(side)
		check(path.get_point_position(0).is_equal_approx(d.contact_point(side)),"pulse starts at exact contact")
		for sample in range(201):
			check(inside_or_on_edge(path.sample_baked(path.get_baked_length()*sample/200.0),d.base_polygon()),"entire pulse path stays in fixed member")
		check(is_equal_approx(path.get_point_position(1).y,365),"pulse ends on support")
	d.elapsed = 4.2
	check(d.support_alpha() > 0,"support briefly responds at arrival")
	d.elapsed = 5.95
	check(d.force_alpha() == 0 and d.reaction_alpha() == 0 and d.pulse_progress() < 0,"reset occurs without applied force or pulses")
	p.set_paused(true)
	var before: float = d.elapsed
	p._process(3.0)
	check(d.elapsed == before,"pause API freezes phase")
	p.set_paused(false)
	p._process(0.1)
	check(is_equal_approx(d.elapsed,fposmod(before+.1,d.CYCLE)),"resume API continues phase including wrap")
	p.close_button.pressed.emit()
	before = d.elapsed
	p._process(50)
	check(not p.opened and not p.panel.visible and not d.playing and not p.is_processing() and d.elapsed == before,"close stops all background advancing")
	for i in range(5):
		check(p.open_for_joint() and d.elapsed == 0 and d.playing,"reopening restarts cleanly")
		p.close()
	p.open_for_joint()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	p._input(escape)
	check(not p.opened and not p.is_processing(),"Escape fully stops")
	p.open_for_joint()
	p.set_process(false)
	# Render three whole cycles in the blocked pull lesson (accelerated clock, real frames).
	if captures:
		d.replay()
		for frame in range(217):
			p._process(d.CYCLE/72.0)
			await process_frame
		check(d.completed_cycles >= 3 and d.playing,"real render survives multiple full cycles")
	for dimensions in [Vector2i(1280,800),Vector2i(800,600),Vector2i(1440,900),Vector2i(640,480)]:
		root.size = dimensions
		await process_frame
		await process_frame
		check(p.panel.size.x <= dimensions.x+1 and p.panel.size.y <= dimensions.y+1,"panel fits")
		check(p.close_button.get_global_rect().end.x <= dimensions.x and p.close_button.get_global_rect().end.y <= dimensions.y,"icons in bounds")
		for phase in [.2,.8,1.4,2.8,4.2,5.2,5.95]:
			d.elapsed = phase
			d.queue_redraw()
			await process_frame
			if dimensions == Vector2i(1280,800) or phase == 2.8:
				await shot("loop-%d-%s-%dx%d" % [0,str(phase).replace(".","_"),dimensions.x,dimensions.y])
	var assembly := FakeAssembly.new()
	root.add_child(assembly)
	var entry: Button = p.create_entry_button(assembly)
	root.add_child(entry)
	check(entry.visible,"dovetail entry visible")
	entry.pressed.emit()
	check(p.opened,"entry opens autoplay")
	assembly.changed.emit()
	check(p.opened,"ordinary refresh preserves playback")
	assembly.definition.id = "other"
	assembly.changed.emit()
	check(not entry.visible and not p.opened and not p.is_processing(),"model switch stops stale lesson")
	entry.queue_free()
	assembly.queue_free()
	var result := {"assertions":assertions,"failures":failures,"render_capture":captures,"simulated_cycles":8,"rendered_cycles":3 if captures else 0}
	var file := FileAccess.open("res://classroom/science/dynamic/evidence/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	p.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
