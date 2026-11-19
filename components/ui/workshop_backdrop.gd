extends CanvasLayer
## Shared muted workshop backdrop. Chapters provide only the source image.
var image_texture: Texture2D=preload("res://assets/images/shared/shipyard_background.png")
func _ready() -> void:
	layer=-10
	var image:=TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture=image_texture
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""
shader_type canvas_item;
void fragment() {
	vec2 texel=TEXTURE_PIXEL_SIZE * 2.5;
	vec3 c=texture(TEXTURE,UV).rgb * .36;
	c+=(texture(TEXTURE,UV+vec2(texel.x,0)).rgb+texture(TEXTURE,UV-vec2(texel.x,0)).rgb+texture(TEXTURE,UV+vec2(0,texel.y)).rgb+texture(TEXTURE,UV-vec2(0,texel.y)).rgb)*.16;
	float gray=dot(c,vec3(.299,.587,.114));
	c=mix(vec3(gray),c,.36);
	c=(c-.5)*.55+.5;
	c=mix(c,vec3(.40,.35,.28),.38)*.82;
	COLOR=vec4(c,1.0);
}
"""
	var treatment:=ShaderMaterial.new()
	treatment.shader=shader
	image.material=treatment
	add_child(image)
