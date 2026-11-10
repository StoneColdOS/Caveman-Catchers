shader_type sky;
// Dark deco night sky: painted red going to near-black up high, black cloud streaks,
// and a big pale moon. Flat, like a background painted on black paper.

uniform vec3 moon_dir = vec3(0.4, 0.33, -0.85);
uniform vec3 horizon : source_color = vec3(0.95, 0.33, 0.16);
uniform vec3 middle : source_color = vec3(0.66, 0.08, 0.07);
uniform vec3 top : source_color = vec3(0.10, 0.02, 0.05);

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 col = mix(horizon, middle, smoothstep(-0.02, 0.22, y));
	col = mix(col, top, smoothstep(0.22, 0.75, y));
	// Long torn cloud streaks in black
	float az = atan(d.x, d.z);
	// thin bands across the sky, broken up along their length
	float band = sin(y * 70.0 + sin(az * 3.0) * 2.5 + az * 1.2);
	float breakup = sin(az * 2.3 + y * 9.0) * 0.6 + sin(az * 5.7 - y * 14.0) * 0.4;
	float streak = smoothstep(0.55, 0.85, band) * smoothstep(0.1, 0.45, breakup)
		* smoothstep(0.06, 0.14, y) * (1.0 - smoothstep(0.42, 0.6, y));
	col = mix(col, vec3(0.03, 0.0, 0.015), streak * 0.92);
	// Moon: a flat pale disc with a soft warm halo
	float md = dot(d, normalize(moon_dir));
	col += vec3(1.0, 0.62, 0.45) * pow(max(md, 0.0), 160.0) * 0.45;
	col = mix(col, vec3(1.0, 0.96, 0.86), smoothstep(0.9983, 0.9987, md));
	if (y < -0.02) {
		col = vec3(0.04, 0.01, 0.03);
	}
	COLOR = col;
}
