shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 cor : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform float intensidade = 3.0;

void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	float m = max(p.x, p.y);
	float borda = smoothstep(0.86, 0.92, m) * smoothstep(1.0, 0.96, m);
	float canto = step(0.55, min(p.x, p.y));
	float pulso = 0.8 + 0.2 * sin(TIME * 5.0);
	float a = borda * (0.35 + canto * 0.65) * pulso + smoothstep(0.9, 0.0, m) * 0.06;
	ALBEDO = cor.rgb * intensidade * a;
	ALPHA = 1.0;
}
