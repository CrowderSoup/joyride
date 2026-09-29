shader_type spatial;
// Stylized buildings: flat vertex-colored walls with a procedural window grid,
// storefront glass on the ground floor, a cornice band, and baked-looking AO at the base.
// UV  = (meters along the wall, meters up the wall)
// UV2 = (1.0 on walls / 0.0 on roofs, building height)

uniform vec3 glass_color : source_color = vec3(0.13, 0.17, 0.24);
uniform vec3 glass_sky : source_color = vec3(0.55, 0.68, 0.82);

float band(float x, float lo, float hi) {
	float w = fwidth(x) * 0.75;
	return smoothstep(lo - w, lo + w, x) - smoothstep(hi - w, hi + w, x);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float is_wall = UV2.x;
	float height = UV2.y;
	float x = UV.x;
	float y = UV.y;

	float house = step(height, 9.0);
	float col_w = mix(3.2, 4.6, house);
	float floor_h = 3.5;
	float win = band(fract(x / col_w), 0.2, 0.8) * band(fract(y / floor_h), 0.3, 0.78);
	float store = band(fract(x / col_w), 0.05, 0.95) * band(y, 0.35, 2.9);
	win = mix(win, store, (1.0 - step(floor_h, y)) * (1.0 - house));
	win *= 1.0 - smoothstep(height - 1.3, height - 1.0, y);
	win *= is_wall;

	// Each window pane gets its own shade so facades don't look like graph paper.
	vec2 cell = floor(vec2(x / col_w, y / floor_h));
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	// Fake sky reflection: panes facing up the view get lighter.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 glass = mix(glass_color * (0.7 + 0.6 * h), glass_sky, fres * 0.6);

	float ao = mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 4.0, y)), is_wall);
	float cornice = band(y, height - 0.9, height - 0.55) * is_wall;
	vec3 wall = mix(base * ao, base * 1.2, cornice);

	ALBEDO = mix(wall, glass, win);
	ROUGHNESS = mix(0.92, 0.12, win);
	SPECULAR = mix(0.25, 0.9, win);
}
