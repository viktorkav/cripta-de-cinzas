class_name Jogo
extends Node3D
## Orquestra a partida: exploração, turnos por CT (estilo FFT), habilidades, IA, salas e baú.

signal fim_turno_heroi

enum E { MENU, EXPLORAR, TURNO_HEROI, OCUPADO, FIM }

var estado := E.MENU
var mapa: Mapa
var mundo: Mundo
var vfx: Vfx
var cam: CameraRig
var hud: Hud
var ia: IA
var heroi: Unidade
var unidades: Array[Unidade] = []
var rng := RandomNumberGenerator.new()

var sala := 0
var salas_limpas := {}
var em_combate := false
var modo := "mover"
var alc_heroi := {}
var moveu := false
var agiu := false
var virou_manual := false
var celula_hover := Vector2i(-99, -99)
var unidade_hover: Unidade = null
var estado_chefe := {}
var telegrafo_no: Node3D = null
var chefe_morto := false
var bau_aberto := false
var feixe_bau: Node3D = null

var overlay_alcance: MultiMeshInstance3D
var overlay_area: MultiMeshInstance3D
var cursor: MeshInstance3D

var args := {}
var autoplay := false
var bench := false
var escala_tempo := 1.0
var log_linhas: PackedStringArray = []
var stats := {"turnos": 0, "dano_causado": 0, "dano_recebido": 0, "pocoes": 0, "mortes": 0, "tempo": 0.0}
var stats_sala := {}
var snapshot := {}
var spawns := {} # Unidade -> Vector2i
var invocados: Array[Unidade] = []
var tempo_jogo := 0.0
var fps_amostras: PackedFloat32Array = []
var gpu_amostras: PackedFloat32Array = []


func _ready() -> void:
	_ler_args()
	rng.seed = int(args.get("seed", "7"))
	mapa = Mapa.new()
	mapa.carregar(Dados.MAPA)
	vfx = Vfx.new()
	add_child(vfx)
	mundo = Mundo.new()
	add_child(mundo)
	mundo.construir(mapa, vfx)
	cam = CameraRig.new()
	add_child(cam)
	vfx.camera_rig = cam
	_criar_overlays()
	_criar_unidades()
	if args.has("hp"): # teste da tela de morte: herói fraco e sem poções
		heroi.hp = int(args["hp"])
		heroi.pocoes = 0
	ia = IA.new(self)
	hud = Hud.new()
	add_child(hud)
	hud.configurar(self)
	Sons.tocar_ambiente("ambiente", -10.0)
	if bench:
		if args.get("vsync", "0") == "0":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var melhor := 0
		var area := 0
		for i in DisplayServer.get_screen_count():
			var sz := DisplayServer.screen_get_size(i)
			print("TELA %d %s escala=%.2f" % [i, str(sz), DisplayServer.screen_get_scale(i)])
			if sz.x * sz.y > area:
				area = sz.x * sz.y
				melhor = i
		DisplayServer.window_set_current_screen(melhor)
		var res: String = args.get("res", "3840x2160")
		if res == "tela":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			var p := res.split("x")
			DisplayServer.window_set_position(DisplayServer.screen_get_position(melhor))
			DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		_bench_perfil.call_deferred()
	if args.has("pular"):
		_pular_para(int(args["pular"]))
	if autoplay or bench or args.has("direto") or args.has("teste_clique") or args.has("retrato"):
		iniciar_jogo()
		if args.has("teste_clique"):
			_teste_cliques()
		if args.has("retrato"):
			_retrato()
	else:
		_menu_titulo()
		if args.has("titulo") and args.has("shots"):
			await get_tree().create_timer(5.0).timeout
			_salvar_shot("titulo")
			get_tree().quit()


# ------------------------------------------------------------------ teste de interface: só eventos de mouse/teclado
func _evento_mouse(p: Vector2, botao := MOUSE_BUTTON_LEFT) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await get_tree().process_frame
	for apertado in [true, false]:
		var b := InputEventMouseButton.new()
		b.position = p
		b.global_position = p
		b.button_index = botao
		b.pressed = apertado
		Input.parse_input_event(b)
		await get_tree().process_frame


func _tecla(k: Key) -> void:
	for apertado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = apertado
		Input.parse_input_event(e)
		await get_tree().process_frame


func _esperar_estado(alvos: Array, limite := 20.0) -> bool:
	var t0 := tempo_jogo
	while not (estado in alvos):
		await get_tree().process_frame
		if tempo_jogo - t0 > limite:
			return false
	return true


func _teste_cliques() -> void:
	var r: PackedStringArray = []
	await get_tree().create_timer(1.5, false).timeout
	# 1) andar clicando no chão
	var c0 := heroi.celula
	await _evento_mouse(cam.cam.unproject_position(mapa.mundo(Vector2i(11, 27))))
	await get_tree().create_timer(2.5, false).timeout
	r.append("andar: %s -> %s (estado %d, combate %s)" % [c0, heroi.celula, estado, em_combate])
	# 2) turnos por clique
	var acoes := 0
	while em_combate and acoes < 30:
		if not await _esperar_estado([E.TURNO_HEROI, E.FIM], 30.0):
			r.append("timeout esperando turno")
			break
		if estado == E.FIM:
			break
		await get_tree().create_timer(0.3, false).timeout
		var adj: Array[Unidade] = []
		for u in _inimigos_vivos(sala):
			if Mapa.cheb(u.celula, heroi.celula) == 1:
				adj.append(u)
		if adj.size() >= 2 and heroi.furia >= 30:
			await _tecla(KEY_2)
			r.append("tecla 2 -> modo %s" % modo)
			var f0 := heroi.furia
			await _evento_mouse(cam.cam.unproject_position(heroi.position + Vector3(0, 0.05, 0)))
			await get_tree().create_timer(1.8, false).timeout
			r.append("redemoinho: agiu=%s fúria %d -> %d" % [agiu, f0, heroi.furia])
			if estado == E.TURNO_HEROI:
				await _tecla(KEY_SPACE)
				r.append("espaço: encerrou turno")
		else:
			var alvo: Unidade = null
			for u in _inimigos_vivos(sala):
				if pode_golpear(heroi, u):
					alvo = u
			if alvo == null and not moveu:
				var perto := _inimigo_mais_proximo()
				var melhor := heroi.celula
				var md := 999
				for c in alc_heroi:
					if alc_heroi[c].get("ocupada", false):
						continue
					var d := Mapa.dist(c, perto.celula)
					if d < md:
						md = d
						melhor = c
				await _evento_mouse(cam.cam.unproject_position(mapa.mundo(melhor) + Vector3(0, 0.02, 0)))
				await _esperar_estado([E.TURNO_HEROI, E.OCUPADO, E.FIM], 5.0)
				await get_tree().create_timer(1.6, false).timeout
				r.append("clique chão %s -> herói em %s moveu=%s" % [melhor, heroi.celula, moveu])
				for u in _inimigos_vivos(sala):
					if pode_golpear(heroi, u):
						alvo = u
			if alvo and estado == E.TURNO_HEROI and not agiu:
				var hp0 := alvo.hp
				await _evento_mouse(cam.cam.unproject_position(alvo.pos_peito()))
				await get_tree().create_timer(1.4, false).timeout
				r.append("clique em %s: hp %d -> %d" % [alvo.nome, hp0, alvo.hp])
			if estado == E.TURNO_HEROI:
				await _tecla(KEY_SPACE)
				r.append("espaço: encerrou turno")
		acoes += 1
	await get_tree().create_timer(3.0, false).timeout
	r.append("fim: sala0 limpa=%s hp=%d estado=%d" % [salas_limpas.has(0), heroi.hp, estado])
	var f := FileAccess.open(args.get("log", "user://teste_clique.log"), FileAccess.WRITE)
	f.store_string("\n".join(r) + "\n")
	f.close()
	print("\n".join(r))
	get_tree().quit()


func _ler_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		if "=" in s:
			var kv := s.split("=", true, 1)
			args[kv[0]] = kv[1]
		else:
			args[s] = "1"
	bench = args.has("bench")
	Unidade.PBR_DESLIGADO = args.has("sem_pbr")
	autoplay = args.has("autoplay") or bench
	if args.has("tempo"):
		escala_tempo = float(args["tempo"])
		Engine.time_scale = escala_tempo


# ------------------------------------------------------------------ montagem
func _criar_unidades() -> void:
	heroi = _nova_unidade("heroi", Dados.INICIO_HEROI)
	heroi.dormindo = false
	heroi.virar(Vector2i(0, -1), 0.0)
	for i in Dados.SALAS.size():
		for e in Dados.SALAS[i]["inimigos"]:
			var u := _nova_unidade(e[0], e[1])
			u.sala = i
			u.virar(Vector2i(0, 1), 0.0)
			spawns[u] = e[1]


