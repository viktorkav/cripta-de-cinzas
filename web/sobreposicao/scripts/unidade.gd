class_name Unidade
extends Node3D
## Uma unidade em campo: modelo da Tripo com rig, animações, atributos e reações.

signal impacto

const SH_UNIDADE := preload("res://shaders/unidade.gdshader")
const MANIFEST_PATH := "res://assets/models/manifest_personagens.json"
static var manifest := {}
static var PBR_DESLIGADO := false # --sem_pbr: volta ao material antigo (comparação)

var tipo := ""
var dados := {}
var nome := ""
var time := 1
var celula := Vector2i.ZERO
var face := Vector2i(0, -1)
var hp := 1
var hp_max := 1
var atk := 1
var def := 0
var mov := 3
var pulo := 1
var vel := 7
var ct := 0
var furia := 0
var pocoes := 0
var atordoado := 0
var furioso := false
var vivo := true
var dormindo := true
var sala := -1

var corpo: Node3D
var pivo: Node3D
var modelo: Node3D
var anim: AnimationPlayer
var mats: Array[ShaderMaterial] = []
var anel: MeshInstance3D
var luz: OmniLight3D
var altura := 1.0
var mapa: Mapa
var vfx: Vfx
var _flash_tw: Tween
var anim_atual := ""


static func carregar_manifest() -> void:
	if manifest.is_empty():
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		manifest = JSON.parse_string(f.get_as_text())


func configurar(t: String, m: Mapa, efeitos: Vfx, c: Vector2i) -> void:
	carregar_manifest()
	tipo = t
	dados = Dados.TIPOS[t]
	nome = dados["nome"]
	time = dados["time"]
	hp_max = dados["hp"]
	hp = hp_max
	atk = dados["atk"]
	def = dados["def"]
	mov = dados["mov"]
	pulo = dados["pulo"]
	vel = dados["vel"]
	mapa = m
	vfx = efeitos
	celula = c
	altura = dados["altura"]
	corpo = Node3D.new()
	add_child(corpo)
	pivo = Node3D.new()
	corpo.add_child(pivo)
	var info: Dictionary = manifest[dados["modelo"]]
	var s: float = altura / float(info["height"])
	pivo.scale = Vector3.ONE * s
	pivo.rotation.y = PI * 0.5 # o modelo da Tripo olha para +X; a unidade olha para -Z
	modelo = (load("res://assets/models/%s.glb" % dados["modelo"]) as PackedScene).instantiate()
	pivo.add_child(modelo)
	var hips: Array = info["hips"]
	modelo.position = Vector3(-float(hips[0]), -float(info["zmin"]), float(hips[1]))
	anim = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for n in ["idle", "walk"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		anim.playback_default_blend_time = 0.15
	_trocar_materiais()
	_criar_anel()
	if t == "heroi":
		pocoes = Dados.POCOES_INICIAIS
		furia = 20
	if t == "heroi" and not Dados.luz_fixa:
		luz = OmniLight3D.new()
		luz.light_color = Color(1.0, 0.86, 0.7)
		luz.light_energy = 2.4
		luz.omni_range = 7.0
		luz.omni_attenuation = 1.25
		luz.shadow_enabled = true
		luz.shadow_blur = 1.5
		luz.light_volumetric_fog_energy = 0.4
		luz.position = Vector3(0.4, 2.6, 0.9)
		add_child(luz)
	if t == "chefe" and not Dados.luz_fixa:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.1)
		l.light_energy = 0.9
		l.omni_range = 3.5
		l.position = Vector3(0, 1.9, -0.5)
		add_child(l)
	position = mapa.mundo(c)
	tocar("idle")
	if anim:
		anim.seek(randf() * 1.5, true)


func _trocar_materiais() -> void:
	var ruido := load("res://assets/textures/ruido.png")
	# PBR da Tripo: roughness (G) e metallic (B) num mapa só (11/11; na web, 1024²)
	var orm: Texture2D = load("res://assets/models/pbr/%s_orm.png" % dados["modelo"])
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in m3.mesh.get_surface_count():
			var orig := m3.get_active_material(i)
			var sm := ShaderMaterial.new()
			sm.shader = SH_UNIDADE
			if orig is BaseMaterial3D:
				sm.set_shader_parameter("albedo_tex", (orig as BaseMaterial3D).albedo_texture)
			sm.set_shader_parameter("ruido", ruido)
			if orm and not PBR_DESLIGADO:
				sm.set_shader_parameter("orm_tex", orm)
				sm.set_shader_parameter("usar_pbr", 1.0)
			if tipo == "heroi":
				sm.set_shader_parameter("aro_base", 0.35)
				sm.set_shader_parameter("cor_aro_base", Color(1.0, 0.85, 0.6))
			m3.set_surface_override_material(i, sm)
			mats.append(sm)


func _criar_anel() -> void:
	anel = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5) * clampf(altura * 0.8, 0.85, 1.7)
	q.orientation = PlaneMesh.FACE_Y
	anel.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/anel.gdshader")
	m.set_shader_parameter("cor", Color(1.0, 0.78, 0.35) if time == 0 else Color(1.0, 0.2, 0.12))
	m.set_shader_parameter("raio", 0.36)
	m.set_shader_parameter("espessura", 0.035)
	m.set_shader_parameter("intensidade", 2.2)
	m.set_shader_parameter("tracos", 12.0)
	anel.material_override = m
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anel.position.y = 0.035
	anel.visible = false
	add_child(anel)


