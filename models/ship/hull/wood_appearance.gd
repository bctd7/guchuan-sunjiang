extends RefCounted
## Reuse chapter-one/classroom timber finish without changing triangles or state.
const Surface=preload("res://models/ship/hull/wood_surface.gd")
const Look=preload("res://components/teaching/classroom/display/workshop_look.gd")
const COLORS=[Color("b89569"),Color("dcc29b"),Color("9e805d")]
const DISPLAY_COLORS=[Color("c1a078"),Color("cfb083"),Color("ad8961")]
static var _grain: NoiseTexture2D

static func grain_texture() -> NoiseTexture2D:
	if _grain==null:
		# Keep the existing fibre pattern, with a light, low-contrast finish.
		# Multiplying dark timber by dark grain hid the tongue and groove faces.
		_grain=Look.grain_texture().duplicate() as NoiseTexture2D
		var ramp:=Gradient.new()
		ramp.colors=PackedColorArray([Color("d9cdb9"),Color.WHITE])
		_grain.color_ramp=ramp
	return _grain

static func apply(node: Node,axis:=Vector3.ZERO,pose:=Transform3D.IDENTITY) -> void:
	if node.has_meta("wood_axis"):
		axis=node.get_meta("wood_axis");pose=Transform3D.IDENTITY
	if node is MeshInstance3D:
		var source=node.material_override as StandardMaterial3D
		if source!=null:
			var index: int=COLORS.find(Color(source.albedo_color,1.0))
			if index>=0:
				var material=source.duplicate() as StandardMaterial3D
				Look.configure_wood(material,index,node.mesh)
				material.albedo_color=DISPLAY_COLORS[index]
				material.albedo_texture=grain_texture()
				material.albedo_color.a=1.0
				material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
				if axis.length_squared()>.5:
					node.mesh=Surface.bake(node.mesh,pose,axis)
					material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE
				node.material_override=material
	for child in node.get_children():apply(child,axis,pose*child.transform if child is Node3D else pose)

