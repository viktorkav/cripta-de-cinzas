shader_type canvas_item;

uniform float forca = 0.55;
uniform vec4 cor : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float dano = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 0.85;
	float v = smoothstep(0.55, 1.45, length(p));
	vec3 c = mix(cor.rgb, vec3(0.45, 0.0, 0.0), dano);
	COLOR = vec4(c, clamp(v * forca + v * dano * 0.6, 0.0, 1.0));
}
