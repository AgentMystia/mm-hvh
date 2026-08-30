shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 albedo : source_color = vec4(0.3, 1.0, 0.4, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
