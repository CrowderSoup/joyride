shader_type spatial;
// Stylized buildings: flat vertex-colored walls with procedural facades, storefront glass
// on the ground floor, a cornice band, and baked-looking AO at the base.
// UV  = (meters along the wall, meters up the wall)
// UV2 = (wall material, building height). Materials: 0 roof/plain prop, 1 punched windows,
//       2 glass curtain wall (vertex color tints the glass), 3 brick with small windows,
//       4 plain wall with a clerestory strip (warehouses).

uniform vec3 glass_color : source_color = vec3(0.13, 0.17, 0.24);
uniform vec3 glass_sky : source_color = vec3(0.55, 0.68, 0.82);

float band(float x, float lo, float hi) {
	float w = fwidth(x) * 0.75;
	return smoothstep(lo - w, lo + w, x) - smoothstep(hi - w, hi + w, x);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float mat = floor(UV2.x + 0.5);
	float is_wall = step(0.5, mat);
	float curtain = step(1.5, mat) * (1.0 - step(2.5, mat));
	float brick = step(2.5, mat) * (1.0 - step(3.5, mat));
	float plain = step(3.5, mat);
	float height = UV2.y;
	float x = UV.x;
	float y = UV.y;

	float house = step(height, 9.0);
	float col_w = mix(mix(3.2, 4.6, house), 2.6, brick);
	float floor_h = 3.5;
	float win = band(fract(x / col_w), mix(0.2, 0.3, brick), mix(0.8, 0.7, brick))
		* band(fract(y / floor_h), 0.3, mix(0.78, 0.72, brick));
	float store = band(fract(x / col_w), 0.05, 0.95) * band(y, 0.35, 2.9);
	win = mix(win, store, (1.0 - step(floor_h, y)) * (1.0 - house));
	// Curtain wall: all glass except thin mullions and a spandrel stripe at each floor.
	float glass_wall = (1.0 - band(fract(x / 1.6), 0.0, 0.06)) * (1.0 - band(fract(y / floor_h), 0.0, 0.12));
	win = mix(win, glass_wall, curtain);
	// Warehouses: one strip of clerestory windows near the top.
	win = mix(win, band(y, height - 3.2, height - 2.2) * band(fract(x / 6.0), 0.1, 0.9), plain);
	win *= 1.0 - smoothstep(height - 1.3, height - 1.0, y);
	win *= is_wall;
	// No windows in the foundation, where a building on a hill runs below its base.
	win *= step(0.0, y);

	// Each window pane gets its own shade so facades don't look like graph paper.
	vec2 cell = floor(vec2(x / col_w, y / floor_h));
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	// Fake sky reflection: panes facing up the view get lighter.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 pane = mix(glass_color, base * 0.55, curtain * 0.6);
	vec3 glass = mix(pane * (0.7 + 0.6 * h), glass_sky, fres * mix(0.6, 0.8, curtain));

	float ao = mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 4.0, y)), is_wall);
	float cornice = band(y, height - 0.9, height - 0.55) * is_wall * (1.0 - curtain);
	// Brick gets a faint course pattern.
	float courses = brick * band(fract(y / 0.6), 0.0, 0.08) * 0.12;
	vec3 wall = mix(base * ao * (1.0 - courses), base * 1.2, cornice);

	ALBEDO = mix(wall, glass, win);
	ROUGHNESS = mix(0.92, 0.12, win);
	SPECULAR = mix(0.25, 0.9, win);
	METALLIC = curtain * win * 0.3;
}