func _nova_unidade(t: String, c: Vector2i) -> Unidade:
	var u := Unidade.new()
	add_child(u)
	u.configurar(t, mapa, vfx, c)
	mapa.ocupante[c] = u
	unidades.append(u)
	return u


func _criar_overlays() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.94, 0.94)
	q.orientation = PlaneMesh.FACE_Y
	var sh := load("res://shaders/ladrilho.gdshader")
	for i in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var m := ShaderMaterial.new()
		m.shader = sh
		if i == 0:
			m.set_shader_parameter("preenchimento", 0.05)
			m.set_shader_parameter("intensidade", 1.5)
		else:
			m.set_shader_parameter("preenchimento", 0.13)
			m.set_shader_parameter("intensidade", 2.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		if i == 0:
			overlay_alcance = mi
		else:
			overlay_area = mi
	cursor = MeshInstance3D.new()
	var qc := QuadMesh.new()
	qc.size = Vector2(1.0, 1.0)
	qc.orientation = PlaneMesh.FACE_Y
	cursor.mesh = qc
	var mc := ShaderMaterial.new()
	mc.shader = load("res://shaders/cursor.gdshader")
	cursor.material_override = mc
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)


func _desenhar(mi: MultiMeshInstance3D, lista: Array) -> void:
	var mm := mi.multimesh
	mm.instance_count = lista.size()
	for i in lista.size():
		var c: Vector2i = lista[i][0]
		var cor: Color = lista[i][1]
		var y := mapa.y(c) + (0.04 if mi == overlay_alcance else 0.05)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, y, c.y)))
		mm.set_instance_color(i, cor)


# ------------------------------------------------------------------ fluxo de partida
func _menu_titulo() -> void:
	estado = E.MENU
	cam.focar(Vector3(11, 0.6, 5.5), true)
	cam.dist_alvo = 15.0
	cam.dist = 15.0
	cam.pitch = deg_to_rad(-34.0)
	cam.orbitar = true
	hud.mostrar_titulo(true)


func iniciar_jogo() -> void:
	hud.mostrar_titulo(false)
	cam.orbitar = false
	cam.pitch = deg_to_rad(-50.0)
	cam.yaw_alvo = deg_to_rad(45.0)
	cam.dist_alvo = 16.5
	cam.focar(heroi.position, true)
	estado = E.EXPLORAR
	hud.mostrar_hud(true)
	hud.atualizar_heroi()
	tempo_jogo = 0.0
	hud.banner("CRIPTA DE CINZAS", "Desça e enfrente Vorgath, o Chifrudo", Dados.COR_OURO, 3.2)
	hud.dica("Clique no chão para andar  ·  Roda do mouse: zoom  ·  Z / C: girar a câmera")
	_log("inicio")
	if autoplay:
		_auto_explorar()


func _process(delta: float) -> void:
	if estado != E.MENU and estado != E.FIM:
		tempo_jogo += delta
	if heroi and estado != E.MENU:
		var alvo := heroi.position
		if estado == E.OCUPADO and _unidade_ativa and is_instance_valid(_unidade_ativa) and _unidade_ativa.vivo:
			alvo = _unidade_ativa.position
		if _retrato_ligado:
			alvo = _retrato_pos
		cam.focar(alvo)
		mundo.atualizar_furo(cam.cam, heroi.position)
	if cam:
		mundo.atualizar_paredes(cam.yaw_alvo)
		mundo.focar_sombras(Vector2i(roundi(cam.alvo.x), roundi(cam.alvo.z)))
	if hud:
		hud.atualizar_barras(unidades, cam.cam, em_combate)
	if bench:
		_bench_amostrar(delta)
	if args.has("shots"):
		_shots_auto()


var _unidade_ativa: Unidade = null


func _pular_para(s: int) -> void:
	for u in unidades:
		if u.sala >= 0 and u.sala < s:
			u.vivo = false
			u.visible = false
			mapa.ocupante.erase(u.celula)
	for i in s:
		salas_limpas[i] = true
		var p: Vector2i = Dados.SALAS[i]["porta"]
		if mundo.portas.has(p):
			mundo.portas[p].queue_free()
			mundo.portas.erase(p)
			mapa.bloqueado.erase(p)
	var entrada := {1: Vector2i(11, 20), 2: Vector2i(11, 11)}
	if entrada.has(s):
		mapa.ocupante.erase(heroi.celula)
		heroi.celula = entrada[s]
		heroi.position = mapa.mundo(heroi.celula)
		mapa.ocupante[heroi.celula] = heroi
	sala = s


func _inimigos_vivos(s: int) -> Array[Unidade]:
	var r: Array[Unidade] = []
	for u in unidades:
		if u.vivo and u.time != 0 and u.sala == s:
			r.append(u)
	return r


func _checar_gatilho() -> int:
	for s in Dados.SALAS.size():
		if salas_limpas.has(s):
			continue
		var g: int = Dados.SALAS[s]["gatilho"]
		for u in _inimigos_vivos(s):
			if u.dormindo and Mapa.dist(heroi.celula, u.celula) <= g:
				return s
	return -1


func _explorar_para(c: Vector2i) -> void:
	var alc := mapa.alcance(heroi.celula, 80, heroi.pulo, 0)
	if not alc.has(c) or alc[c].get("ocupada", false):
		return
	var cam_ := mapa.caminho(alc, c)
	if cam_.size() < 2:
		return
	estado = E.OCUPADO
	_limpar_overlays()
	var gatilho := [-1]
	var cb := func() -> bool:
		gatilho[0] = _checar_gatilho()
		return gatilho[0] >= 0
	await heroi.andar(cam_, 0.27, cb)
	if gatilho[0] >= 0:
		await _iniciar_combate(gatilho[0])
	else:
		estado = E.EXPLORAR
		_atualizar_overlays()


func _iniciar_combate(s: int) -> void:
	em_combate = true
	sala = s
	estado = E.OCUPADO
	_limpar_overlays()
	var inimigos := _inimigos_vivos(s)
	for u in inimigos:
		u.dormindo = false
		u.ct = rng.randi_range(0, 35)
		u.virar_para(heroi.celula, 0.25)
	heroi.ct = 45
	snapshot = {"hp": heroi.hp, "furia": heroi.furia, "pocoes": heroi.pocoes, "celula": heroi.celula}
	stats_sala = {"turnos": 0, "hp_inicio": heroi.hp, "pocoes_inicio": heroi.pocoes, "t": tempo_jogo}
	Sons.tocar("encontro", -2.0)
	if s == 2:
		await _intro_chefe()
	else:
		hud.banner(Dados.SALAS[s]["nome"].to_upper(), "Encontro", Dados.COR_VERMELHO, 2.0)
		cam.tremer(0.15)
		await get_tree().create_timer(1.0, false).timeout
	hud.dica("Clique: mover / atacar  ·  1–4: habilidades  ·  Q: poção  ·  Espaço: esperar  ·  W A S D: virar")
	_log("combate sala=%d hp=%d" % [s, heroi.hp])
	_loop_turnos()


func _intro_chefe() -> void:
	var chefe := _chefe()
	cam.focar(chefe.position + Vector3(0, 0.5, 0))
	cam.dist_alvo = 14.0
	await get_tree().create_timer(0.8, false).timeout
	chefe.tocar("cast", 0.1)
	await get_tree().create_timer(0.45, false).timeout
	Sons.tocar("rugido", 0.0)
	vfx.onda(chefe.position + Vector3(0, 0.05, 0), Color(1.0, 0.3, 0.1), 5.0, 0.8, 3.0)
	vfx.flash_luz(chefe.pos_peito(), Color(1.0, 0.3, 0.1), 10.0, 0.8, 8.0)
	cam.tremer(0.6)
	hud.banner(chefe.nome.to_upper(), Dados.TIPOS["chefe"]["titulo"], Dados.COR_LENDARIO, 2.6)
	hud.barra_chefe(chefe)
	await get_tree().create_timer(1.6, false).timeout
	cam.dist_alvo = 16.5


func _chefe() -> Unidade:
	for u in unidades:
		if u.tipo == "chefe":
			return u
	return null


func _proximo() -> Unidade:
	var todos: Array[Unidade] = [heroi]
	todos.append_array(_inimigos_vivos(sala))
	for _i in 200:
		var pronto: Unidade = null
		for u in todos:
			if u.ct >= 100 and (pronto == null or u.ct > pronto.ct):
				pronto = u
		if pronto:
			return pronto
		for u in todos:
			u.ct += u.vel
	return heroi


func previsao_turnos(n: int) -> Array[Unidade]:
	var todos: Array[Unidade] = [heroi]
	todos.append_array(_inimigos_vivos(sala))
	var cts := {}
	for u in todos:
		cts[u] = u.ct
	var r: Array[Unidade] = []
	var guarda := 0
	while r.size() < n and guarda < 500:
		guarda += 1
		var pronto: Unidade = null
		for u in todos:
			if cts[u] >= 100 and (pronto == null or cts[u] > cts[pronto]):
				pronto = u
		if pronto:
			r.append(pronto)
			cts[pronto] -= 100
		else:
			for u in todos:
				cts[u] += u.vel
	return r


