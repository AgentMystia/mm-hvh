shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.2, 0.9, 0.35, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
