class_name Mundo
extends Node3D
## Monta a masmorra: piso, paredes, props da Tripo, luzes, névoa e partículas de ambiente.

const ALTURA_PAREDE := 3.2
const BASE := -0.6

var mapa: Mapa
var vfx: Vfx
var ambiente: WorldEnvironment
var mat_parede: ShaderMaterial
var portas := {} # Vector2i -> Node3D
var bau: Node3D
var tampa_bau: Node3D
var luzes_tocha: Array[OmniLight3D] = []
var base_energia: Array[float] = []
var ruido_luz := FastNoiseLite.new()
var tempo := 0.0
var circulo_runa: MeshInstance3D
var luz_runa: OmniLight3D
var modelos := {}
var paredes: Array[Vector2i] = []
var paredes_alt: Array[float] = []
var paredes_normal: Array[Vector3] = []
var mm_paredes: MultiMesh
var enfeites_parede := {} # Vector2i -> Array[Node3D]
var luzes_parede := {} # Vector2i -> OmniLight3D
var yaw_paredes := 999.0


func construir(m: Mapa, efeitos: Vfx) -> void:
	mapa = m
	vfx = efeitos
	ruido_luz.frequency = 2.2
	_ambiente()
	_piso_e_paredes()
	_props()
	_tochas()
	_estandartes()
	_luar()
	_santuario()
	_poeira()


func cena(nome: String) -> Node3D:
	if not modelos.has(nome):
		modelos[nome] = load("res://assets/models/%s.glb" % nome)
	var n := (modelos[nome] as PackedScene).instantiate() as Node3D
	_pbr(n, nome)
	return n


## PBR da Tripo nos objetos: o material importado do GLB passa a ler roughness (G) e metallic (B)
## do mapa empacotado. O material é compartilhado entre as cópias, então basta ajustar uma vez.
func _pbr(n: Node, nome: String) -> void:
	if Unidade.PBR_DESLIGADO:
		return
	var caminho := "res://assets/models/pbr/%s_orm.png" % nome
	if not ResourceLoader.exists(caminho):
		return
	var orm: Texture2D = load(caminho)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var mat := m3.get_active_material(i) as BaseMaterial3D
			if mat == null or mat.roughness_texture == orm:
				continue
			mat.roughness = 1.0
			mat.roughness_texture = orm
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			mat.metallic = 1.0
			mat.metallic_texture = orm
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE


# ------------------------------------------------------------------ ambiente
func _ambiente() -> void:
	ambiente = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.36, 0.5)
	e.ambient_light_energy = 0.3
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_strength = 1.0
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.05
	e.glow_hdr_scale = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	e.set_glow_level(5, 0.3)
	e.ssao_enabled = true
	e.ssao_radius = 1.1
	e.ssao_intensity = 2.4
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssao_light_affect = 0.15
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.028
	e.volumetric_fog_albedo = Color(0.62, 0.64, 0.72)
	e.volumetric_fog_emission = Color(0, 0, 0)
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_detail_spread = 1.5
	e.volumetric_fog_gi_inject = 0.0
	e.volumetric_fog_ambient_inject = 0.0
	e.volumetric_fog_temporal_reprojection_enabled = true
	e.volumetric_fog_temporal_reprojection_amount = 0.85
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.0
	e.adjustment_contrast = 1.1
	e.adjustment_saturation = 1.12
	ambiente.environment = e
	add_child(ambiente)


