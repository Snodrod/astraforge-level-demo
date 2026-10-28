// Земля v3: бесшовные рисованные текстуры из AstraForge (вкладка «VFX» → Material Maker):
// трава, земля, песок. Смешиваются по уклону, высоте и расстоянию до реки.
// Triplanar: на склонах холмов текстура не растягивается. Крупный шум ломает повтор плитки.
shader_type spatial;

uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float tile = 0.16;               // 1 / размер плитки в метрах
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform float sand_edge = 4.0;           // где у реки кончается песок, м от оси
uniform float rock_slope = 0.42;

varying vec3 wpos;
varying vec3 wnrm;

vec3 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

float river_x(float z) {
	return 3.0 + 4.5 * sin(z * 0.10) + 1.5 * sin(z * 0.23 + 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(wnrm);
	float broad = texture(noise_tex, wpos.xz * 0.012).r;
	float mid = texture(noise_tex, wpos.xz * 0.07 + 0.37).r;
	vec3 g = tri(grass_tex, wpos, n, tile) * grass_tint;
	vec3 g2 = tri(grass_tex, wpos * 0.43 + 11.0, n, tile);              // второй масштаб — без видимого повтора
	g = mix(g, g2, 0.35);
	g *= mix(vec3(0.86, 0.95, 0.80), vec3(1.10, 1.06, 0.88), smoothstep(0.3, 0.7, broad));   // тёплые и холодные пятна
	vec3 dr = tri(dirt_tex, wpos, n, tile * 1.2);
	vec3 sd = tri(sand_tex, wpos, n, tile * 1.4);

	float slope = 1.0 - n.y;
	float d = abs(wpos.x - river_x(wpos.z)) + (mid - 0.5) * 1.4;
	float sand_w = 1.0 - smoothstep(sand_edge - 0.6, sand_edge + 0.5, d);
	float dirt_w = smoothstep(0.16, 0.30, slope) * 0.8 + smoothstep(0.78, 0.9, mid) * 0.35;
	float rock_w = smoothstep(rock_slope, rock_slope + 0.12, slope);

	vec3 col = mix(g, dr, clamp(dirt_w, 0.0, 1.0));
	col = mix(col, vec3(0.56, 0.54, 0.50) * (0.8 + 0.4 * mid), rock_w);
	col = mix(col, sd, sand_w);
	col *= mix(1.0, 0.72, smoothstep(-0.2, -1.4, wpos.y));    // мокрый песок у дна темнее
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