func _custo_ct(m: bool, a: bool) -> int:
	if m and a:
		return 100
	if m or a:
		return 80
	return 60


func _loop_turnos() -> void:
	while em_combate:
		if not heroi.vivo:
			await _derrota()
			return
		if _inimigos_vivos(sala).is_empty():
			await _vitoria_sala()
			return
		var u := _proximo()
		hud.ordem_turnos(previsao_turnos(8))
		if u.atordoado > 0:
			u.atordoado -= 1
			vfx.numero(u.pos_cabeca() + Vector3(0, 0.3, 0), "ATORDOADO", Color(0.75, 0.8, 1.0), 40)
			u.ct -= 60
			await get_tree().create_timer(0.55, false).timeout
			continue
		if u == heroi:
			stats["turnos"] += 1
			stats_sala["turnos"] = stats_sala.get("turnos", 0) + 1
			await _turno_heroi()
		else:
			estado = E.OCUPADO
			_unidade_ativa = u
			u.mostrar_anel(true, true)
			hud.unidade_ativa(u)
			await get_tree().create_timer(0.3, false).timeout
			if not heroi.vivo:
				continue
			var r: Dictionary = await ia.turno(u)
			u.mostrar_anel(false)
			u.ct -= _custo_ct(r.get("moveu", false), r.get("agiu", false))
			_unidade_ativa = null
			hud.atualizar_heroi()
			await get_tree().create_timer(0.2, false).timeout


func _turno_heroi() -> void:
	estado = E.TURNO_HEROI
	moveu = false
	agiu = false
	virou_manual = false
	modo = "mover"
	heroi.mostrar_anel(true, true)
	hud.unidade_ativa(heroi)
	alc_heroi = mapa.alcance(heroi.celula, heroi.mov, heroi.pulo, 0)
	hud.banner_curto("SEU TURNO")
	hud.atualizar_heroi()
	_atualizar_overlays()
	if autoplay:
		_ia_heroi.call_deferred()
	await fim_turno_heroi
	heroi.mostrar_anel(false)
	_limpar_overlays()
	if not virou_manual:
		var perto := _inimigo_mais_proximo()
		if perto:
			heroi.virar_para(perto.celula)
	heroi.ct -= _custo_ct(moveu, agiu)
	estado = E.OCUPADO


func _inimigo_mais_proximo() -> Unidade:
	var melhor: Unidade = null
	var md := 999
	for u in _inimigos_vivos(sala):
		var d := Mapa.dist(u.celula, heroi.celula)
		if d < md:
			md = d
			melhor = u
	return melhor


func encerrar_turno() -> void:
	if estado == E.TURNO_HEROI:
		modo = "mover"
		fim_turno_heroi.emit()


func _checar_fim_turno() -> void:
	if _inimigos_vivos(sala).is_empty() or not heroi.vivo:
		await get_tree().create_timer(0.3, false).timeout
		encerrar_turno()
		return
	if moveu and agiu:
		await get_tree().create_timer(0.35, false).timeout
		encerrar_turno()


# ------------------------------------------------------------------ entrada
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_atualizar_hover((ev as InputEventMouseMotion).position)
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_clique()
			MOUSE_BUTTON_RIGHT:
				cancelar_modo()
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom(-1.2)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom(1.2)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		match k:
			KEY_ESCAPE:
				if modo != "mover":
					cancelar_modo()
				elif estado != E.MENU and estado != E.FIM:
					hud.alternar_pausa()
			KEY_1:
				selecionar("golpe")
			KEY_2:
				selecionar("redemoinho")
			KEY_3:
				selecionar("investida")
			KEY_4:
				selecionar("martelo")
			KEY_Q:
				usar_pocao()
			KEY_SPACE:
				encerrar_turno()
			KEY_Z, KEY_BRACKETLEFT:
				cam.girar(-1)
			KEY_C, KEY_BRACKETRIGHT:
				cam.girar(1)
			KEY_W, KEY_A, KEY_S, KEY_D:
				_virar_tecla(k)
			KEY_F11:
				_alternar_tela_cheia()
			KEY_ENTER:
				if (ev as InputEventKey).alt_pressed:
					_alternar_tela_cheia()
			KEY_F3:
				hud.alternar_fps()


func _alternar_tela_cheia() -> void:
	var m := DisplayServer.window_get_mode()
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _virar_tecla(k: Key) -> void:
	if estado != E.TURNO_HEROI:
		return
	# direções relativas à câmera
	var f := -cam.cam.global_transform.basis.z
	f.y = 0
	f = f.normalized()
	var r := cam.cam.global_transform.basis.x
	r.y = 0
	r = r.normalized()
	var v := f if k == KEY_W else (-f if k == KEY_S else (-r if k == KEY_A else r))
	var d := Vector2i(int(round(v.x)), int(round(v.z))) if absf(v.x) > absf(v.z) else Vector2i(0, int(signf(v.z)))
	if absf(v.x) > absf(v.z):
		d = Vector2i(int(signf(v.x)), 0)
	heroi.virar(d)
	virou_manual = true


func _pegar_celula(tela: Vector2) -> Vector2i:
	var o := cam.cam.project_ray_origin(tela)
	var n := cam.cam.project_ray_normal(tela)
	# unidades primeiro (corpo inteiro clicável)
	var melhor: Unidade = null
	var md := 1e9
	for u in unidades:
		if not u.vivo or not u.visible:
			continue
		var base := u.global_position
		var topo := base + Vector3(0, u.altura, 0)
		var d := _dist_raio_segmento(o, n, base, topo)
		var raio := 0.32 * clampf(u.altura, 0.8, 1.6)
		if d < raio:
			var t := (base - o).dot(n)
			if t < md:
				md = t
				melhor = u
	if melhor and melhor != heroi:
		return melhor.celula
	for nivel in [2, 1, 0]:
		var y := float(nivel) * Dados.NIVEL
		if absf(n.y) < 0.0001:
			continue
		var t := (y - o.y) / n.y
		if t < 0:
			continue
		var p := o + n * t
		var c := Vector2i(roundi(p.x), roundi(p.z))
		if mapa.eh_piso(c) and mapa.h(c) == nivel:
			return c
	return Vector2i(-99, -99)


func _dist_raio_segmento(o: Vector3, n: Vector3, a: Vector3, b: Vector3) -> float:
	var u := n
	var v := b - a
	var w := o - a
	var aa := u.dot(u)
	var bb := u.dot(v)
	var cc := v.dot(v)
	var dd := u.dot(w)
	var ee := v.dot(w)
	var den := aa * cc - bb * bb
	var sc := 0.0
	var tc := 0.0
	if den < 1e-6:
		tc = clampf(ee / cc, 0.0, 1.0)
	else:
		sc = (bb * ee - cc * dd) / den
		tc = clampf((aa * ee - bb * dd) / den, 0.0, 1.0)
	return ((o + u * sc) - (a + v * tc)).length()


func _atualizar_hover(tela: Vector2) -> void:
	if estado == E.MENU:
		return
	var c := _pegar_celula(tela)
	if unidade_hover and is_instance_valid(unidade_hover):
		unidade_hover.destacar(false)
	celula_hover = c
	unidade_hover = mapa.ocupante.get(c) as Unidade
	if unidade_hover and unidade_hover.time != 0 and unidade_hover.vivo:
		unidade_hover.destacar(true)
	hud.info_alvo(unidade_hover if unidade_hover and unidade_hover.vivo and not unidade_hover.dormindo else null)
	if mapa.eh_piso(c):
		cursor.visible = true
		cursor.position = mapa.mundo(c) + Vector3(0, 0.06, 0)
	else:
		cursor.visible = false
	_atualizar_overlays()


# ------------------------------------------------------------------ modos e destaques
func selecionar(id: String) -> void:
	if estado != E.TURNO_HEROI or agiu:
		return
	var hab: Dictionary = Dados.HABILIDADES[id]
	if heroi.furia < hab["custo"]:
		hud.aviso("Fúria insuficiente")
		Sons.tocar("negado", -6.0)
		return
	if modo == id:
		cancelar_modo()
		return
	modo = id
	Sons.tocar("clique", -8.0)
	hud.modo_habilidade(id)
	if id == "redemoinho":
		hud.dica("Clique no herói (ou em qualquer casa destacada) para girar  ·  Botão direito: cancelar")
	elif id == "investida":
		hud.dica("Escolha uma linha: o herói avança até o primeiro inimigo  ·  Botão direito: cancelar")
	elif id == "martelo":
		hud.dica("Escolha o centro da cruz (até 3 casas)  ·  Botão direito: cancelar")
	else:
		hud.dica("Escolha um inimigo adjacente  ·  Botão direito: cancelar")
	_atualizar_overlays()


