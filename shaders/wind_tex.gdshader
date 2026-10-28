// Ветер для ассетов студии: тот же принцип, что wind.gdshader (качаем вершины, тем сильнее, чем выше),
// но материал берётся из пакета AstraForge: базовый цвет и рисованная подсветка (emission).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float amplitude = 0.06;     // метры у вершины
uniform float speed = 1.3;
uniform float height_ref = 5.0;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float roughness = 0.85;
uniform float flutter = 0.015;      // мелкая дрожь листвы
uniform float clip_below = -100.0;  // срезать «подставку» под деревом (локальная высота, м)

varying float local_y;

void vertex() {
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.83, 1.17));
	local_y = VERTEX.y;
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float gust = sin(TIME * speed + phase) + 0.45 * sin(TIME * speed * 2.1 + phase * 1.7);
	VERTEX.xz += normalize(wind_dir) * gust * amplitude * h * h;
	VERTEX += NORMAL * sin(TIME * 7.0 + dot(VERTEX, vec3(5.0, 7.0, 3.0)) + phase) * flutter * h;
}

void fragment() {
	if (local_y < clip_below) {
		discard;
	}
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = albedo.rgb * t.rgb;
	EMISSION = emission * texture(emission_tex, UV).rgb * emission_energy;
	ROUGHNESS = roughness;
}