# ------------------------------------------------------------------ piso e paredes
func _piso_e_paredes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE
	# piso
	var mat_piso := ShaderMaterial.new()
	mat_piso.shader = load("res://shaders/piso.gdshader")
	mat_piso.set_shader_parameter("albedo_piso", load("res://assets/textures/piso_albedo.png"))
	mat_piso.set_shader_parameter("normal_piso", load("res://assets/textures/piso_normal.png"))
	mat_piso.set_shader_parameter("rough_piso", load("res://assets/textures/piso_rough.png"))
	mat_piso.set_shader_parameter("albedo_lado", load("res://assets/textures/parede_albedo.png"))
	mat_piso.set_shader_parameter("normal_lado", load("res://assets/textures/parede_normal.png"))
	var cel := mapa.piso.keys()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = caixa
	mm.instance_count = cel.size()
	for i in cel.size():
		var c: Vector2i = cel[i]
		var topo := mapa.y(c) + rng.randf_range(-0.012, 0.012)
		var alt := topo - BASE
		var t := Transform3D(Basis().scaled(Vector3(1.0, alt, 1.0)), Vector3(c.x, BASE + alt * 0.5, c.y))
		mm.set_instance_transform(i, t)
		mm.set_instance_custom_data(i, Color(rng.randi_range(0, 3), rng.randi_range(0, 3), rng.randf_range(0.82, 1.08), 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat_piso
	add_child(mi)
	# paredes: células de rocha vizinhas a piso
	paredes.clear()
	for z in range(-1, mapa.profundidade + 1):
		for x in range(-1, mapa.largura + 1):
			var c := Vector2i(x, z)
			if mapa.eh_piso(c):
				continue
			for d in Mapa.DIRS8:
				if mapa.eh_piso(c + d):
					paredes.append(c)
					break
	mat_parede = ShaderMaterial.new()
	mat_parede.shader = load("res://shaders/parede.gdshader")
	mat_parede.set_shader_parameter("albedo_lado", load("res://assets/textures/parede_albedo.png"))
	mat_parede.set_shader_parameter("normal_lado", load("res://assets/textures/parede_normal.png"))
	var mw := MultiMesh.new()
	mw.transform_format = MultiMesh.TRANSFORM_3D
	mw.mesh = caixa
	mw.instance_count = paredes.size()
	var ms := MultiMesh.new()
	ms.transform_format = MultiMesh.TRANSFORM_3D
	ms.mesh = caixa
	ms.instance_count = paredes.size()
	for i in paredes.size():
		var c: Vector2i = paredes[i]
		var alt := ALTURA_PAREDE + rng.randf_range(-0.25, 0.35) - BASE
		var t := Transform3D(Basis().scaled(Vector3(1.0, alt, 1.0)), Vector3(c.x, BASE + alt * 0.5, c.y))
		mw.set_instance_transform(i, t)
		ms.set_instance_transform(i, t)
		paredes_alt.append(alt)
		var n := Vector3.ZERO
		for d in Mapa.DIRS:
			if mapa.eh_piso(c - d):
				n += Vector3(d.x, 0, d.y)
		if n.length() < 0.01:
			for d in Mapa.DIRS8:
				if mapa.eh_piso(c - d):
					n += Vector3(d.x, 0, d.y)
		paredes_normal.append(n.normalized())
	mm_paredes = mw
	var wi := MultiMeshInstance3D.new()
	wi.multimesh = mw
	wi.material_override = mat_parede
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)
	var si := MultiMeshInstance3D.new()
	si.multimesh = ms
	var mat_sombra := StandardMaterial3D.new()
	mat_sombra.albedo_color = Color.BLACK
	si.material_override = mat_sombra
	si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(si)


# ------------------------------------------------------------------ props
func _colocar(nome: String, c: Vector2i, escala: float, giro_y := 0.0, desloc := Vector3.ZERO) -> Node3D:
	var n := cena(nome)
	add_child(n)
	n.position = mapa.mundo(c) + desloc
	n.rotation.y = giro_y
	n.scale = Vector3.ONE * escala
	_sombras(n, true)
	return n


func _sombras(n: Node, ligar: bool) -> void:
	for f in n.find_children("*", "GeometryInstance3D", true, false):
		(f as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ligar else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for c in mapa.piso:
		var ch: String = mapa.piso[c]
		match ch:
			"P":
				_colocar("pilar", c, 2.95, rng.randi_range(0, 3) * PI * 0.5)
			"B":
				_colocar("barril", c, 0.82, rng.randf_range(0, TAU), Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)))
			"o":
				_colocar("ossos", c, 0.85, rng.randf_range(0, TAU))
			"R":
				var b := _colocar("braseiro", c, 0.95, rng.randf_range(0, TAU))
				var fogo := vfx.chama(1.25)
				add_child(fogo)
				fogo.global_position = b.global_position + Vector3(0, 0.62, 0)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.5, 0.2)
				l.light_energy = 5.0
				l.omni_range = 9.0
				l.omni_attenuation = 1.3
				l.shadow_enabled = true
				l.shadow_blur = 1.5
				l.light_size = 0.0 # PCSS custava ~25% do quadro em 4K
				l.light_volumetric_fog_energy = 1.4
				l.distance_fade_enabled = true
				l.distance_fade_begin = 45.0
				l.distance_fade_shadow = 34.0
				add_child(l)
				l.global_position = b.global_position + Vector3(0, 1.3, 0)
				_registrar_luz(l)
			"C":
				bau = _colocar("bau_novo", c, 0.95, -PI * 0.5)
				tampa_bau = bau.find_child("tampa", true, false) as Node3D
			"D":
				var p := _colocar("porta", c, 2.6, PI * 0.5)
				portas[c] = p


