// Вода-река: материал, который двигается сам. Модели и анимации не нужно.
// Шум сдвигается по времени вдоль течения (рябь), цвет зависит от глубины,
// по Френелю у воды появляется отражение неба, у берега — светлая пена.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D noise_tex : repeat_enable, filter_linear;                 // бесшовный шум (даёт генератор текстур)
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 shallow_color : source_color = vec4(0.42, 0.72, 0.80, 0.55);   // у берега
uniform vec4 deep_color : source_color = vec4(0.231, 0.498, 0.659, 0.93);   // #3b7fa8
uniform vec4 sky_color : source_color = vec4(0.72, 0.84, 0.96, 1.0);        // что отражается на скользящем угле
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform vec2 flow_dir = vec2(0.0, 1.0);        // куда течёт (по оси Z)
uniform float flow_speed = 0.05;               // медленная вода выглядит дороже
uniform float noise_scale = 0.11;
uniform float ripple = 6.0;                    // сила мягкой ряби
uniform float depth_range = 1.6;               // глубина, на которой вода становится «глубокой»
uniform float foam_width = 0.4;                // ширина пены, метры

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// два слоя шума плывут с разной скоростью, из них получается рябь
	vec2 uv = world_pos.xz * noise_scale + flow_dir * TIME * flow_speed;
	vec2 uv2 = world_pos.xz * noise_scale * 1.9 + flow_dir * TIME * flow_speed * 0.6;
	float n = (texture(noise_tex, uv).r + texture(noise_tex, uv2).r) * 0.5;
	float nx = (texture(noise_tex, uv + vec2(0.01, 0.0)).r + texture(noise_tex, uv2 + vec2(0.019, 0.0)).r) * 0.5;
	float nz = (texture(noise_tex, uv + vec2(0.0, 0.01)).r + texture(noise_tex, uv2 + vec2(0.0, 0.019)).r) * 0.5;
	NORMAL_MAP = vec3(0.5 + (n - nx) * ripple, 0.5 + (n - nz) * ripple, 1.0);   // нормаль из градиента шума

	// толщина воды под взглядом = расстояние до дна по глубине сцены
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float thick = max(VERTEX.z - p.z / p.w, 0.0);

	float k = clamp(thick / depth_range, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, k) + (n - 0.5) * 0.10;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);       // Френель
	col = mix(col, sky_color.rgb, fres * 0.65);
	float foam = 1.0 - smoothstep(0.0, foam_width, thick + (n - 0.5) * 0.3);
	foam += smoothstep(0.78, 0.9, n) * 0.25 * (1.0 - k);                    // редкие барашки
	foam = clamp(foam, 0.0, 1.0);

	ALBEDO = mix(col, foam_color.rgb, foam);
	ALPHA = clamp(mix(mix(shallow_color.a, deep_color.a, k), 1.0, foam) + fres * 0.3, 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.6, foam);          // гладкая вода отражает небо, пена матовая
	SPECULAR = 0.9;
}
