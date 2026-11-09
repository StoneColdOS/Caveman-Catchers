shader_type canvas_item;
// PS1 look: render at a low resolution (chunky pixels) with limited color
// depth and ordered dithering, like 15-bit color on the original hardware.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_height = 200.0;   // pretend vertical resolution (PS1 ran 240; lower = chunkier)
uniform float color_levels = 24.0;    // steps per color channel (lower = more banding)

const float BAYER[16] = {
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
};

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 res = vec2(pixel_height * aspect, pixel_height);
	vec2 cell = floor(SCREEN_UV * res);
	vec3 c = texture(screen_tex, (cell + 0.5) / res).rgb;
	int i = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float d = BAYER[i] / 16.0 - 0.5;
	c = floor(c * color_levels + d + 0.5) / color_levels;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