func cancelar_modo() -> void:
	if modo != "mover":
		modo = "mover"
		hud.modo_habilidade("")
		hud.dica("Clique: mover / atacar  ·  1–4: habilidades  ·  Q: poção  ·  Espaço: esperar  ·  W A S D: virar")
		_atualizar_overlays()


func _limpar_overlays() -> void:
	_desenhar(overlay_alcance, [])
	_desenhar(overlay_area, [])
	hud.previsao("")


const AZUL := Color(0.18, 0.45, 1.0, 1.0)
const AZUL_CAMINHO := Color(0.55, 0.8, 1.0, 1.0)
const VERMELHO := Color(1.0, 0.22, 0.15, 1.0)
const OURO := Color(1.0, 0.72, 0.28, 1.0)
const LARANJA := Color(1.0, 0.45, 0.12, 1.0)


func pode_golpear(a: Unidade, b: Unidade) -> bool:
	return b and b.vivo and b.time != a.time and Mapa.dist(a.celula, b.celula) == 1 and absi(mapa.h(a.celula) - mapa.h(b.celula)) <= 2


func linha_investida(d: Vector2i) -> Dictionary:
	var cel: Array[Vector2i] = []
	var c := heroi.celula
	var alvo: Unidade = null
	for i in 5:
		var n := c + d
		if not mapa.caminhavel(n) or absi(mapa.h(n) - mapa.h(c)) > heroi.pulo:
			break
		if mapa.ocupante.has(n):
			var u: Unidade = mapa.ocupante[n]
			if u.time != 0 and u.vivo:
				alvo = u
			break
		cel.append(n)
		c = n
	return {"celulas": cel, "alvo": alvo}


func _atualizar_overlays() -> void:
	var a: Array = []
	var b: Array = []
	hud.previsao("")
	if estado == E.EXPLORAR:
		if mapa.caminhavel(celula_hover) and celula_hover != heroi.celula:
			var alc := mapa.alcance(heroi.celula, 80, heroi.pulo, 0)
			if alc.has(celula_hover):
				for c in mapa.caminho(alc, celula_hover):
					a.append([c, Color(AZUL_CAMINHO, 0.55)])
		if chefe_morto and not bau_aberto and mapa.piso.get(celula_hover, "") == "C":
			b.append([celula_hover, OURO])
	elif estado == E.TURNO_HEROI:
		match modo:
			"mover":
				if not moveu:
					for c in alc_heroi:
						if c != heroi.celula and not alc_heroi[c].get("ocupada", false):
							a.append([c, AZUL])
					if alc_heroi.has(celula_hover) and not alc_heroi[celula_hover].get("ocupada", false) and celula_hover != heroi.celula:
						for c in mapa.caminho(alc_heroi, celula_hover):
							b.append([c, AZUL_CAMINHO])
				if not agiu:
					for u in _inimigos_vivos(sala):
						if pode_golpear(heroi, u):
							a.append([u.celula, VERMELHO])
					if unidade_hover and pode_golpear(heroi, unidade_hover):
						b.append([unidade_hover.celula, VERMELHO])
						_prever_dano(unidade_hover, 1.0)
			"golpe":
				for u in _inimigos_vivos(sala):
					if pode_golpear(heroi, u):
						a.append([u.celula, VERMELHO])
				if unidade_hover and pode_golpear(heroi, unidade_hover):
					b.append([unidade_hover.celula, VERMELHO])
					_prever_dano(unidade_hover, 1.0)
			"redemoinho":
				var n := 0
				for c in mapa.vizinhos8(heroi.celula):
					if mapa.eh_piso(c):
						var u: Unidade = mapa.ocupante.get(c)
						if u and u.time != 0:
							b.append([c, VERMELHO])
							n += 1
						else:
							a.append([c, OURO])
				hud.previsao("Redemoinho de Aço · %d alvo(s)" % n)
			"investida":
				for d in Mapa.DIRS:
					var L := linha_investida(d)
					var sob: bool = (celula_hover in L["celulas"]) or (L["alvo"] and celula_hover == L["alvo"].celula)
					for c in L["celulas"]:
						a.append([c, LARANJA if not sob else OURO])
					if L["alvo"]:
						(b if sob else a).append([L["alvo"].celula, VERMELHO])
						if sob:
							_prever_dano(L["alvo"], Dados.HABILIDADES["investida"]["mult"], L["celulas"].back() if L["celulas"].size() > 0 else heroi.celula)
			"martelo":
				for c in mapa.losango(heroi.celula, 3):
					a.append([c, Color(OURO, 0.55)])
				if Mapa.dist(celula_hover, heroi.celula) <= 3 and mapa.eh_piso(celula_hover):
					var n2 := 0
					for c in mapa.cruz(celula_hover):
						var u: Unidade = mapa.ocupante.get(c)
						b.append([c, VERMELHO if (u and u.time != 0) else LARANJA])
						if u and u.time != 0:
							n2 += 1
					hud.previsao("Martelo dos Céus · %d alvo(s) · atordoa" % n2)
	_desenhar(overlay_alcance, a)
	_desenhar(overlay_area, b)


func _prever_dano(alvo: Unidade, mult: float, de := Vector2i(-999, -999)) -> void:
	var origem := heroi.celula if de == Vector2i(-999, -999) else de
	var info := _dano_base(heroi, alvo, mult, origem)
	var txt := "%s · %d–%d de dano" % [alvo.nome, int(info["min"]), int(info["max"])]
	if info["lado"] == "costas":
		txt += " · COSTAS +50%"
	elif info["lado"] == "lado":
		txt += " · FLANCO +25%"
	if info["bloqueio"]:
		txt += " · ESCUDO −50%"
	hud.previsao(txt)


# ------------------------------------------------------------------ cliques
func _clique() -> void:
	if hud.bloqueando_clique():
		return
	var c := celula_hover
	match estado:
		E.EXPLORAR:
			if chefe_morto and not bau_aberto and mapa.piso.get(c, "") == "C":
				_abrir_bau()
			elif mapa.caminhavel(c) and not mapa.ocupante.has(c):
				_explorar_para(c)
		E.TURNO_HEROI:
			match modo:
				"mover":
					var alvo: Unidade = mapa.ocupante.get(c)
					if alvo and alvo.time != 0 and not agiu and pode_golpear(heroi, alvo):
						await acao_heroi("golpe", c)
					elif not moveu and alc_heroi.has(c) and not alc_heroi[c].get("ocupada", false) and c != heroi.celula:
						await mover_heroi(c)
				"golpe":
					var alvo2: Unidade = mapa.ocupante.get(c)
					if alvo2 and pode_golpear(heroi, alvo2):
						await acao_heroi("golpe", c)
				"redemoinho":
					if c == heroi.celula or Mapa.cheb(c, heroi.celula) == 1:
						await acao_heroi("redemoinho", c)
				"investida":
					for d in Mapa.DIRS:
						var L := linha_investida(d)
						if L["alvo"] and ((c in L["celulas"]) or c == L["alvo"].celula):
							await acao_heroi("investida", c, d)
							break
				"martelo":
					if Mapa.dist(c, heroi.celula) <= 3 and mapa.eh_piso(c):
						await acao_heroi("martelo", c)


func mover_heroi(c: Vector2i) -> void:
	estado = E.OCUPADO
	_limpar_overlays()
	var cam_ := mapa.caminho(alc_heroi, c)
	await mover_unidade(heroi, cam_)
	moveu = true
	estado = E.TURNO_HEROI
	hud.atualizar_heroi()
	_atualizar_overlays()
	_checar_fim_turno()


func mover_unidade(u: Unidade, caminho: Array[Vector2i]) -> void:
	_unidade_ativa = u
	await u.andar(caminho, 0.28 if u.tipo != "chefe" else 0.34)


func usar_pocao() -> void:
	if estado != E.TURNO_HEROI or agiu:
		return
	if heroi.pocoes <= 0:
		hud.aviso("Sem poções")
		Sons.tocar("negado", -6.0)
		return
	if heroi.hp >= heroi.hp_max:
		hud.aviso("Vida cheia")
		return
	await acao_heroi("pocao", heroi.celula)


