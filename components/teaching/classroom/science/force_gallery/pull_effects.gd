extends RefCounted
## Only the external pull and the opposing contact force on the moving wood.
## Every anchor/edge is a source-mesh coordinate supplied by the profile.

static func draw(diagram: Control, view: Dictionary) -> void:
	var m: Dictionary = diagram.profile.modes[diagram.mode]
	var timing = diagram.load_clock()
	var alpha: float = timing.force_alpha()
	var direction: Vector2 = diagram.project(diagram.v3(m.direction),view).normalized()
	var anchor: Vector2 = diagram.project(diagram.display_vertex(m.moving[0],diagram.v3(m.pull_anchor))+diagram.display_displacement(),view)
	var scale: float = diagram.draw_scale
	var length := clampf(diagram.size.x*.09,64.0,116.0)/scale
	if alpha > .001:
		# Starts on the loaded member's outer end and points AWAY from the joint.
		diagram._arrow(anchor,anchor+direction*length*(.65+.35*alpha),Color(diagram.FORCE,alpha),1.25)
	var reaction_alpha: float = timing.reaction_alpha()
	if reaction_alpha <= .001: return
	var contact_alpha: float = timing.contact_alpha()
	var reaction_length := length*.84
	if m.has("reactions") and m.contacts.size() == 2:
		# Keep the two real oblique normals distinct rather than making a blue X.
		var separation: Vector2 = diagram.project(diagram.v3(m.contacts[1])-diagram.v3(m.contacts[0]),view)
		reaction_length = minf(reaction_length,separation.length()*.72)
	for edge in m.contact_edges:
		var a: Vector2 = diagram.project(diagram.v3(edge[0]),view)
		var b: Vector2 = diagram.project(diagram.v3(edge[1]),view)
		diagram.draw_line(a,b,Color(diagram.REACTION,.15*contact_alpha),13.0/scale,true)
		diagram.draw_line(a,b,Color(diagram.REACTION,.86*contact_alpha),4.0/scale,true)
	for i in m.contacts.size():
		var normal: Array = m.reactions[i] if m.has("reactions") else m.reaction
		var reaction: Vector2 = diagram.project(diagram.v3(normal),view).normalized()
		var contact: Vector2 = diagram.project(diagram.v3(m.contacts[i]),view)
		if not diagram.profile.has("display_clearance"):
			diagram.draw_circle(contact,4.5/scale,Color(diagram.REACTION,reaction_alpha))
		diagram._arrow(contact,contact+reaction*reaction_length,Color(diagram.REACTION,reaction_alpha),1.0 if m.has("reactions") else 1.2)
