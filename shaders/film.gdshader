shader_type canvas_item;
// Old cartoon film: sepia with a hint of the original color, grain at 12 fps,
// flicker, the odd vertical scratch, and a vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float keep_color = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(l * 1.08 + 0.04, l * 0.97 + 0.02, l * 0.78);
	vec3 col = mix(sepia, c, keep_color);
	col = (col - 0.5) * 1.12 + 0.5;

	float frame = floor(TIME * 12.0);
	col += (hash(floor(uv * vec2(480.0, 270.0)) + frame) - 0.5) * 0.1;
	col *= 0.94 + 0.06 * hash(vec2(frame, 1.7));

	if (hash(vec2(frame, 9.2)) > 0.55) {
		float x = hash(vec2(frame, 3.1));
		col = mix(col, vec3(0.95, 0.9, 0.8), smoothstep(0.0018, 0.0, abs(uv.x - x)) * 0.55);
	}
	if (hash(vec2(frame, 5.5)) > 0.8) {
		float x = hash(vec2(frame, 7.7));
		col = mix(col, vec3(0.1, 0.08, 0.06), smoothstep(0.0012, 0.0, abs(uv.x - x)) * 0.5);
	}

	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 1.2;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
