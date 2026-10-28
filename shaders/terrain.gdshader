// Земля: трава / земля / песок / камень смешиваются по высоте, уклону и расстоянию до реки.
// Текстуры «triplanar»: бесшовный шум берётся с трёх сторон, поэтому на склонах нет растяжения.
shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 grass_a : source_color = vec3(0.498, 0.702, 0.290);   // #7fb34a
uniform vec3 grass_b : source_color = vec3(0.640, 0.780, 0.300);   // подсвеченная
uniform vec3 dirt_c : source_color = vec3(0.545, 0.404, 0.267);
uniform vec3 sand_c : source_color = vec3(0.830, 0.740, 0.500);
uniform vec3 rock_c : source_color = vec3(0.604, 0.584, 0.549);    // #9a958c

varying vec3 wpos;
varying vec3 wnrm;

float tri(vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(noise_tex, p.yz * s).r * w.x + texture(noise_tex, p.xz * s).r * w.y + texture(noise_tex, p.xy * s).r * w.z;
}

// та же формула оси реки, что в level_terrain.gd
float river_x(float z) {
	return 3.0 + 4.5 * sin(z * 0.10) + 1.5 * sin(z * 0.23 + 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(wnrm);
	float broad = tri(wpos, n, 0.035);     // крупные пятна
	float mid = tri(wpos, n, 0.3);
	float fine = tri(wpos, n, 1.7);        // мелкое зерно

	vec3 grass = mix(grass_a, grass_b, smoothstep(0.35, 0.65, broad));
	grass *= 0.86 + 0.28 * mid;
	grass += (fine - 0.5) * 0.06;
	grass = mix(grass, grass * vec3(1.05, 1.0, 0.8), smoothstep(0.6, 0.8, mid) * 0.5);   // сухие пятна

	float slope = 1.0 - n.y;
	float d = abs(wpos.x - river_x(wpos.z)) + (broad - 0.5) * 1.6;
	float sand_w = 1.0 - smoothstep(4.7, 5.9, d);
	float dirt_w = max(smoothstep(0.10, 0.22, slope), smoothstep(0.80, 0.92, mid) * 0.6);
	float rock_w = smoothstep(0.30, 0.42, slope);

	vec3 col = mix(grass, dirt_c * (0.8 + 0.4 * fine), dirt_w);
	col = mix(col, rock_c * (0.8 + 0.4 * mid), rock_w);
	col = mix(col, sand_c * (0.9 + 0.2 * fine), sand_w);
	col *= mix(1.0, 0.82, smoothstep(0.0, -1.2, wpos.y));      // мокрее и темнее у дна
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