func acao_heroi(id: String, c: Vector2i, d := Vector2i.ZERO) -> void:
	estado = E.OCUPADO
	_limpar_overlays()
	hud.modo_habilidade("")
	match id:
		"golpe":
			var alvo: Unidade = mapa.ocupante[c]
			await ataque_corpo(heroi, alvo, 1.0)
			heroi.furia = mini(Dados.FURIA_MAX, heroi.furia + 15)
		"redemoinho":
			heroi.furia -= Dados.HABILIDADES["redemoinho"]["custo"]
			await _redemoinho()
		"investida":
			heroi.furia -= Dados.HABILIDADES["investida"]["custo"]
			await _investida(d)
		"martelo":
			heroi.furia -= Dados.HABILIDADES["martelo"]["custo"]
			await _martelo(c)
		"pocao":
			heroi.pocoes -= 1
			stats["pocoes"] += 1
			heroi.tocar("victory", 0.1, 1.6)
			Sons.tocar("pocao", -2.0)
			var cura := mini(Dados.POCAO_CURA, heroi.hp_max - heroi.hp)
			heroi.hp += cura
			vfx.cura(heroi.position)
			vfx.numero(heroi.pos_cabeca(), "+%d" % cura, Color(0.55, 1.0, 0.45), 60)
			heroi.flash(Color(1.0, 0.4, 0.35), 0.8)
			await get_tree().create_timer(0.7, false).timeout
			heroi.tocar("idle", 0.3)
	agiu = true
	modo = "mover"
	if heroi.vivo:
		estado = E.TURNO_HEROI
	hud.atualizar_heroi()
	_atualizar_overlays()
	_checar_fim_turno()


# ------------------------------------------------------------------ dano
func lado_ataque(c_atacante: Vector2i, alvo: Unidade) -> String:
	var d := Vector2(c_atacante - alvo.celula)
	if d.length() < 0.01:
		return "frente"
	d = d.normalized()
	var dot := d.dot(Vector2(alvo.face))
	if dot > 0.5:
		return "frente"
	if dot < -0.5:
		return "costas"
	return "lado"


func _dano_base(a: Unidade, b: Unidade, mult: float, origem: Vector2i, ignorar_lado := false) -> Dictionary:
	var lado := "frente" if ignorar_lado else lado_ataque(origem, b)
	var m := mult
	if lado == "costas":
		m *= 1.5
	elif lado == "lado":
		m *= 1.25
	var bloqueio: bool = b.dados.get("escudo", false) and lado == "frente" and not ignorar_lado
	if bloqueio:
		m *= 0.5
	if mapa.h(origem) > mapa.h(b.celula):
		m *= 1.1
	var base := float(a.atk) * (1.25 if a.furioso else 1.0)
	return {"lado": lado, "bloqueio": bloqueio, "m": m, "base": base,
		"min": maxf(1.0, round(base * m * 0.9 - b.def)), "max": maxf(1.0, round(base * m * 1.1 - b.def))}


func calcular_dano(a: Unidade, b: Unidade, mult: float, ignorar_lado := false) -> Dictionary:
	var info := _dano_base(a, b, mult, a.celula, ignorar_lado)
	var d: float = info["base"] * info["m"] * rng.randf_range(0.9, 1.1)
	var crit := a == heroi and rng.randf() < 0.12
	if crit:
		d *= 1.5
	info["dano"] = int(maxf(1.0, round(d - b.def)))
	info["crit"] = crit
	return info


func aplicar_dano(alvo: Unidade, info: Dictionary, origem: Vector3, tipo_fx := "corte") -> void:
	if not alvo.vivo:
		return
	var dano: int = info["dano"]
	alvo.hp = maxi(0, alvo.hp - dano)
	if alvo == heroi:
		stats["dano_recebido"] += dano
		heroi.furia = mini(Dados.FURIA_MAX, heroi.furia + 5)
		hud.dano_heroi(float(dano) / heroi.hp_max)
	else:
		stats["dano_causado"] += dano
	var crit: bool = info.get("crit", false)
	var cor := Color(1.0, 0.97, 0.9) if alvo != heroi else Color(1.0, 0.35, 0.3)
	if crit:
		cor = Color(1.0, 0.62, 0.15)
	vfx.numero(alvo.pos_cabeca(), str(dano) if not crit else "%d!" % dano, cor, 84 if crit else 64)
	if info.get("lado", "frente") == "costas":
		vfx.numero(alvo.pos_cabeca() + Vector3(0, 0.35, 0), "COSTAS", Color(1.0, 0.85, 0.4), 34, 0.6)
	elif info.get("bloqueio", false):
		vfx.numero(alvo.pos_cabeca() + Vector3(0, 0.35, 0), "BLOQUEADO", Color(0.7, 0.75, 0.85), 34, 0.6)
	if tipo_fx == "corte":
		var cor_f := Color(1.0, 0.7, 0.3)
		if alvo.tipo == "esqueleto":
			vfx.sangue_osso(alvo.pos_peito(), Color(0.88, 0.84, 0.72))
		elif alvo.tipo == "chefe" or alvo.tipo == "diabrete":
			vfx.sangue_osso(alvo.pos_peito(), Color(0.55, 0.06, 0.04))
			cor_f = Color(1.0, 0.4, 0.15)
		elif alvo == heroi:
			vfx.sangue_osso(alvo.pos_peito(), Color(0.5, 0.05, 0.04))
		vfx.faiscas(alvo.pos_peito(), cor_f, 30 if crit else 20, 1.3 if crit else 1.0)
	Sons.tocar("impacto" if not crit else "critico", -3.0, randf_range(0.92, 1.08))
	cam.tremer(0.28 if crit else (0.18 if alvo == heroi else 0.12))
	_parada(0.07 if crit else 0.045)
	alvo.sofrer(dano, origem)
	hud.atualizar_heroi()
	if alvo.hp <= 0:
		_matar(alvo)


func _parada(dur: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = escala_tempo


func _matar(u: Unidade) -> void:
	if u == heroi:
		heroi.morrer()
		return
	Sons.tocar("morte", -4.0, randf_range(0.9, 1.1))
	heroi.furia = mini(Dados.FURIA_MAX, heroi.furia + 10)
	if u.tipo == "chefe":
		await _morte_chefe(u)
	else:
		u.morrer()
	hud.atualizar_heroi()


func ataque_corpo(a: Unidade, b: Unidade, mult: float) -> void:
	a.virar_para(b.celula, 0.1)
	await get_tree().create_timer(0.08, false).timeout
	var info := calcular_dano(a, b, mult)
	a.golpear(b.position)
	Sons.tocar("espada", -6.0, randf_range(0.9, 1.15))
	await a.impacto
	var cor := Color(1.0, 0.72, 0.32) if a == heroi else Color(1.0, 0.3, 0.2)
	vfx.rastro_golpe(a.pos_peito(), b.pos_peito(), cor, rng.randf_range(-35.0, 35.0), clampf(a.altura * 0.8, 0.8, 1.6))
	aplicar_dano(b, info, a.position)
	await get_tree().create_timer(0.45, false).timeout


func _redemoinho() -> void:
	heroi.tocar("spin", 0.08)
	Sons.tocar("giro", -2.0)
	await get_tree().create_timer(0.18, false).timeout
	vfx.redemoinho(heroi.position)
	var tw := create_tween()
	tw.tween_property(heroi.corpo, "rotation:y", heroi.corpo.rotation.y - TAU * 1.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.25, false).timeout
	for c in mapa.vizinhos8(heroi.celula):
		var u: Unidade = mapa.ocupante.get(c)
		if u and u.time != 0 and u.vivo and absi(mapa.h(c) - mapa.h(heroi.celula)) <= 2:
			var info := calcular_dano(heroi, u, Dados.HABILIDADES["redemoinho"]["mult"])
			aplicar_dano(u, info, heroi.position)
	await tw.finished
	heroi.virar(heroi.face, 0.05)
	heroi.tocar("idle", 0.25)
	await get_tree().create_timer(0.35, false).timeout


func _investida(d: Vector2i) -> void:
	var L := linha_investida(d)
	var alvo: Unidade = L["alvo"]
	if alvo == null:
		return
	var cel: Array[Vector2i] = L["celulas"]
	heroi.virar(d, 0.06)
	Sons.tocar("investida", -2.0)
	if cel.size() > 0:
		var caminho: Array[Vector2i] = [heroi.celula]
		caminho.append_array(cel)
		for c in cel:
			vfx.poeira_passo(mapa.mundo(c), 6, 0.35)
		await heroi.andar(caminho, 0.085)
	heroi.virar(d, 0.0)
	var info := calcular_dano(heroi, alvo, Dados.HABILIDADES["investida"]["mult"])
	heroi.golpear(alvo.position)
	await heroi.impacto
	vfx.rastro_golpe(heroi.pos_peito(), alvo.pos_peito(), Color(1.0, 0.6, 0.25), 0.0, 1.3)
	vfx.onda(alvo.position + Vector3(0, 0.05, 0), Color(1.0, 0.6, 0.25), 1.6, 0.4)
	aplicar_dano(alvo, info, heroi.position)
	if alvo.vivo and alvo.tipo != "chefe":
		var dest := alvo.celula + d
		if mapa.caminhavel(dest) and not mapa.ocupante.has(dest) and absi(mapa.h(dest) - mapa.h(alvo.celula)) <= 1:
			mapa.ocupante.erase(alvo.celula)
			alvo.celula = dest
			mapa.ocupante[dest] = alvo
			var tw := create_tween()
			tw.tween_property(alvo, "position", mapa.mundo(dest), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			vfx.poeira_passo(mapa.mundo(dest), 10, 0.45)
		alvo.atordoado = 1
		vfx.numero(alvo.pos_cabeca() + Vector3(0, 0.4, 0), "ATORDOADO", Color(0.75, 0.8, 1.0), 36, 0.7)
	elif alvo.vivo:
		vfx.numero(alvo.pos_cabeca() + Vector3(0, 0.4, 0), "IMUNE", Color(0.8, 0.8, 0.8), 34, 0.6)
	await get_tree().create_timer(0.55, false).timeout


func _martelo(c: Vector2i) -> void:
	heroi.virar_para(c, 0.1)
	heroi.tocar("victory", 0.1, 1.5)
	Sons.tocar("carga", -4.0)
	vfx.flash_luz(heroi.pos_cabeca() + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.5), 5.0, 0.5, 4.0)
	await get_tree().create_timer(0.42, false).timeout
	Sons.tocar("trovao", 0.0)
	var area := mapa.cruz(c)
	vfx.raio_sagrado(mapa.mundo(c))
	for x in area:
		if x != c:
			vfx.faiscas(mapa.mundo(x) + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.45), 16, 1.2)
	await get_tree().create_timer(0.08, false).timeout
	for x in area:
		var u: Unidade = mapa.ocupante.get(x)
		if u and u.time != 0 and u.vivo:
			var info := calcular_dano(heroi, u, Dados.HABILIDADES["martelo"]["mult"], true)
			aplicar_dano(u, info, mapa.mundo(c), "raio")
			if u.vivo:
				if u.tipo != "chefe":
					u.atordoado = 1
					vfx.numero(u.pos_cabeca() + Vector3(0, 0.4, 0), "ATORDOADO", Color(0.75, 0.8, 1.0), 36, 0.7)
				else:
					vfx.numero(u.pos_cabeca() + Vector3(0, 0.4, 0), "IMUNE", Color(0.8, 0.8, 0.8), 34, 0.6)
	await get_tree().create_timer(0.6, false).timeout
	heroi.tocar("idle", 0.3)


