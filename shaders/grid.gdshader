// Серая сетка пустой сцены (начало ролика).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.29, 0.30, 0.32, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.47, 0.50, 1.0);
uniform float cell = 1.0;
uniform float major = 5.0;   // каждая пятая линия ярче

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float size) {
	vec2 g = abs(fract(p / size - 0.5) - 0.5) / fwidth(p / size);
	return 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
}

void fragment() {
	float minor_l = grid(wpos.xz, cell) * 0.55;
	float major_l = grid(wpos.xz, cell * major);
	float l = max(minor_l, major_l);
	// сетка растворяется вдали
	float fade = 1.0 - smoothstep(18.0, 45.0, length(wpos.xz));
	ALBEDO = mix(base_color.rgb, line_color.rgb, l * fade);
	ROUGHNESS = 1.0;
}
