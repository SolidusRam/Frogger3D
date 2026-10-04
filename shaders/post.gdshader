// Post-processing a tutto schermo per gli stili grafici.
// mode 0: nessun effetto (serve solo per il lampo invertito)
// mode 1: PS1 - pixel grossi, colori ridotti, retinatura ordinata
// mode 2: arcade - schermo curvo, scanline, aberrazione cromatica, vignettatura
// flash: 1 inverte i colori, per il cambio di livello del calore.
shader_type canvas_item;

uniform sampler2D screen_nearest : hint_screen_texture, filter_nearest;
uniform sampler2D screen_linear : hint_screen_texture, filter_linear;
uniform int mode = 0;
uniform float flash = 0.0;

uniform float pixel_size = 3.0;
uniform float color_levels = 24.0;

uniform float curvature = 0.08;
uniform float scanlines = 0.25;
uniform float aberration = 0.0015;
uniform float vignette = 0.45;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 ps1(vec2 frag_coord, vec2 texel) {
	// pixel_size vale a 720 righe: a risoluzioni più alte i pixel crescono,
	// così la grana resta la stessa.
	float size = max(1.0, floor(pixel_size / (texel.y * 720.0) + 0.5));
	vec2 cell = floor(frag_coord / size);
	vec2 uv = (cell + 0.5) * size * texel;
	vec3 color = textureLod(screen_nearest, uv, 0.0).rgb;
	int index = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	float dither = (BAYER[index] / 16.0 - 0.5) / color_levels;
	return floor((color + dither) * color_levels + 0.5) / color_levels;
}

vec3 arcade(vec2 screen_uv, vec2 frag_coord) {
	// Schermo curvo: i bordi si piegano verso l'esterno.
	vec2 centered = screen_uv * 2.0 - 1.0;
	centered *= 1.0 + curvature * dot(centered, centered);
	vec2 uv = centered * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	vec2 shift = vec2(aberration, 0.0) * length(centered);
	vec3 color = vec3(
		textureLod(screen_linear, uv + shift, 0.0).r,
		textureLod(screen_linear, uv, 0.0).g,
		textureLod(screen_linear, uv - shift, 0.0).b);
	float line = 0.5 + 0.5 * sin(frag_coord.y * 3.14159);
	color *= 1.0 - scanlines * (1.0 - line);
	color *= 1.0 - vignette * pow(length(centered) * 0.7, 2.0);
	return color;
}

void fragment() {
	vec3 color;
	if (mode == 1) {
		color = ps1(FRAGCOORD.xy, SCREEN_PIXEL_SIZE);
	} else if (mode == 2) {
		color = arcade(SCREEN_UV, FRAGCOORD.xy);
	} else {
		color = textureLod(screen_linear, SCREEN_UV, 0.0).rgb;
	}
	color = mix(color, vec3(1.0) - color, flash);
	COLOR = vec4(color, 1.0);
}
