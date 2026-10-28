// Вода в пиксель-арте. Спрайт воды рисуется по маске: A = вода, G = мелководье, R = пена у берега.
// Шум сдвигается по времени (течение), цвет — три ступени общей палитры, поверх блики и пена.
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform vec4 c_deep : source_color = vec4(0.231, 0.498, 0.659, 1.0);    // #3b7fa8
uniform vec4 c_mid : source_color = vec4(0.318, 0.600, 0.745, 1.0);
uniform vec4 c_light : source_color = vec4(0.480, 0.730, 0.830, 1.0);
uniform vec4 c_shallow : source_color = vec4(0.560, 0.820, 0.830, 1.0);  // у берега теплее и светлее
uniform vec4 c_spark : source_color = vec4(0.930, 0.980, 1.0, 1.0);      // блики солнца
uniform vec2 flow_dir = vec2(0.0, 1.0);
uniform float flow_speed = 0.03;
uniform float noise_scale = 0.014;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a < 0.5) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = floor(wpos) * noise_scale;                       // шум привязан к пикселям картинки
		vec2 f = flow_dir * TIME * flow_speed;
		float n = (texture(noise_tex, p + f).r + texture(noise_tex, p * 2.1 - f * 0.7).r) * 0.5;
		vec3 col = c_deep.rgb;
		col = mix(col, c_mid.rgb, step(0.46, n));
		col = mix(col, c_light.rgb, step(0.64, n));
		col = mix(col, c_shallow.rgb, m.g * step(0.42, n) * 0.8);
		// блики: редкие светлые пиксели, мигают по времени
		float sp = texture(noise_tex, floor(wpos / 2.0) * 0.041 + vec2(TIME * 0.015, 0.0)).r;
		col = mix(col, c_spark.rgb, step(0.87, sp) * step(0.5, fract(TIME * 0.6 + sp * 11.0)));
		// пена у берега рваными полосками
		float foam = m.r * step(0.42, fract(n * 6.0 + TIME * 0.4));
		col = mix(col, c_spark.rgb, foam);
		COLOR = vec4(col, 1.0);
	}
}