func set_param(nome_p: String, v) -> void:
	for m in mats:
		m.set_shader_parameter(nome_p, v)


func tocar(nome_a: String, blend := -1.0, vel_a := 1.0) -> void:
	if anim and anim.has_animation(nome_a):
		anim_atual = nome_a
		anim.play(nome_a, blend, vel_a)


func mostrar_anel(on: bool, ativo := false) -> void:
	anel.visible = on
	var m := anel.material_override as ShaderMaterial
	m.set_shader_parameter("intensidade", 3.2 if ativo else 1.8)
	m.set_shader_parameter("giro", 0.9 if ativo else 0.3)


func destacar(on: bool) -> void:
	set_param("aro", 1.0 if on else 0.0)


func pos_peito() -> Vector3:
	return global_position + Vector3(0, altura * 0.62, 0)


func pos_cabeca() -> Vector3:
	return global_position + Vector3(0, altura * 1.05, 0)


func yaw_para(d: Vector2i) -> float:
	return atan2(-float(d.x), -float(d.y))


func virar(d: Vector2i, dur := 0.12) -> void:
	if d == Vector2i.ZERO:
		return
	face = d
	var alvo := yaw_para(d)
	var atual := corpo.rotation.y
	var diff := wrapf(alvo - atual, -PI, PI)
	var tw := create_tween()
	tw.tween_property(corpo, "rotation:y", atual + diff, dur)


func virar_para(c: Vector2i, dur := 0.12) -> void:
	var d := c - celula
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= absi(d.y):
		d = Vector2i(signi(d.x), 0)
	else:
		d = Vector2i(0, signi(d.y))
	virar(d, dur)


func andar(caminho: Array[Vector2i], passo := 0.3, ao_passo := Callable()) -> void:
	if caminho.size() < 2:
		return
	tocar("walk", 0.12, 1.3)
	mapa.ocupante.erase(celula)
	for i in range(1, caminho.size()):
		var de: Vector2i = caminho[i - 1]
		var para: Vector2i = caminho[i]
		virar(para - de, 0.1)
		var p0 := mapa.mundo(de)
		var p1 := mapa.mundo(para)
		var tw := create_tween()
		if absf(p1.y - p0.y) > 0.01:
			var meio := (p0 + p1) * 0.5 + Vector3(0, 0.45, 0)
			var arco := func(t: float) -> void:
				var a := p0.lerp(meio, t)
				var b := meio.lerp(p1, t)
				position = a.lerp(b, t)
			tw.tween_method(arco, 0.0, 1.0, passo * 1.15)
		else:
			tw.tween_property(self, "position", p1, passo)
		await tw.finished
		celula = para
		if i % 2 == 0 or i == caminho.size() - 1:
			vfx.poeira_passo(position, 4, 0.22)
		if tipo == "heroi" or tipo == "chefe" or tipo == "bruto":
			Sons.tocar("passo", -14.0 if tipo == "heroi" else -10.0, randf_range(0.9, 1.1))
		if ao_passo.is_valid() and ao_passo.call():
			break
	mapa.ocupante[celula] = self
	tocar("idle", 0.2)


func golpear(alvo_pos: Vector3, nome_anim := "attack", momento := 0.43) -> void:
	tocar(nome_anim, 0.08, 1.0)
	await get_tree().create_timer(momento, false).timeout
	impacto.emit()
	var dur := anim.get_animation(nome_anim).length if anim and anim.has_animation(nome_anim) else 1.0
	await get_tree().create_timer(maxf(0.1, dur - momento - 0.05)).timeout
	if vivo:
		tocar("idle", 0.25)


func flash(cor := Color.WHITE, forca := 1.0) -> void:
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	set_param("cor_flash", cor)
	_flash_tw = create_tween()
	_flash_tw.tween_method(func(v): set_param("flash", v), forca, 0.0, 0.28)


func sofrer(_dano: int, de_onde: Vector3) -> void:
	flash(Color(1.0, 0.95, 0.9), 1.4)
	if hp > 0:
		tocar("hit", 0.05)
		var dir := (global_position - de_onde)
		dir.y = 0
		if dir.length() > 0.01:
			dir = dir.normalized() * 0.12
		var base := corpo.position
		var tw := create_tween()
		tw.tween_property(corpo, "position", base + dir, 0.07)
		tw.tween_property(corpo, "position", base, 0.2)
		get_tree().create_timer(0.5, false).timeout.connect(_voltar_idle_apos_hit)


func _voltar_idle_apos_hit() -> void:
	if vivo and anim_atual == "hit":
		tocar("idle", 0.25)


func morrer() -> void:
	vivo = false
	mapa.ocupante.erase(celula)
	mostrar_anel(false)
	tocar("death", 0.08)
	await get_tree().create_timer(1.25, false).timeout
	if tipo == "heroi":
		return
	vfx.alma(position + Vector3(0, 0.4, 0), Color(1.0, 0.45, 0.15) if tipo == "chefe" else Color(0.55, 0.75, 1.0), 26 if tipo == "chefe" else 16)
	var tw := create_tween()
	tw.tween_method(func(v): set_param("dissolver", v), 0.001, 1.0, 1.6 if tipo == "chefe" else 1.0)
	await tw.finished
	visible = false


func reviver() -> void:
	vivo = true
	visible = true
	hp = hp_max
	set_param("dissolver", 0.0)
	tocar("idle", 0.0)
