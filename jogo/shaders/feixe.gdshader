shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec4 cor : source_color = vec4(0.55, 0.65, 1.0, 1.0);
uniform float intensidade = 0.25;
uniform float velocidade = 0.05;

void fragment() {
	float n = texture(ruido, vec2(UV.x * 2.0, UV.y * 0.6 - TIME * velocidade)).r;
	float lados = pow(sin(UV.x * 3.14159), 2.0);
	float vertical = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float a = lados * vertical * (0.55 + n * 0.6);
	float fres = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = cor.rgb * intensidade * a * fres;
	ALPHA = 1.0;
}
