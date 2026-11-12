shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float intensidade = 1.0;
uniform vec4 cor : source_color = vec4(1.0, 0.25, 0.05, 1.0);

void fragment() {
	float b = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float borda = smoothstep(0.09, 0.0, b);
	float listras = step(0.5, fract((UV.x + UV.y) * 4.0 - TIME * 1.4));
	float pulso = 0.6 + 0.4 * sin(TIME * 6.0);
	float a = (0.22 + listras * 0.16 + borda * 0.9) * pulso;
	ALBEDO = cor.rgb * a * 2.6 * intensidade;
	ALPHA = 1.0;
}