func abrir_porta(c: Vector2i) -> void:
	if not portas.has(c):
		return
	var p: Node3D = portas[c]
	portas.erase(c)
	mapa.bloqueado.erase(c)
	var tw := create_tween()
	tw.tween_property(p, "position:y", p.position.y - 2.8, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(p, "position:x", p.position.x + 0.04, 0.08).set_delay(0.0)
	tw.tween_callback(p.queue_free)
	for i in 5:
		get_tree().create_timer(i * 0.3, false).timeout.connect(_poeira_porta.bind(c))
	vfx.tremer(0.35)


func _poeira_porta(c: Vector2i) -> void:
	vfx.poeira_passo(mapa.mundo(c) + Vector3(randf_range(-1, 1), 0, randf_range(-0.3, 0.3)), 14, 0.9)


func abrir_bau() -> void:
	if tampa_bau == null:
		return
	var tw := create_tween()
	tw.tween_property(tampa_bau, "rotation:z", deg_to_rad(-6), 0.15)
	tw.tween_property(tampa_bau, "rotation:z", deg_to_rad(105), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ luzes
func _registrar_luz(l: OmniLight3D) -> void:
	luzes_tocha.append(l)
	base_energia.append(l.light_energy)
	_registrar_sombra(l, Vector2(l.global_position.x, l.global_position.z), l.omni_range * 0.9)


# ------------------------------------------------------------------ orçamento de sombras
# Sombra de luz pontual custa 6 passadas por quadro (cubo). Só as luzes cujo alcance
# toca a sala em foco mantêm sombra; as outras continuam acesas, sem sombra. Como as
# paredes isolam as salas, o que fica fora desse alcance não aparece na sala em cena.
var luzes_sombra: Array = [] # [Light3D, Vector2 posição xz, alcance]
var salas_sombra := [-1]


func _registrar_sombra(l: Light3D, pos: Vector2, alcance: float) -> void:
	luzes_sombra.append([l, pos, alcance])


func _ret_sala(i: int) -> Rect2:
	var r: Rect2i = Dados.SALAS[i]["ret"]
	return Rect2(Vector2(r.position) - Vector2(0.5, 0.5), Vector2(r.size))


func focar_sombras(celula: Vector2i) -> void:
	var salas: Array = []
	for i in Dados.SALAS.size():
		var r: Rect2i = Dados.SALAS[i]["ret"]
		if r.grow(1).has_point(celula):
			salas.append(i)
	if salas.is_empty() or salas == salas_sombra:
		return
	salas_sombra = salas
	for e in luzes_sombra:
		var l: Light3D = e[0]
		var pos: Vector2 = e[1]
		var alc: float = e[2]
		var liga := false
		for i in salas:
			var r := _ret_sala(i)
			var maisperto := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
			if maisperto.distance_to(pos) < alc:
				liga = true
		l.shadow_enabled = liga


func _tochas() -> void:
	for t in Dados.TOCHAS:
		var w: Vector2i = t[0]
		var d: Vector2i = t[1]
		var dir := Vector3(d.x, 0, d.y)
		var face := Vector3(w.x, 0, w.y) + dir * 0.5
		var tocha := cena("tocha")
		add_child(tocha)
		var esc := 0.75
		tocha.scale = Vector3.ONE * esc
		tocha.basis = Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).scaled(Vector3.ONE * esc)
		tocha.position = face + dir * 0.2 + Vector3(0, 1.25, 0)
		_sombras(tocha, false)
		enfeites_parede[w] = enfeites_parede.get(w, []) + [tocha]
		var topo := tocha.position + dir * 0.06 + Vector3(0, 0.78, 0)
		var fogo := vfx.chama(0.75)
		add_child(fogo)
		fogo.position = topo
		enfeites_parede[w] = enfeites_parede.get(w, []) + [fogo]
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.56, 0.24)
		l.light_energy = 2.6
		l.omni_range = 7.5
		l.omni_attenuation = 1.45
		l.shadow_enabled = true
		l.shadow_blur = 1.2
		l.light_size = 0.0
		l.shadow_bias = 0.08
		l.light_volumetric_fog_energy = 1.6
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		l.distance_fade_length = 8.0
		l.distance_fade_shadow = 30.0
		add_child(l)
		l.position = topo + dir * 0.35 + Vector3(0, 0.15, 0)
		_registrar_luz(l)
		luzes_parede[w] = luzes_parede.get(w, []) + [l]


