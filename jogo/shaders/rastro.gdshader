shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float progresso = 0.0;
uniform float comprimento = 0.5;
uniform vec4 cor : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float intensidade = 4.5;

void fragment() {
	float d = progresso - UV.x;
	float a = d >= 0.0 ? clamp(1.0 - d / comprimento, 0.0, 1.0) : 0.0;
	a = a * a;
	float faixa = smoothstep(0.0, 0.45, UV.y) * smoothstep(1.0, 0.82, UV.y);
	float fio = smoothstep(0.7, 0.95, UV.y) * smoothstep(1.0, 0.95, UV.y);
	float fim = 1.0 - smoothstep(0.9, 1.35, progresso);
	vec3 c = mix(cor.rgb, vec3(1.0, 0.97, 0.9), fio);
	float alfa = (faixa * 0.8 + fio) * a * fim;
	ALBEDO = c * intensidade * alfa;
	ALPHA = alfa;
}
