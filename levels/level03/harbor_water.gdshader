shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec2 harbor_position;

void vertex() {
	harbor_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = harbor_position;
	float drift = TIME * 0.65;
	float swell = 0.52*sin(p.x*0.7 + p.y*2.1 + drift) + 0.28*sin(p.x*2.1 - p.y*0.8 + 0.6*drift) + 0.20*cos(p.y*3.1 - p.x*1.3);
	float ripples = sin(p.y * 14.0 + swell * 1.8 + sin(p.x * 1.8 - drift));
	float glints = smoothstep(0.91, 1.0, ripples) * smoothstep(0.38, 0.89, sin(p.x * 3.4 + p.y + drift));
	vec3 water = mix(vec3(0.32,0.55,0.55),vec3(0.40,0.62,0.60),0.5 + 0.5*swell);
	ALBEDO = mix(water,vec3(0.78,0.85,0.76),glints*0.24);
}
