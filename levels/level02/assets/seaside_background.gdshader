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
