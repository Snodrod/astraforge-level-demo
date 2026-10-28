// Небо: градиент, облака (шум в несколько слоёв, плывут по ветру), солнце со свечением.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.20, 0.45, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.95, 0.86, 0.72);
uniform vec3 ground_color : source_color = vec3(0.45, 0.55, 0.38);
uniform float cloud_cover = 0.52;
uniform float cloud_speed = 0.004;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(up, 0.45));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-dir.y * 5.0, 0.0, 1.0));
	} else {
		vec2 uv = dir.xz / (dir.y + 0.18) * 0.9 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv);
		float c = smoothstep(cloud_cover, cloud_cover + 0.22, n) * smoothstep(0.0, 0.2, dir.y);
		float lit = smoothstep(0.3, 0.8, fbm(uv + LIGHT0_DIRECTION.xz * 0.15));   // светлая сторона облака
		vec3 cloud = mix(vec3(0.70, 0.76, 0.88), vec3(1.0, 0.98, 0.94), lit);
		col = mix(col, cloud, c * 0.92);
	}
	float s = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.18);
	COLOR = col;
}
