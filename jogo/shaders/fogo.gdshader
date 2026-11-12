shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec4 cor_quente : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform vec4 cor_fria : source_color = vec4(0.95, 0.28, 0.04, 1.0);
uniform float intensidade = 2.6;
uniform float suavidade = 0.45;
varying float semente;

void vertex() {
	semente = INSTANCE_CUSTOM.x * 3.7 + float(INSTANCE_ID) * 0.37;
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	float n = texture(ruido, uv * vec2(0.55, 0.45) + vec2(semente, -TIME * 0.85)).r;
	float n2 = texture(ruido, uv * vec2(1.1, 0.9) + vec2(-semente * 0.7, -TIME * 1.6)).r;
	vec2 c = (uv - vec2(0.5, 0.62)) * vec2(2.0, 1.5);
	float forma = 1.0 - length(c);
	forma += (n - 0.5) * 0.75 + (n2 - 0.5) * 0.35;
	forma = clamp(forma, 0.0, 1.0);
	float a = smoothstep(0.02, suavidade, forma) * COLOR.a;
	vec3 col = mix(cor_fria.rgb, cor_quente.rgb, smoothstep(0.25, 0.85, forma));
	ALBEDO = col * COLOR.rgb * intensidade * a;
	ALPHA = a;
}
