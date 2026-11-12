shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 cor : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform float raio = 0.42;
uniform float espessura = 0.05;
uniform float intensidade = 2.5;
uniform float tracos = 0.0;
uniform float giro = 0.6;
uniform float runas = 0.0;
uniform float alfa = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x) + TIME * giro;
	float anel = smoothstep(espessura, 0.0, abs(r - raio * 2.0));
	if (tracos > 0.0) {
		anel *= step(0.35, fract(ang / 6.2831853 * tracos));
	}
	float brilho = smoothstep(raio * 2.0, 0.0, r) * 0.08;
	float rr = 0.0;
	if (runas > 0.0) {
		float a2 = atan(p.y, p.x) - TIME * giro * 0.5;
		float aneis = smoothstep(0.012, 0.0, abs(r - 0.62)) + smoothstep(0.012, 0.0, abs(r - 0.95));
		float marcas = step(0.8, fract(a2 / 6.2831853 * 24.0)) * step(0.66, r) * step(r, 0.91);
		float estrela = 0.0;
		for (int i = 0; i < 5; i++) {
			float t = float(i) * 2.5132741 + TIME * giro * 0.3;
			vec2 a = vec2(cos(t), sin(t)) * 0.6;
			vec2 b = vec2(cos(t + 2.5132741 * 2.0), sin(t + 2.5132741 * 2.0)) * 0.6;
			vec2 pa = p - a, ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			estrela += smoothstep(0.012, 0.0, length(pa - ba * h));
		}
		rr = (aneis + marcas * 0.8 + estrela * 0.8) * runas * step(r, 1.0);
	}
	float a = (anel + brilho + rr) * alfa;
	ALBEDO = cor.rgb * intensidade * a;
	ALPHA = 1.0;
}
