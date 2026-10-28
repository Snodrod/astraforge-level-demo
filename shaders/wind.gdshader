// Ветер для деревьев и травы: качает вершины, чем выше точка, тем сильнее.
// Основание (y = 0) стоит на месте, поэтому студия ставит модель ровно на ноль.
// Амплитуда — сантиметры, фаза своя у каждого экземпляра: лес колышется волной.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(0.247, 0.490, 0.227, 1.0);   // листва #3f7d3a
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable; // текстура ассета (если есть)
uniform float amplitude = 0.05;     // метры у вершины
uniform float speed = 1.6;
uniform float height_ref = 4.0;     // высота, на которой качание максимально
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float roughness = 0.9;

varying vec3 tint;

void vertex() {
	// своя фаза на экземпляр: берём позицию экземпляра в мире
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.83, 1.17));
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);        // 0 у земли, 1 наверху
	float gust = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 2.3 + phase * 1.7 + VERTEX.x * 2.0);
	VERTEX.xz += normalize(wind_dir) * gust * amplitude * h * h;
	tint = COLOR.rgb;                                          // оттенок экземпляра (MultiMesh)
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb * tint;
	ROUGHNESS = roughness;
}
