shader_type canvas_item;

uniform float nivel : hint_range(0.0, 1.0) = 1.0;
uniform float nivel_atraso : hint_range(0.0, 1.0) = 1.0;
uniform vec4 cor_a : source_color = vec4(0.85, 0.08, 0.06, 1.0);
uniform vec4 cor_b : source_color = vec4(0.22, 0.0, 0.01, 1.0);
uniform vec4 cor_atraso : source_color = vec4(0.95, 0.85, 0.7, 1.0);
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float borda_aa = smoothstep(1.0, 0.97, r);
	float onda = sin(p.x * 5.0 + TIME * 2.0) * 0.03 + sin(p.x * 12.0 - TIME * 3.3) * 0.012;
	float sup = 1.0 - nivel * 2.0 + onda;
	float sup_atraso = 1.0 - nivel_atraso * 2.0 + onda * 0.5;
	float esfera = sqrt(max(0.0, 1.0 - r * r));
	vec3 vidro = vec3(0.025, 0.02, 0.022) + vec3(0.04) * esfera;
	vec2 q = p * 0.6 + vec2(TIME * 0.03, -TIME * 0.05);
	float n = texture(ruido, q).r;
	float n2 = texture(ruido, p * 0.9 + vec2(-TIME * 0.04, TIME * 0.02)).r;
	vec3 liquido = mix(cor_b.rgb, cor_a.rgb, clamp(n * 0.7 + n2 * 0.5 + esfera * 0.35 - 0.15, 0.0, 1.0));
	liquido *= 0.55 + esfera * 0.7;
	float dentro = smoothstep(sup - 0.01, sup + 0.01, p.y);
	float dentro_atraso = smoothstep(sup_atraso - 0.01, sup_atraso + 0.01, p.y) * (1.0 - dentro);
	float linha = smoothstep(0.05, 0.0, abs(p.y - sup)) * step(0.001, nivel) * step(nivel, 0.999);
	vec3 c = vidro;
	c = mix(c, cor_atraso.rgb * 0.55 * (0.5 + esfera * 0.5), dentro_atraso * 0.8);
	c = mix(c, liquido, dentro);
	c += cor_a.rgb * linha * 0.8;
	float brilho = smoothstep(0.42, 0.0, length(p - vec2(-0.32, -0.42))) * 0.45;
	brilho += smoothstep(0.1, 0.0, abs(r - 0.82)) * smoothstep(0.2, -0.6, p.y) * 0.08;
	c += vec3(brilho);
	c *= mix(1.0, 0.45, smoothstep(0.75, 1.0, r));
	COLOR = vec4(c, borda_aa);
}
