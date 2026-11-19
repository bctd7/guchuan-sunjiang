shader_type canvas_item;
render_mode unshaded;

uniform vec2 rect_size = vec2(100.0);
uniform float corner_radius = 10.0;

void fragment() {
	vec4 sampled = COLOR;
	float radius = min(corner_radius, min(rect_size.x, rect_size.y) * 0.5);
	vec2 q = abs((UV - vec2(0.5)) * rect_size) - rect_size * 0.5 + vec2(radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	sampled.a *= 1.0 - smoothstep(-0.75, 0.75, distance_to_edge);
	COLOR = sampled;
}
