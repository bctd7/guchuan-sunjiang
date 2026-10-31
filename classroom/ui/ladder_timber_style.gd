extends RefCounted
## Grain and light only. Every original control metric and silhouette is retained.
static var _grain_texture: Texture2D

class TimberFace extends StyleBox:
	var face: StyleBoxFlat
	var grain: StyleBoxTexture
	func _get_minimum_size() -> Vector2:
		return face.get_minimum_size() if face else Vector2.ZERO
	func _draw(canvas_item: RID, rect: Rect2) -> void:
		face.draw(canvas_item,rect)
		grain.draw(canvas_item,rect)

static func apply(theme: Theme) -> void:
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var original=theme.get_stylebox(state,kind) as StyleBoxFlat
			if original==null: continue
			var face=original.duplicate() as StyleBoxFlat
			var down: bool=state in ["pressed","hover_pressed"]
			face.shadow_color=Color(.28,.18,.08,.10 if down else .18)
			face.shadow_size=2 if down else 7
			face.shadow_offset=Vector2(0,1 if down else 4)
			var texture=StyleBoxTexture.new()
			texture.texture=_grain()
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: texture.set_texture_margin(side,20)
			texture.modulate_color=Color(1,1,1,.40 if state=="disabled" else .95)
			var timber=TimberFace.new()
			timber.face=face
			timber.grain=texture
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: timber.set_content_margin(side,original.get_content_margin(side))
			theme.set_stylebox(state,kind,timber)

static func _grain() -> Texture2D:
	if _grain_texture: return _grain_texture
	const W=256
	const H=128
	var image=Image.create(W,H,false,Image.FORMAT_RGBA8)
	var noise=FastNoiseLite.new()
	noise.seed=1739
	noise.frequency=.09
	noise.fractal_octaves=3
	for y in H:
		for x in W:
			var point=Vector2(x+.5,y+.5)
			var nearest=point.clamp(Vector2(18,18),Vector2(W-18,H-18))
			var cover=clampf(16.0-point.distance_to(nearest),0,1)
			if x<2 or x>=W-2 or y<2 or y>=H-4: cover=0
			var wave=y+sin(x*.018+y*.031)*2.0+sin(x*.047)*.65
			var fiber=sin(wave*.64+noise.get_noise_2d(x*.22,y*1.5)*2.2)
			var value=fiber*.58+noise.get_noise_2d(x*.24,y*3.6)*.42
			var tone=Color("57371b") if value<0 else Color("fff0cf")
			tone.a=absf(value)*(.105 if value<0 else .17)*cover
			# A narrow face highlight reads as worn, softly lit timber.
			if y<5 and cover>0:
				tone=Color(1.0,.94,.80,(5.0-y)*.035*cover)
			image.set_pixel(x,y,tone)
	_grain_texture=ImageTexture.create_from_image(image)
	return _grain_texture