# ------------------------------------------------------------------ inimigos especiais
func bola_de_fogo(u: Unidade, alvo: Unidade) -> void:
	u.virar_para(alvo.celula, 0.12)
	u.tocar("cast", 0.1)
	Sons.tocar("conjurar", -6.0)
	await get_tree().create_timer(0.5, false).timeout
	var de := u.global_position + Vector3(0, u.altura * 1.05, 0) + Vector3(-u.face.x, 0, -u.face.y) * -0.3
	Sons.tocar("fogo", -4.0)
	await vfx.bola_de_fogo(de, alvo.pos_peito())
	var info := calcular_dano(u, alvo, 1.0, true)
	aplicar_dano(alvo, info, u.position, "fogo")
	await get_tree().create_timer(0.35, false).timeout
	if u.vivo:
		u.tocar("idle", 0.3)


func clivar(u: Unidade, alvo: Unidade) -> void:
	u.virar_para(alvo.celula, 0.12)
	await get_tree().create_timer(0.1, false).timeout
	var frente := u.celula + u.face
	var lateral := Vector2i(u.face.y, u.face.x)
	var area: Array[Vector2i] = [frente, frente + lateral, frente - lateral]
	u.golpear(alvo.position, "attack", 0.5)
	Sons.tocar("espada", -2.0, 0.7)
	await u.impacto
	vfx.rastro_golpe(u.pos_peito(), mapa.mundo(frente) + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.12), rng.randf_range(-20.0, 20.0), 2.2, 0.3)
	vfx.onda(mapa.mundo(frente) + Vector3(0, 0.05, 0), Color(1.0, 0.3, 0.1), 1.8, 0.4)
	for c in area:
		var v: Unidade = mapa.ocupante.get(c)
		if v and v.time != u.time and v.vivo:
			var info := calcular_dano(u, v, 1.0)
			aplicar_dano(v, info, u.position)
	await get_tree().create_timer(0.6, false).timeout


func telegrafar(u: Unidade, celulas: Array[Vector2i], tipo: String) -> void:
	u.tocar("cast", 0.1)
	Sons.tocar("conjurar", -2.0, 0.7)
	await get_tree().create_timer(0.5, false).timeout
	if telegrafo_no:
		telegrafo_no.queue_free()
	telegrafo_no = vfx.telegrafo(celulas, mapa)
	estado_chefe["telegrafo"] = celulas
	estado_chefe["tipo"] = tipo
	cam.tremer(0.2)
	if tipo == "nova":
		hud.banner_curto("VORGATH PREPARA A CHAMA INFERNAL", Dados.COR_LENDARIO)
	else:
		hud.banner_curto("CINZAS ARDENTES CAEM SOBRE VOCÊ", Dados.COR_LENDARIO)
	hud.dica("Saia da área marcada antes do próximo turno de Vorgath!")
	await get_tree().create_timer(0.8, false).timeout
	if u.vivo:
		u.tocar("idle", 0.3)


func detonar_telegrafo(u: Unidade) -> void:
	var celulas: Array = estado_chefe.get("telegrafo", [])
	var tipo: String = estado_chefe.get("tipo", "nova")
	estado_chefe["telegrafo"] = []
	u.tocar("cast", 0.1)
	await get_tree().create_timer(0.45, false).timeout
	Sons.tocar("explosao", 0.0)
	vfx.pilares_de_fogo(celulas, mapa)
	if telegrafo_no:
		telegrafo_no.queue_free()
		telegrafo_no = null
	for c in celulas:
		var v: Unidade = mapa.ocupante.get(c)
		if v and v.time == 0 and v.vivo:
			var info := calcular_dano(u, v, 1.7 if tipo == "nova" else 1.5, true)
			aplicar_dano(v, info, mapa.mundo(c), "fogo")
	await get_tree().create_timer(0.7, false).timeout
	if u.vivo:
		u.tocar("idle", 0.3)