func _estandartes() -> void:
	for t in Dados.ESTANDARTES:
		var w: Vector2i = t[0]
		var d: Vector2i = t[1]
		var dir := Vector3(d.x, 0, d.y)
		var face := Vector3(w.x, 0, w.y) + dir * 0.5
		var e := cena("estandarte")
		add_child(e)
		e.basis = Basis(dir, Vector3.UP, dir.cross(Vector3.UP)).scaled(Vector3.ONE * 2.1)
		e.position = face + dir * 0.14 + Vector3(0, 0.75, 0)
		_sombras(e, true)
		enfeites_parede[w] = enfeites_parede.get(w, []) + [e]


func _luar() -> void:
	for f in Dados.FEIXES:
		var p := Vector3(f.x, 0, f.y)
		var s := SpotLight3D.new()
		s.light_color = Color(0.55, 0.66, 1.0)
		s.light_energy = 7.0
		s.spot_range = 16.0
		s.spot_angle = 11.0
		s.spot_angle_attenuation = 0.6
		s.spot_attenuation = 0.3
		s.shadow_enabled = true
		s.shadow_blur = 2.0
		s.light_volumetric_fog_energy = 5.0
		add_child(s)
		s.position = p + Vector3(1.6, 12.0, -1.2)
		s.look_at(p, Vector3.FORWARD)
		_registrar_sombra(s, Vector2(p.x, p.z), 2.0)
		# poeira dentro do feixe
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.9, 2.5, 0.9)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 40
		pm.initial_velocity_min = 0.02
		pm.initial_velocity_max = 0.08
		pm.gravity = Vector3(0, -0.02, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.3
		pm.turbulence_influence_min = 0.01
		pm.turbulence_influence_max = 0.03
		pm.color_ramp = Vfx.rampa([Color(0.8, 0.85, 1.0, 0), Color(0.8, 0.85, 1.0, 1), Color(0.8, 0.85, 1.0, 0)], [0.0, 0.5, 1.0])
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/poeira.gdshader")
		m.set_shader_parameter("opacidade", 0.9)
		var pp := vfx.particulas(90, 10.0, pm, m, Vector2(0.03, 0.03), false)
		pp.preprocess = 10.0
		pp.emitting = true
		add_child(pp)
		pp.position = p + Vector3(0.35, 2.6, -0.25)


func _santuario() -> void:
	# círculo rúnico sob o estrado do chefe
	circulo_runa = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.2, 5.2)
	q.orientation = PlaneMesh.FACE_Y
	circulo_runa.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/anel.gdshader")
	m.set_shader_parameter("cor", Color(1.0, 0.18, 0.08))
	m.set_shader_parameter("runas", 1.0)
	m.set_shader_parameter("raio", 0.5)
	m.set_shader_parameter("espessura", 0.015)
	m.set_shader_parameter("intensidade", 1.1)
	m.set_shader_parameter("giro", 0.12)
	circulo_runa.material_override = m
	circulo_runa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(circulo_runa)
	circulo_runa.position = Vector3(11, Dados.NIVEL + 0.03, 3)
	luz_runa = OmniLight3D.new()
	luz_runa.light_color = Color(1.0, 0.15, 0.1)
	luz_runa.light_energy = 1.7
	luz_runa.omni_range = 6.5
	luz_runa.light_volumetric_fog_energy = 2.5
	add_child(luz_runa)
	luz_runa.position = Vector3(11, 1.2, 3.2)
	# névoa rasteira avermelhada no santuário
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(15, 1.4, 11)
	var fm := FogMaterial.new()
	fm.density = 0.35
	fm.albedo = Color(0.55, 0.5, 0.52)
	fm.height_falloff = 2.2
	fm.edge_fade = 0.4
	fv.material = fm
	add_child(fv)
	fv.position = Vector3(11, 0.2, 6.5)
	# névoa rasteira leve na galeria e no salão
	for r in [[Vector3(11, 0.15, 16.5), Vector3(9, 1.0, 8)], [Vector3(11, 0.15, 26.5), Vector3(13, 1.0, 10)]]:
		var f2 := FogVolume.new()
		f2.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		f2.size = r[1]
		var m2 := FogMaterial.new()
		m2.density = 0.18
		m2.albedo = Color(0.55, 0.58, 0.66)
		m2.height_falloff = 2.5
		m2.edge_fade = 0.5
		f2.material = m2
		add_child(f2)
		f2.position = r[0]


