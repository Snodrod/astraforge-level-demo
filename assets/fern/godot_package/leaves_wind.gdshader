// AstraForge: leaf cards — alpha scissor + wind sway.
// UV2.x = wind weight (0 at the trunk, 1 at the crown edge), UV2.y = per-card phase; COLOR = per-card tint.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.35);
uniform float wind_strength : hint_range(0.0, 0.5) = 0.07;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.4;
uniform float flutter : hint_range(0.0, 0.2) = 0.025;
void vertex() {
	float w = UV2.x;
	float ph = UV2.y * 6.28318;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.25 + ph * 0.3);
	float flut = sin(TIME * wind_speed * 4.3 + ph) * flutter;
	VERTEX += normalize(wind_direction) * sway * wind_strength * w + NORMAL * flut * w;
}
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.3, 0.12);
}