func invocar(u: Unidade) -> void:
	u.tocar("cast", 0.1)
	Sons.tocar("rugido", -3.0, 1.1)
	hud.banner_curto("VORGATH CONVOCA SEUS DIABRETES", Dados.COR_LENDARIO)
	await get_tree().create_timer(0.5, false).timeout
	var livres: Array[Vector2i] = []
	for c in mapa.losango(u.celula, 3):
		if mapa.livre(c) and Mapa.dist(c, u.celula) >= 2 and Mapa.dist(c, heroi.celula) >= 2:
			livres.append(c)
	livres.shuffle()
	for i in mini(2, livres.size()):
		var c := livres[i]
		vfx.portal(mapa.mundo(c))
		Sons.tocar("portal", -4.0)
		await get_tree().create_timer(0.35, false).timeout
		var d := _nova_unidade("diabrete", c)
		d.sala = sala
		d.dormindo = false
		d.ct = 40
		d.virar_para(heroi.celula, 0.0)
		d.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(d, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		invocados.append(d)
	await get_tree().create_timer(0.6, false).timeout
	if u.vivo:
		u.tocar("idle", 0.3)


func enfurecer(u: Unidade) -> void:
	u.set_param("brilho_extra", 0.9)
	u.flash(Color(1.0, 0.2, 0.05), 2.0)
	u.tocar("cast", 0.1)
	Sons.tocar("rugido", 0.0, 0.85)
	cam.tremer(0.5)
	vfx.onda(u.position + Vector3(0, 0.05, 0), Color(1.0, 0.15, 0.05), 4.0, 0.7)
	hud.banner_curto("VORGATH ENFURECE · +25% DE DANO", Dados.COR_VERMELHO)
	await get_tree().create_timer(1.0, false).timeout
	if u.vivo:
		u.tocar("idle", 0.3)


func _morte_chefe(u: Unidade) -> void:
	chefe_morto = true
	mundo.apagar_runa()
	Engine.time_scale = 0.3
	escala_tempo = 0.3
	cam.focar(u.position)
	cam.dist_alvo = 13.0
	Sons.tocar("rugido", 0.0, 0.6)
	u.morrer()
	vfx.explosao(u.pos_peito(), 1.6)
	cam.tremer(0.8)
	await get_tree().create_timer(0.9, true, false, true).timeout
	escala_tempo = float(args.get("tempo", "1.0"))
	Engine.time_scale = escala_tempo
	for v in _inimigos_vivos(sala):
		if v != u:
			v.hp = 0
			v.morrer()
	if telegrafo_no:
		telegrafo_no.queue_free()
		telegrafo_no = null
	estado_chefe["telegrafo"] = []
	cam.dist_alvo = 16.5


# ------------------------------------------------------------------ fim de sala, derrota e baú
func _vitoria_sala() -> void:
	em_combate = false
	estado = E.OCUPADO
	salas_limpas[sala] = true
	hud.ordem_turnos([])
	_log("sala %d limpa: turnos=%d hp=%d/%d pocoes_usadas=%d" % [sala, stats_sala.get("turnos", 0), heroi.hp, heroi.hp_max, stats_sala.get("pocoes_inicio", 0) - heroi.pocoes])
	await get_tree().create_timer(1.2, false).timeout
	if sala == 2:
		hud.barra_chefe(null)
		hud.banner("VORGATH FOI DERROTADO", "O baú do Chifrudo aguarda", Dados.COR_LENDARIO, 3.5)
		Sons.tocar("vitoria", 0.0)
		feixe_bau = vfx.feixe_lendario(mundo.bau.global_position)
		hud.dica("Clique no baú para abri-lo")
	else:
		hud.banner("SALA PURIFICADA", "A porta selada se abre", Dados.COR_OURO, 2.6)
		Sons.tocar("porta", 0.0)
		mundo.abrir_porta(Dados.SALAS[sala]["porta"])
		cam.focar(mapa.mundo(Dados.SALAS[sala]["porta"]))
		hud.dica("Clique no chão para andar  ·  Roda do mouse: zoom  ·  Z / C: girar a câmera")
	# regeneração fora de combate, como em Diablo
	var falta := heroi.hp_max - heroi.hp
	if falta > 0:
		vfx.cura(heroi.position)
		var tw := create_tween()
		tw.tween_method(_hp_regen, float(heroi.hp), float(heroi.hp_max), 1.6)
	await get_tree().create_timer(1.8, false).timeout
	sala += 1
	estado = E.EXPLORAR
	_atualizar_overlays()
	if autoplay:
		_auto_explorar()


func _hp_regen(v: float) -> void:
	heroi.hp = int(v)
	hud.atualizar_heroi()


func _derrota() -> void:
	em_combate = false
	estado = E.FIM
	stats["mortes"] += 1
	_log("derrota sala=%d" % sala)
	Sons.tocar("derrota", 0.0)
	await get_tree().create_timer(1.6, false).timeout
	hud.tela_morte()
	if autoplay:
		await get_tree().create_timer(2.6, false).timeout
		if args.has("shots"):
			_salvar_shot("morte")
		if args.has("retentar") and stats["mortes"] == 1:
			tentar_de_novo()
			return
		_fim_autoplay(false)


func tentar_de_novo() -> void:
	hud.esconder_telas()
	# remove invocados e restaura a sala
	for d in invocados:
		mapa.ocupante.erase(d.celula)
		unidades.erase(d)
		d.queue_free()
	invocados.clear()
	if telegrafo_no:
		telegrafo_no.queue_free()
		telegrafo_no = null
	estado_chefe = {}
	for u in unidades:
		if u.sala == sala and u != heroi:
			mapa.ocupante.erase(u.celula)
			u.reviver()
			u.furioso = false
			u.set_param("brilho_extra", 0.0)
			u.atordoado = 0
			u.celula = spawns[u]
			u.position = mapa.mundo(u.celula)
			u.virar(Vector2i(0, 1), 0.0)
			mapa.ocupante[u.celula] = u
	mapa.ocupante.erase(heroi.celula)
	heroi.reviver()
	heroi.hp = heroi.hp_max
	heroi.furia = snapshot.get("furia", 20)
	heroi.pocoes = maxi(snapshot.get("pocoes", 3), 1)
	heroi.atordoado = 0
	heroi.celula = snapshot.get("celula", heroi.celula)
	heroi.position = mapa.mundo(heroi.celula)
	mapa.ocupante[heroi.celula] = heroi
	if sala == 2:
		hud.barra_chefe(null)
	hud.atualizar_heroi()
	_iniciar_combate(sala)


func voltar_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _abrir_bau() -> void:
	var alvo_cel := Vector2i(11, 2)
	estado = E.OCUPADO
	_limpar_overlays()
	if heroi.celula != alvo_cel:
		var alc := mapa.alcance(heroi.celula, 80, heroi.pulo, 0)
		if not alc.has(alvo_cel):
			estado = E.EXPLORAR
			return
		await heroi.andar(mapa.caminho(alc, alvo_cel), 0.27)
	heroi.virar(Vector2i(0, -1))
	await get_tree().create_timer(0.3, false).timeout
	heroi.tocar("attack", 0.1, 0.8)
	await get_tree().create_timer(0.45, false).timeout
	bau_aberto = true
	hud.dica("")
	Sons.tocar("bau", 0.0)
	mundo.abrir_bau()
	var p := mundo.bau.global_position + Vector3(0, 0.6, 0)
	vfx.flash_luz(p, Color(1.0, 0.65, 0.25), 14.0, 1.6, 9.0)
	vfx.faiscas(p, Color(1.0, 0.6, 0.2), 60, 1.4)
	vfx.alma(p, Color(1.0, 0.6, 0.2), 40)
	vfx.onda(mundo.bau.global_position + Vector3(0, 0.05, 0), Color(1.0, 0.6, 0.2), 3.0, 0.8)
	cam.tremer(0.3)
	cam.dist_alvo = 12.0
	await get_tree().create_timer(0.9, false).timeout
	heroi.tocar("victory", 0.2)
	Sons.tocar("lendario", 0.0)
	await get_tree().create_timer(0.8, false).timeout
	estado = E.FIM
	stats["tempo"] = tempo_jogo
	_log("vitoria tempo=%.1f turnos=%d dano_recebido=%d pocoes=%d mortes=%d" % [tempo_jogo, stats["turnos"], stats["dano_recebido"], stats["pocoes"], stats["mortes"]])
	hud.mostrar_loot(Dados.ITEM_LENDARIO)
	if autoplay:
		await get_tree().create_timer(2.0, false).timeout
		if args.has("shots"):
			_salvar_shot("loot")
			concluir_loot()
			await get_tree().create_timer(2.5, false).timeout
			_salvar_shot("vitoria")
		_fim_autoplay(true)


func _salvar_shot(nome: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [args["shots"], nome])


# ------------------------------------------------------------------ retrato fixo (capturas antes/depois, 11/11)
## --retrato=heroi|bruto|chefe|bau --saida=<arquivo.png> [--pular=N] [--res=3840x2160]
## Câmera fixa no alvo, quadro congelado (animação, luzes e tempo parados) e HUD escondida.
var _retrato_ligado := false
var _retrato_pos := Vector3.ZERO


func _retrato() -> void:
	var qual: String = args["retrato"]
	Engine.time_scale = 0.0 # nada anda: nem IA, nem gatilho de sala, nem tremor de luz
	mundo.tempo = 10.0
	var res: String = args.get("res", "3840x2160")
	var melhor := 0
	var area := 0
	for i in DisplayServer.get_screen_count():
		var sz := DisplayServer.screen_get_size(i)
		if sz.x * sz.y > area:
			area = sz.x * sz.y
			melhor = i
	DisplayServer.window_set_current_screen(melhor)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(melhor))
	var p := res.split("x")
	DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
	var alvo: Node3D = null
	for u in unidades:
		if u.tipo == qual and alvo == null:
			alvo = u
	if qual == "bau":
		alvo = mundo.bau
		for u in unidades:
			if u.tipo == "chefe":
				u.visible = false # o chefe fica na frente do baú nesta câmera
	_retrato_pos = alvo.global_position
	_retrato_ligado = true
	cam.yaw_alvo = deg_to_rad(float(args.get("yaw", "45")))
	cam.yaw = cam.yaw_alvo
	cam.dist_alvo = float(args.get("dist", "7.5"))
	cam.dist = cam.dist_alvo
	cam.focar(_retrato_pos, true)
	hud.visible = false
	if args.has("sem_particulas"): # medidas pixel a pixel: a poeira não congela igual entre rodadas
		for pp in _todos(self, "GPUParticles3D"):
			(pp as GPUParticles3D).visible = false
	for i in 20:
		await get_tree().process_frame
	for u in unidades:
		if u.anim and u.anim.has_animation("idle"):
			u.anim.play("idle", 0.0)
			u.anim.seek(0.5, true)
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args.get("saida", "user://retrato.png"))
	print("RETRATO %s -> %s" % [qual, args.get("saida", "")])
	get_tree().quit()


func concluir_loot() -> void:
	hud.tela_vitoria(stats)


# ------------------------------------------------------------------ autoplay (testes) e benchmark
func _log(s: String) -> void:
	var linha := "[%.1fs] %s" % [tempo_jogo, s]
	log_linhas.append(linha)
	if autoplay or bench:
		print(linha)


func _fim_autoplay(venceu: bool) -> void:
	if args.has("log"):
		var f := FileAccess.open(args["log"], FileAccess.WRITE)
		f.store_string("\n".join(log_linhas) + "\nRESULTADO " + ("vitoria" if venceu else "derrota") + "\n")
		f.close()
	if bench:
		_bench_relatorio()
	get_tree().quit()