func apagar_runa() -> void:
	if circulo_runa == null:
		return
	var m := circulo_runa.material_override as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("alfa", v), 1.0, 0.12, 3.0)
	tw.parallel().tween_property(luz_runa, "light_color", Color(1.0, 0.55, 0.3), 3.0)


func _poeira() -> void:
	for s in Dados.SALAS:
		var r: Rect2i = s["ret"]
		var centro := Vector3(r.position.x + r.size.x * 0.5 - 0.5, 1.6, r.position.y + r.size.y * 0.5 - 0.5)
		vfx.poeira_ambiente(centro, Vector3(r.size.x * 0.5, 1.5, r.size.y * 0.5))


func _process(delta: float) -> void:
	tempo += delta
	for i in luzes_tocha.size():
		var l := luzes_tocha[i]
		if not is_instance_valid(l):
			continue
		var n := ruido_luz.get_noise_2d(tempo * 6.0, i * 37.0)
		var n2 := ruido_luz.get_noise_2d(tempo * 17.0, i * 11.0 + 5.0)
		l.light_energy = base_energia[i] * (0.86 + n * 0.16 + n2 * 0.06)
	if luz_runa and luz_runa.light_color.g < 0.5:
		luz_runa.light_energy = 1.6 + sin(tempo * 1.7) * 0.4


## Paredes entre a câmera e a sala viram toquinhos (corte isométrico, como em Diablo)
func atualizar_paredes(yaw: float) -> void:
	if absf(wrapf(yaw - yaw_paredes, -PI, PI)) < 0.2 or mm_paredes == null:
		return
	yaw_paredes = yaw
	var para_cam := Vector3(sin(yaw), 0, cos(yaw))
	var baixas := {}
	for i in paredes.size():
		var c := paredes[i]
		var baixa := paredes_normal[i].dot(para_cam) > 0.25
		var alt := 0.95 if baixa else paredes_alt[i]
		mm_paredes.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.0, alt, 1.0)), Vector3(c.x, BASE + alt * 0.5, c.y)))
		if baixa:
			baixas[c] = true
	for w in enfeites_parede:
		for n in enfeites_parede[w]:
			(n as Node3D).visible = not baixas.has(w)
	for w in luzes_parede:
		for l in luzes_parede[w]:
			var idx := luzes_tocha.find(l)
			if idx >= 0:
				base_energia[idx] = 1.6 if baixas.has(w) else 2.6


func atualizar_furo(cam: Camera3D, alvo: Vector3) -> void:
	if mat_parede == null or cam == null or not cam.is_inside_tree():
		return
	if cam.global_position.distance_to(alvo) < 1.0:
		return
	var vp := get_viewport()
	var tam := vp.get_visible_rect().size
	var sp := cam.unproject_position(alvo + Vector3(0, 0.8, 0))
	mat_parede.set_shader_parameter("furo_tela", Vector2(sp.x / tam.x, sp.y / tam.y))
	var prof := -(cam.global_transform.affine_inverse() * (alvo + Vector3(0, 0.8, 0))).z
	mat_parede.set_shader_parameter("furo_prof", prof)
	mat_parede.set_shader_parameter("aspecto", tam.x / tam.y)
