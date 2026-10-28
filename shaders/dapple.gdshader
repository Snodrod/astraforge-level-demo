// Мягкие пятна света и тени облаков по земле: медленно плывут, привязаны к пикселям.
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float strength = 0.13;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(wpos / 3.0) * 3.0 * 0.0022 + vec2(TIME * 0.004, TIME * 0.0015);
	float n = texture(noise_tex, p).r;
	float shade = smoothstep(0.52, 0.72, n);
	float light = smoothstep(0.30, 0.18, n);
	COLOR = vec4(mix(vec3(0.10, 0.16, 0.30), vec3(1.0, 0.95, 0.7), light), (shade + light * 0.6) * strength);
}
