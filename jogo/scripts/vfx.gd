class_name Vfx
extends Node3D
## Fábrica de efeitos visuais: partículas, rastros, luzes rápidas e números de dano.

var ruido: Texture2D
var mat_fogo: ShaderMaterial
var mat_fogo_azul: ShaderMaterial
var mat_fogo_roxo: ShaderMaterial
var mat_faisca: ShaderMaterial
var mat_poeira: ShaderMaterial
var malha_arco: ArrayMesh
var malha_anel_completo: ArrayMesh
var fonte_num: FontVariation
var camera_rig: Node = null

const SH_FOGO := preload("res://shaders/fogo.gdshader")
const SH_FAISCA := preload("res://shaders/faisca.gdshader")
const SH_POEIRA := preload("res://shaders/poeira.gdshader")
const SH_RASTRO := preload("res://shaders/rastro.gdshader")
const SH_ANEL := preload("res://shaders/anel.gdshader")
const SH_FEIXE := preload("res://shaders/feixe.gdshader")
const SH_TELE := preload("res://shaders/telegrafo.gdshader")


func _ready() -> void:
	ruido = load("res://assets/textures/ruido.png")
	mat_fogo = _mat_fogo(Color(1.0, 0.74, 0.36), Color(0.9, 0.22, 0.03), 1.45)
	mat_fogo_azul = _mat_fogo(Color(0.75, 0.9, 1.0), Color(0.15, 0.35, 1.0), 1.5)
	mat_fogo_roxo = _mat_fogo(Color(1.0, 0.6, 0.95), Color(0.55, 0.05, 0.6), 1.6)
	mat_faisca = ShaderMaterial.new()
	mat_faisca.shader = SH_FAISCA
	mat_poeira = ShaderMaterial.new()
	mat_poeira.shader = SH_POEIRA
	malha_arco = _criar_arco(deg_to_rad(-95), deg_to_rad(95), 0.35, 1.15, 28)
	malha_anel_completo = _criar_arco(0.0, TAU, 0.55, 1.55, 48)
	fonte_num = FontVariation.new()
	fonte_num.base_font = load("res://assets/fonts/Cinzel.ttf")
	fonte_num.variation_opentype = {"wght": 800}


