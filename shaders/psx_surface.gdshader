shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// PSX surface: the two things that make PS1 3D look wobbly and cheap.
//  1. Vertex snapping: corners snap to a coarse screen grid, so shapes jitter
//     and swim a little as the camera moves (the PS1 had no sub-pixel precision).
//  2. Affine texture mapping: textures are stretched across each triangle without
//     perspective correction, so they warp and slide on big faces up close.
// Textures are mapped from the mesh's own position (no UVs needed) and use the
// chunky 16x16 pixel textures with nearest filtering.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tex_scale = 1.4;
uniform float snap_rows = 280.0;   // lower = more jitter (dialed back for readability)
uniform float affine = 0.35;       // 1 = full PS1 texture warp, 0 = correct
uniform float tex_amount = 0.3;    // how much the pixel texture shows (flat painted look)

varying vec3 uv_w;   // (uv * w, w): interpolates into affine (non-perspective) uvs

void vertex() {
	// Pick the flat axis from the face normal (faces are flat, so this is stable per face).
	vec3 an = abs(NORMAL);
	vec2 uv;
	if (an.x >= an.y && an.x >= an.z) {
		uv = VERTEX.zy;
	} else if (an.y >= an.z) {
		uv = VERTEX.xz;
	} else {
		uv = VERTEX.xy;
	}
	uv *= tex_scale;

	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_rows * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), snap_rows) * 0.5;
	if (clip.w > 0.0) {
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, clip.w, affine);
	uv_w = vec3(uv * w, w);
}

void fragment() {
	vec2 uv = uv_w.xy / uv_w.z;
	ALBEDO = albedo.rgb * mix(vec3(1.0), texture(tex, uv).rgb, tex_amount);
	ROUGHNESS = 1.0;
}

// Dark deco lighting: light falls in flat bands with hard edges, like a painted
// background. Unlit sides drop into the ambient (deep indigo) almost straight away.
void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float band = smoothstep(0.03, 0.07, lit) * 0.5 + smoothstep(0.32, 0.38, lit) * 0.5;
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
