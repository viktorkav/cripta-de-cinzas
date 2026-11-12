shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float preenchimento = 0.16;
uniform float intensidade = 1.6;
varying vec4 cor;

void vertex() {
	cor = COLOR;
}

void fragment() {
	float b = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float borda = smoothstep(0.075, 0.015, b);
	float brilho_borda = smoothstep(0.16, 0.0, b) * 0.35;
	float pulso = 0.78 + 0.22 * sin(TIME * 3.2);
	float a = preenchimento + (borda + brilho_borda) * pulso;
	ALBEDO = cor.rgb * a * intensidade * cor.a;
	ALPHA = 1.0;
}