func _mat_fogo(quente: Color, fria: Color, inten: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_FOGO
	m.set_shader_parameter("ruido", ruido)
	m.set_shader_parameter("cor_quente", quente)
	m.set_shader_parameter("cor_fria", fria)
	m.set_shader_parameter("intensidade", inten)
	return m


static func rampa(cores: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cores)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func curva(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p in pts:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func particulas(qtd: int, vida: float, pm: ParticleProcessMaterial, mat: Material, tam: Vector2, unica := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	p.one_shot = unica
	p.explosiveness = 0.95 if unica else 0.0
	p.randomness = 0.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = tam
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 14, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _soltar(no: Node3D, pos: Vector3, vida: float) -> void:
	add_child(no)
	no.global_position = pos
	if no is GPUParticles3D:
		(no as GPUParticles3D).emitting = true
	get_tree().create_timer(vida).timeout.connect(no.queue_free)


func _criar_arco(a0: float, a1: float, ri: float, ro: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var b0 := lerpf(a0, a1, t0)
		var b1 := lerpf(a0, a1, t1)
		var p00 := Vector3(sin(b0) * ri, 0, -cos(b0) * ri)
		var p01 := Vector3(sin(b0) * ro, 0, -cos(b0) * ro)
		var p10 := Vector3(sin(b1) * ri, 0, -cos(b1) * ri)
		var p11 := Vector3(sin(b1) * ro, 0, -cos(b1) * ro)
		for v in [[p00, Vector2(t0, 0)], [p01, Vector2(t0, 1)], [p11, Vector2(t1, 1)],
				[p00, Vector2(t0, 0)], [p11, Vector2(t1, 1)], [p10, Vector2(t1, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


# ------------------------------------------------------------------ fogo contínuo
func chama(escala := 1.0, tipo := "laranja") -> Node3D:
	var raiz := Node3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06 * escala
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.35 * escala
	pm.initial_velocity_max = 0.7 * escala
	pm.gravity = Vector3(0, 0.6 * escala, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	pm.scale_curve = curva([Vector2(0, 0.55), Vector2(0.25, 1.0), Vector2(1, 0.15)])
	pm.color_ramp = rampa([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.8, 0.7, 0.8), Color(0.6, 0.3, 0.2, 0)], [0.0, 0.12, 0.55, 1.0])
	pm.angle_min = -15
	pm.angle_max = 15
	var mat := mat_fogo if tipo == "laranja" else (mat_fogo_azul if tipo == "azul" else mat_fogo_roxo)
	var f := particulas(int(16 * maxf(1.0, escala)), 0.7, pm, mat, Vector2(0.3, 0.44) * escala, false)
	f.emitting = true
	f.preprocess = 1.0
	raiz.add_child(f)
	# brasas subindo
	var pe := ParticleProcessMaterial.new()
	pe.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pe.emission_sphere_radius = 0.1 * escala
	pe.direction = Vector3.UP
	pe.spread = 25.0
	pe.initial_velocity_min = 0.5 * escala
	pe.initial_velocity_max = 1.4 * escala
	pe.gravity = Vector3(0, 0.25, 0)
	pe.turbulence_enabled = true
	pe.turbulence_noise_strength = 1.2
	pe.turbulence_noise_scale = 1.6
	pe.turbulence_influence_min = 0.05
	pe.turbulence_influence_max = 0.18
	pe.scale_min = 0.5
	pe.scale_max = 1.0
	var cor_brasa := Color(1.0, 0.55, 0.15) if tipo == "laranja" else (Color(0.4, 0.6, 1.0) if tipo == "azul" else Color(0.9, 0.3, 1.0))
	pe.color_ramp = rampa([Color(cor_brasa, 0), Color(cor_brasa, 1), Color(cor_brasa * 0.6, 0)], [0.0, 0.1, 1.0])
	var b := particulas(int(10 * maxf(1.0, escala)), 2.2, pe, mat_faisca, Vector2(0.035, 0.035) * escala, false)
	b.emitting = true
	b.preprocess = 2.0
	raiz.add_child(b)
	# fumaça escura
	var pf := ParticleProcessMaterial.new()
	pf.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pf.emission_sphere_radius = 0.08 * escala
	pf.direction = Vector3.UP
	pf.spread = 10.0
	pf.initial_velocity_min = 0.4 * escala
	pf.initial_velocity_max = 0.7 * escala
	pf.gravity = Vector3(0, 0.15, 0)
	pf.scale_min = 0.8
	pf.scale_max = 1.6
	pf.scale_curve = curva([Vector2(0, 0.3), Vector2(1, 1.0)])
	pf.color_ramp = rampa([Color(0.05, 0.04, 0.04, 0), Color(0.06, 0.05, 0.05, 0.35), Color(0.05, 0.05, 0.05, 0)], [0.0, 0.3, 1.0])
	var fu := particulas(8, 2.4, pf, mat_poeira, Vector2(0.5, 0.5) * escala, false)
	fu.position.y = 0.25 * escala
	fu.emitting = true
	fu.preprocess = 2.0
	raiz.add_child(fu)
	return raiz


# ------------------------------------------------------------------ ambiente
func poeira_ambiente(centro: Vector3, extensao: Vector3) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extensao
	pm.direction = Vector3(0.2, 0.1, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0, -0.006, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.01
	pm.turbulence_influence_max = 0.04
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_ramp = rampa([Color(0.9, 0.85, 0.75, 0), Color(0.9, 0.85, 0.75, 1), Color(0.9, 0.85, 0.75, 1), Color(0.9, 0.85, 0.75, 0)], [0.0, 0.2, 0.8, 1.0])
	var m := ShaderMaterial.new()
	m.shader = SH_POEIRA
	m.set_shader_parameter("opacidade", 0.55)
	var p := particulas(260, 14.0, pm, m, Vector2(0.025, 0.025), false)
	p.visibility_aabb = AABB(-extensao - Vector3.ONE, extensao * 2 + Vector3.ONE * 2)
	p.preprocess = 14.0
	p.emitting = true
	add_child(p)
	p.global_position = centro
	return p


# ------------------------------------------------------------------ combate
func faiscas(pos: Vector3, cor := Color(1.0, 0.7, 0.3), qtd := 28, forca := 1.0) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0 * forca
	pm.initial_velocity_max = 5.5 * forca
	pm.gravity = Vector3(0, -9.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = rampa([Color(1, 1, 0.9, 1), Color(cor, 1), Color(cor * 0.5, 0)], [0.0, 0.25, 1.0])
	var p := particulas(qtd, 0.55, pm, mat_faisca, Vector2(0.06, 0.06), true)
	_soltar(p, pos, 1.2)
	flash_luz(pos, cor, 3.0, 0.18, 4.0)


func sangue_osso(pos: Vector3, cor := Color(0.85, 0.8, 0.7)) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color_ramp = rampa([Color(cor, 1), Color(cor * 0.6, 1), Color(cor * 0.4, 0)], [0.0, 0.7, 1.0])
	var m := ShaderMaterial.new()
	m.shader = SH_POEIRA
	m.set_shader_parameter("opacidade", 1.0)
	var p := particulas(14, 0.7, pm, m, Vector2(0.07, 0.07), true)
	_soltar(p, pos, 1.2)


func poeira_passo(pos: Vector3, qtd := 6, tam := 0.3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.18
	pm.emission_ring_inner_radius = 0.05
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.radial_velocity_min = 0.3
	pm.radial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.1, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = curva([Vector2(0, 0.4), Vector2(1, 1.0)])
	pm.color_ramp = rampa([Color(0.45, 0.42, 0.38, 0), Color(0.45, 0.42, 0.38, 0.45), Color(0.4, 0.38, 0.35, 0)], [0.0, 0.15, 1.0])
	var p := particulas(qtd, 0.9, pm, mat_poeira, Vector2(tam, tam), true)
	_soltar(p, pos + Vector3(0, 0.05, 0), 1.4)


func rastro_golpe(pos: Vector3, para: Vector3, cor := Color(1.0, 0.72, 0.32), inclinacao := 25.0, escala := 1.0, dur := 0.26) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha_arco
	var m := ShaderMaterial.new()
	m.shader = SH_RASTRO
	m.set_shader_parameter("cor", cor)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	var alvo := Vector3(para.x, pos.y, para.z)
	if alvo.distance_to(pos) > 0.01:
		mi.look_at(alvo, Vector3.UP)
	mi.rotate_object_local(Vector3.FORWARD, deg_to_rad(inclinacao))
	mi.scale = Vector3.ONE * escala
	var tw := create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("progresso", v), 0.0, 1.4, dur)
	tw.tween_callback(mi.queue_free)


func redemoinho(pos: Vector3) -> void:
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = malha_anel_completo
		var m := ShaderMaterial.new()
		m.shader = SH_RASTRO
		m.set_shader_parameter("cor", Color(1.0, 0.6, 0.25))
		m.set_shader_parameter("comprimento", 0.6)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos + Vector3(0, 0.45 + i * 0.25, 0)
		mi.rotation.x = deg_to_rad(6 if i == 0 else -8)
		var tw := create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_method(func(v): m.set_shader_parameter("progresso", v), 0.0, 1.4, 0.45)
		tw.parallel().tween_property(mi, "rotation:y", -TAU, 0.45)
		tw.tween_callback(mi.queue_free)
	poeira_passo(pos, 22, 0.55)
	onda(pos + Vector3(0, 0.04, 0), Color(1.0, 0.7, 0.35), 2.0, 0.45)


func onda(pos: Vector3, cor: Color, raio_final := 1.5, dur := 0.5, intens := 3.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SH_ANEL
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("espessura", 0.06)
	m.set_shader_parameter("intensidade", intens)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * raio_final
	var tw := create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("raio", v), 0.05, 0.48, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(v): m.set_shader_parameter("alfa", v), 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)


func flash_luz(pos: Vector3, cor: Color, energia := 4.0, dur := 0.25, alcance := 5.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 1.5
	add_child(l)
	l.global_position = pos
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


func bola_de_fogo(de: Vector3, para: Vector3, roxa := false) -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = de
	var nucleo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.13
	esf.height = 0.26
	nucleo.mesh = esf
	var mn := StandardMaterial3D.new()
	mn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mn.albedo_color = Color(1.0, 0.85, 0.6) if not roxa else Color(1.0, 0.7, 1.0)
	mn.emission_enabled = true
	mn.emission = Color(1.0, 0.5, 0.1) if not roxa else Color(0.8, 0.2, 1.0)
	mn.emission_energy_multiplier = 6.0
	nucleo.material_override = mn
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(nucleo)
	var ch := chama(0.9, "roxo" if roxa else "laranja")
	raiz.add_child(ch)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15) if not roxa else Color(0.8, 0.3, 1.0)
	l.light_energy = 3.0
	l.omni_range = 4.0
	l.light_volumetric_fog_energy = 2.0
	raiz.add_child(l)
	var meio := (de + para) * 0.5 + Vector3(0, 1.2, 0)
	var dur := clampf(de.distance_to(para) * 0.12, 0.3, 0.6)
	var voo := func(t: float) -> void:
		var a := de.lerp(meio, t)
		var b := meio.lerp(para, t)
		raiz.global_position = a.lerp(b, t)
	var tw := create_tween()
	tw.tween_method(voo, 0.0, 1.0, dur)
	await tw.finished
	explosao(para, 0.8, roxa)
	raiz.queue_free()


func explosao(pos: Vector3, tam := 1.0, roxa := false) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2 * tam
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0 * tam
	pm.initial_velocity_max = 3.0 * tam
	pm.gravity = Vector3(0, 1.5, 0)
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.scale_curve = curva([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.2)])
	pm.color_ramp = rampa([Color(1, 1, 1, 1), Color(1, 0.8, 0.6, 0.8), Color(0.4, 0.2, 0.1, 0)], [0.0, 0.4, 1.0])
	var p := particulas(int(30 * tam), 0.7, pm, mat_fogo_roxo if roxa else mat_fogo, Vector2(0.7, 0.7) * tam, true)
	_soltar(p, pos + Vector3(0, 0.3, 0), 1.5)
	faiscas(pos + Vector3(0, 0.3, 0), Color(1.0, 0.5, 0.1) if not roxa else Color(0.8, 0.3, 1.0), 30, 1.2 * tam)
	onda(pos + Vector3(0, 0.05, 0), Color(1.0, 0.45, 0.1) if not roxa else Color(0.8, 0.3, 1.0), 1.6 * tam, 0.5)
	flash_luz(pos + Vector3(0, 0.6, 0), Color(1.0, 0.5, 0.15) if not roxa else Color(0.8, 0.3, 1.0), 9.0 * tam, 0.45, 7.0)
	tremer(0.25 * tam)


func raio_sagrado(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.45
	cil.bottom_radius = 0.6
	cil.height = 9.0
	cil.cap_top = false
	cil.cap_bottom = false
	mi.mesh = cil
	var m := ShaderMaterial.new()
	m.shader = SH_FEIXE
	m.set_shader_parameter("ruido", ruido)
	m.set_shader_parameter("cor", Color(1.0, 0.85, 0.45))
	m.set_shader_parameter("intensidade", 6.0)
	m.set_shader_parameter("velocidade", -2.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 4.5, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(1.4, 1, 1.4), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.6
	pm.emission_ring_inner_radius = 0.1
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = rampa([Color(1, 1, 0.9, 1), Color(1.0, 0.8, 0.35, 1), Color(1.0, 0.6, 0.2, 0)], [0.0, 0.3, 1.0])
	var p := particulas(60, 1.0, pm, mat_faisca, Vector2(0.07, 0.07), true)
	_soltar(p, pos, 1.6)
	onda(pos + Vector3(0, 0.05, 0), Color(1.0, 0.82, 0.4), 2.4, 0.5, 4.0)
	flash_luz(pos + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.55), 14.0, 0.5, 8.0)
	tremer(0.35)


func cura(pos: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.5
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.6
	pm.direction = Vector3.UP
	pm.spread = 5.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.4, 0)
	pm.tangential_accel_min = 1.0
	pm.tangential_accel_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color_ramp = rampa([Color(1.0, 0.3, 0.3, 0), Color(1.0, 0.45, 0.35, 1), Color(1.0, 0.85, 0.6, 0)], [0.0, 0.2, 1.0])
	var p := particulas(40, 1.3, pm, mat_faisca, Vector2(0.06, 0.06), true)
	_soltar(p, pos + Vector3(0, 0.2, 0), 2.0)
	onda(pos + Vector3(0, 0.05, 0), Color(1.0, 0.35, 0.3), 1.2, 0.6, 2.0)
	flash_luz(pos + Vector3(0, 1.0, 0), Color(1.0, 0.4, 0.35), 3.0, 0.6, 4.0)


func alma(pos: Vector3, cor := Color(0.55, 0.75, 1.0), qtd := 18) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.8, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color_ramp = rampa([Color(cor, 0), Color(cor, 1), Color(cor * 0.5, 0)], [0.0, 0.2, 1.0])
	var p := particulas(qtd, 1.8, pm, mat_faisca, Vector2(0.08, 0.08), true)
	_soltar(p, pos, 2.5)


func portal(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SH_ANEL
	m.set_shader_parameter("cor", Color(0.75, 0.2, 1.0))
	m.set_shader_parameter("runas", 1.0)
	m.set_shader_parameter("raio", 0.48)
	m.set_shader_parameter("intensidade", 3.0)
	m.set_shader_parameter("giro", 2.0)
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.04, 0)
	mi.scale = Vector3.ONE * 0.1
	var ch := chama(1.2, "roxo")
	mi.add_child(ch)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.75, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_method(func(v): m.set_shader_parameter("alfa", v), 1.0, 0.0, 0.5)
	tw.tween_callback(mi.queue_free)
	flash_luz(pos + Vector3(0, 1.0, 0), Color(0.7, 0.25, 1.0), 6.0, 1.2, 5.0)


func telegrafo(celulas: Array, mapa, cor := Color(1.0, 0.25, 0.05)) -> Node3D:
	var raiz := Node3D.new()
	add_child(raiz)
	var m := ShaderMaterial.new()
	m.shader = SH_TELE
	m.set_shader_parameter("cor", cor)
	var q := QuadMesh.new()
	q.size = Vector2(0.96, 0.96)
	q.orientation = PlaneMesh.FACE_Y
	for c in celulas:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		mi.global_position = mapa.mundo(c) + Vector3(0, 0.035, 0)
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = 1.2
	l.omni_range = 4.5
	raiz.add_child(l)
	var centro := Vector3.ZERO
	for c in celulas:
		centro += mapa.mundo(c)
	l.global_position = centro / maxf(1.0, celulas.size()) + Vector3(0, 0.6, 0)
	raiz.set_meta("mat", m)
	return raiz


func pilares_de_fogo(celulas: Array, mapa) -> void:
	for c in celulas:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.35, 0.05, 0.35)
		pm.direction = Vector3.UP
		pm.spread = 8.0
		pm.initial_velocity_min = 2.5
		pm.initial_velocity_max = 4.5
		pm.gravity = Vector3(0, 1.0, 0)
		pm.damping_min = 2.0
		pm.damping_max = 3.0
		pm.scale_min = 0.8
		pm.scale_max = 1.4
		pm.scale_curve = curva([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 0.1)])
		pm.color_ramp = rampa([Color(1, 1, 1, 1), Color(1, 0.8, 0.6, 0.9), Color(0.5, 0.2, 0.1, 0)], [0.0, 0.4, 1.0])
		var p := particulas(18, 0.7, pm, mat_fogo, Vector2(0.6, 0.85), true)
		_soltar(p, mapa.mundo(c), 1.4)
	var centro := Vector3.ZERO
	for c in celulas:
		centro += mapa.mundo(c)
	centro /= maxf(1.0, celulas.size())
	flash_luz(centro + Vector3(0, 1.0, 0), Color(1.0, 0.45, 0.1), 16.0, 0.6, 9.0)
	onda(centro + Vector3(0, 0.05, 0), Color(1.0, 0.4, 0.1), 4.0, 0.6, 3.0)
	tremer(0.5)


func feixe_lendario(pos: Vector3) -> Node3D:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = pos
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.08
	cil.bottom_radius = 0.3
	cil.height = 7.0
	cil.cap_top = false
	cil.cap_bottom = false
	mi.mesh = cil
	var m := ShaderMaterial.new()
	m.shader = SH_FEIXE
	m.set_shader_parameter("ruido", ruido)
	m.set_shader_parameter("cor", Color(1.0, 0.5, 0.12))
	m.set_shader_parameter("intensidade", 3.0)
	m.set_shader_parameter("velocidade", -0.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 3.5
	raiz.add_child(mi)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.4
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = rampa([Color(1.0, 0.6, 0.2, 0), Color(1.0, 0.6, 0.2, 1), Color(1.0, 0.4, 0.1, 0)], [0.0, 0.2, 1.0])
	var p := particulas(40, 2.2, pm, mat_faisca, Vector2(0.05, 0.05), false)
	p.emitting = true
	raiz.add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 5.0
	l.light_volumetric_fog_energy = 2.0
	l.position.y = 1.0
	raiz.add_child(l)
	return raiz


func numero(pos: Vector3, texto: String, cor: Color, tam := 64, subir := 0.9, dur := 1.05) -> void:
	var lb := Label3D.new()
	lb.text = texto
	lb.font = fonte_num
	lb.font_size = tam
	lb.pixel_size = 0.0055
	lb.outline_size = int(tam * 0.22)
	lb.outline_modulate = Color(0.05, 0.02, 0.02, 0.95)
	lb.modulate = cor
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.render_priority = 10
	lb.outline_render_priority = 9
	lb.double_sided = true
	add_child(lb)
	lb.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
	lb.scale = Vector3.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(lb, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "scale", Vector3.ONE, 0.1)
	tw.parallel().tween_property(lb, "global_position", lb.global_position + Vector3(0, subir, 0), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.parallel().tween_property(lb, "outline_modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.tween_callback(lb.queue_free)


func tremer(forca: float) -> void:
	if camera_rig and camera_rig.has_method("tremer"):
		camera_rig.tremer(forca)