func _auto_explorar() -> void:
	await get_tree().create_timer(0.6, false).timeout
	while estado == E.EXPLORAR or estado == E.OCUPADO:
		if estado == E.OCUPADO:
			await get_tree().create_timer(0.3, false).timeout
			continue
		if chefe_morto:
			_abrir_bau()
			return
		var alvos := _inimigos_vivos(sala)
		if alvos.is_empty():
			return
		var alc := mapa.alcance(heroi.celula, 80, heroi.pulo, 0)
		var dest := heroi.celula
		var md := 999
		for c in alc:
			if alc[c].get("ocupada", false):
				continue
			var d := Mapa.dist(c, alvos[0].celula)
			if d < md and d >= 2:
				md = d
				dest = c
		if dest == heroi.celula:
			return
		await _explorar_para(dest)
		if em_combate:
			return


func _ia_heroi() -> void:
	await get_tree().create_timer(0.25, false).timeout
	if estado != E.TURNO_HEROI:
		return
	var perigo: Array = estado_chefe.get("telegrafo", [])
	# 1) sair de área telegrafada
	if heroi.celula in perigo and not moveu:
		var melhor := heroi.celula
		var mp := 1e9
		for c in alc_heroi:
			if alc_heroi[c].get("ocupada", false) or c in perigo:
				continue
			var p := float(alc_heroi[c]["custo"])
			for u in _inimigos_vivos(sala):
				if Mapa.dist(c, u.celula) == 1:
					p -= 3.0
			if p < mp:
				mp = p
				melhor = c
		if melhor != heroi.celula:
			await mover_heroi(melhor)
	if estado != E.TURNO_HEROI:
		return
	# 2) poção
	if not agiu and heroi.hp < heroi.hp_max * 0.4 and heroi.pocoes > 0:
		await acao_heroi("pocao", heroi.celula)
	if estado != E.TURNO_HEROI:
		return
	# 3) habilidades e ataques
	if not agiu:
		await _ia_heroi_agir()
	if estado != E.TURNO_HEROI:
		return
	# 4) mover para perto de um inimigo e atacar
	if not moveu:
		var vivos := _inimigos_vivos(sala)
		var melhor2 := heroi.celula
		var mp2 := 1e9
		for c in alc_heroi:
			if alc_heroi[c].get("ocupada", false) or c in perigo:
				continue
			var p2 := 1e6
			for u in vivos:
				var d := Mapa.dist(c, u.celula)
				var v := float(d) * 10.0
				if d == 1:
					v = 0.0
					var l := lado_ataque(c, u)
					v -= 4.0 if l == "costas" else (2.0 if l == "lado" else 0.0)
					v += float(u.hp) / u.hp_max
				p2 = minf(p2, v)
			p2 += alc_heroi[c]["custo"] * 0.1
			if p2 < mp2:
				mp2 = p2
				melhor2 = c
		if melhor2 != heroi.celula:
			await mover_heroi(melhor2)
	if estado != E.TURNO_HEROI:
		return
	if not agiu:
		await _ia_heroi_agir()
	if estado == E.TURNO_HEROI:
		encerrar_turno()


func _ia_heroi_agir() -> void:
	var vivos := _inimigos_vivos(sala)
	if vivos.is_empty():
		return
	# Martelo dos Céus
	if heroi.furia >= 50:
		var melhor_c := Vector2i(-99, -99)
		var melhor_n := 0
		for c in mapa.losango(heroi.celula, 3):
			var n := 0
			for x in mapa.cruz(c):
				var u: Unidade = mapa.ocupante.get(x)
				if u and u.time != 0:
					n += 2 if u.tipo == "chefe" else 1
			if n > melhor_n:
				melhor_n = n
				melhor_c = c
		if melhor_n >= 2:
			await acao_heroi("martelo", melhor_c)
			return
	# Redemoinho
	if heroi.furia >= 30:
		var n2 := 0
		for c in mapa.vizinhos8(heroi.celula):
			var u: Unidade = mapa.ocupante.get(c)
			if u and u.time != 0:
				n2 += 1
		if n2 >= 2:
			await acao_heroi("redemoinho", heroi.celula)
			return
	# Golpe no adjacente mais fraco (preferindo costas)
	var alvo: Unidade = null
	var pa := 1e9
	for u in vivos:
		if pode_golpear(heroi, u):
			var p := float(u.hp)
			var l := lado_ataque(heroi.celula, u)
			if l == "costas":
				p -= 30
			if p < pa:
				pa = p
				alvo = u
	if alvo:
		await acao_heroi("golpe", alvo.celula)
		return
	# Investida
	if heroi.furia >= 25 and not moveu:
		for d in Mapa.DIRS:
			var L := linha_investida(d)
			if L["alvo"] and L["celulas"].size() >= 1:
				await acao_heroi("investida", L["alvo"].celula, d)
				return


var cpu_amostras: PackedFloat32Array = []
var draw_amostras: PackedFloat32Array = []


## Desliga recursos para medir o custo de cada um: --sem=sombras,filtro,nevoa,ssao,smaa,glow,particulas  --escala=0.8
func _bench_perfil() -> void:
	var sem: PackedStringArray = str(args.get("sem", "")).split(",", false)
	var vp := get_viewport()
	var e := mundo.ambiente.environment
	if "sombras" in sem:
		for l in _todos(self, "Light3D"):
			(l as Light3D).shadow_enabled = false
	if "filtro" in sem:
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	if "nevoa" in sem:
		e.volumetric_fog_enabled = false
	if "ssao" in sem:
		e.ssao_enabled = false
	if "glow" in sem:
		e.glow_enabled = false
	if "smaa" in sem:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if "pcss" in sem:
		for l in _todos(self, "Light3D"):
			(l as Light3D).light_size = 0.0
	if args.has("atlas"):
		RenderingServer.viewport_set_positional_shadow_atlas_size(vp.get_viewport_rid(), int(args["atlas"]), true)
	if "particulas" in sem:
		for p in _todos(self, "GPUParticles3D"):
			(p as GPUParticles3D).visible = false
	if args.has("escala"):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if args.get("upscale", "") == "metalfx" else Viewport.SCALING_3D_MODE_FSR2
		vp.scaling_3d_scale = float(args["escala"])
	var luzes := _todos(self, "Light3D")
	var com_sombra := 0
	for l in luzes:
		if (l as Light3D).shadow_enabled:
			com_sombra += 1
	print("PERFIL sem=%s luzes=%d com_sombra=%d particulas=%d" % [str(sem), luzes.size(), com_sombra, _todos(self, "GPUParticles3D").size()])


func _todos(n: Node, classe: String) -> Array:
	var r: Array = []
	for f in n.find_children("*", classe, true, false):
		r.append(f)
	return r


func _bench_amostrar(delta: float) -> void:
	if tempo_jogo < 3.0:
		return
	fps_amostras.append(1.0 / maxf(delta, 0.0001))
	cpu_amostras.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	draw_amostras.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	gpu_amostras.append(gpu)
	var limite := float(args.get("bench_s", "75"))
	if tempo_jogo > limite + 3.0:
		_bench_relatorio()
		get_tree().quit()


func _bench_relatorio() -> void:
	if fps_amostras.is_empty():
		return
	var s := Array(fps_amostras)
	s.sort()
	var soma := 0.0
	for v in s:
		soma += v
	var media := soma / s.size()
	var p1: float = s[int(s.size() * 0.01)]
	var g := Array(gpu_amostras)
	g.sort()
	var gsoma := 0.0
	for v in g:
		gsoma += v
	var cpu := 0.0
	for v in cpu_amostras:
		cpu += v
	var dr := 0.0
	for v in draw_amostras:
		dr += v
	var p5: float = s[int(s.size() * 0.05)]
	var txt := "BENCH res=%s sem=%s janela=%s amostras=%d fps_medio=%.1f fps_5%%=%.1f fps_1%%=%.1f fps_min=%.1f process_ms=%.2f draw_calls=%.0f" % [
		args.get("res", "?"), args.get("sem", "-") + (" escala=" + str(args["escala"]) if args.has("escala") else "") + (" atlas=" + str(args["atlas"]) if args.has("atlas") else ""), str(DisplayServer.window_get_size()), s.size(), media, p5, p1, s[0],
		cpu / maxf(cpu_amostras.size(), 1), dr / maxf(draw_amostras.size(), 1)]
	print(txt)
	if args.has("log"):
		var f := FileAccess.open(args["log"] + ".bench.txt", FileAccess.WRITE)
		f.store_string(txt + "\n")
		f.close()


var _shot_prox := 0.0
var _shot_i := 0


func _shots_auto() -> void:
	var intervalo := float(args.get("shot_int", "4.0"))
	if tempo_jogo >= _shot_prox and tempo_jogo > 1.5:
		_shot_prox = tempo_jogo + intervalo
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [args["shots"], _shot_i])
		_shot_i += 1
		if _shot_i >= int(args.get("shot_max", "12")):
			if not autoplay:
				get_tree().quit()
