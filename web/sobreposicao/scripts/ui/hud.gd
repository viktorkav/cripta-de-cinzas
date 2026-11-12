class_name Hud
extends CanvasLayer
## Interface inspirada em Diablo 4: orbes, barra de habilidades, ordem de turnos, chefe, menus e loot.

var j: Jogo
var raiz: Control
var camada_jogo: Control
var barras: CamadaBarras
var vinheta: ColorRect
var orbe_vida: Orbe
var orbe_furia: Orbe
var slots := {}
var lbl_dica: Label
var lbl_aviso: Label
var tooltip: Moldura
var tooltip_titulo: Label
var tooltip_texto: Label
var previa: Moldura
var previa_lbl: Label
var turnos: HBoxContainer
var chefe_barra: BarraChefe
var info: InfoAlvo
var banner_titulo: Label
var banner_sub: Label
var banner_caixa: Control
var banner_tw: Tween
var curto: Label
var curto_tw: Tween
var lbl_fps: Label
var lbl_pocoes: Label
var titulo: Control
var pausa: Control
var tela_fim: Control
var controles: Control
var acao_barra: Control

var f_titulo: FontVariation
var f_titulo_leve: FontVariation
var f_deco: Font
var f_corpo: Font
var f_corpo_b: Font
var f_italico: Font
var retratos := {}


func configurar(jogo: Jogo) -> void:
	j = jogo
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	f_titulo = FontVariation.new()
	f_titulo.base_font = load("res://assets/fonts/Cinzel.ttf")
	f_titulo.variation_opentype = {"wght": 700}
	f_titulo_leve = FontVariation.new()
	f_titulo_leve.base_font = load("res://assets/fonts/Cinzel.ttf")
	f_titulo_leve.variation_opentype = {"wght": 500}
	f_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	f_corpo = load("res://assets/fonts/Spectral-Regular.ttf")
	f_corpo_b = load("res://assets/fonts/Spectral-SemiBold.ttf")
	f_italico = load("res://assets/fonts/Spectral-Italic.ttf")
	for t in Dados.TIPOS:
		var p := "res://assets/ui/retrato_%s.png" % t
		if ResourceLoader.exists(p):
			retratos[t] = load(p)
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = _tema()
	add_child(raiz)
	_vinheta()
	camada_jogo = Control.new()
	camada_jogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada_jogo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada_jogo.visible = false
	raiz.add_child(camada_jogo)
	barras = CamadaBarras.new()
	barras.hud = self
	barras.set_anchors_preset(Control.PRESET_FULL_RECT)
	barras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada_jogo.add_child(barras)
	_barra_acao()
	_topo()
	_banners()
	_tooltips()
	_fps()
	_titulo()
	_pausa()
	_controles()
	tela_fim = Control.new()
	tela_fim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela_fim.visible = false
	raiz.add_child(tela_fim)


func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = f_corpo
	t.default_font_size = 20
	t.set_color("font_color", "Label", Dados.COR_TEXTO)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.045, 0.04, 0.92)
	normal.border_color = Dados.COR_BRONZE
	normal.set_border_width_all(2)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 34
	normal.content_margin_right = 34
	normal.shadow_color = Color(0, 0, 0, 0.6)
	normal.shadow_size = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.05, 0.04, 0.95)
	hover.border_color = Dados.COR_OURO
	var press := normal.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.32, 0.06, 0.04, 0.95)
	press.border_color = Dados.COR_OURO_CLARO
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", press)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", f_titulo)
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", Dados.COR_TEXTO)
	t.set_color("font_hover_color", "Button", Dados.COR_OURO_CLARO)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	return t


func _label(texto: String, fonte: Font, tam: int, cor: Color, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.horizontal_alignment = alinhar
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vinheta() -> void:
	vinheta = ColorRect.new()
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vinheta.gdshader")
	vinheta.material = m
	raiz.add_child(vinheta)


# ------------------------------------------------------------------ barra de ação (base da tela)
func _barra_acao() -> void:
	acao_barra = Control.new()
	acao_barra.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	acao_barra.position = Vector2(-560, -190)
	acao_barra.size = Vector2(1120, 190)
	acao_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada_jogo.add_child(acao_barra)
	var fundo := Moldura.new()
	fundo.position = Vector2(150, 92)
	fundo.size = Vector2(820, 92)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	acao_barra.add_child(fundo)
	orbe_vida = Orbe.new()
	orbe_vida.position = Vector2(0, 14)
	orbe_vida.size = Vector2(172, 172)
	orbe_vida.configurar(Color(0.88, 0.07, 0.05), Color(0.2, 0.0, 0.01), "VIDA", f_titulo, f_corpo_b)
	acao_barra.add_child(orbe_vida)
	orbe_furia = Orbe.new()
	orbe_furia.position = Vector2(948, 14)
	orbe_furia.size = Vector2(172, 172)
	orbe_furia.configurar(Color(1.0, 0.5, 0.08), Color(0.3, 0.07, 0.0), "FÚRIA", f_titulo, f_corpo_b)
	acao_barra.add_child(orbe_furia)
	var ids := ["golpe", "redemoinho", "investida", "martelo", "pocao", "esperar"]
	var x := 196.0
	for id in ids:
		var s := Slot.new()
		s.id = id
		s.hud = self
		s.position = Vector2(x, 100)
		s.size = Vector2(76, 76)
		acao_barra.add_child(s)
		slots[id] = s
		x += 98.0 if id != "martelo" else 136.0
	lbl_pocoes = _label("3", f_titulo, 20, Dados.COR_OURO_CLARO)
	lbl_pocoes.position = Vector2(slots["pocao"].position.x + 46, 150)
	lbl_pocoes.size = Vector2(28, 24)
	acao_barra.add_child(lbl_pocoes)
	lbl_dica = _label("", f_corpo, 19, Dados.COR_TEXTO_FRACO)
	lbl_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_dica.position = Vector2(-700, -232)
	lbl_dica.size = Vector2(1400, 30)
	camada_jogo.add_child(lbl_dica)
	lbl_aviso = _label("", f_titulo, 28, Color(1.0, 0.35, 0.3))
	lbl_aviso.set_anchors_preset(Control.PRESET_CENTER)
	lbl_aviso.position = Vector2(-400, 120)
	lbl_aviso.size = Vector2(800, 40)
	lbl_aviso.modulate.a = 0.0
	camada_jogo.add_child(lbl_aviso)


func clicar_slot(id: String) -> void:
	match id:
		"pocao":
			j.usar_pocao()
		"esperar":
			j.encerrar_turno()
		_:
			j.selecionar(id)


func atualizar_heroi() -> void:
	var h: Unidade = j.heroi
	if h == null:
		return
	orbe_vida.definir(float(h.hp) / h.hp_max, "%d / %d" % [h.hp, h.hp_max])
	orbe_furia.definir(float(h.furia) / Dados.FURIA_MAX, "%d" % h.furia)
	lbl_pocoes.text = str(h.pocoes)
	var turno: bool = j.estado == j.E.TURNO_HEROI
	for id in slots:
		var s: Slot = slots[id]
		var ok := turno and not j.agiu
		if Dados.HABILIDADES.has(id):
			ok = ok and h.furia >= Dados.HABILIDADES[id]["custo"]
		elif id == "pocao":
			ok = ok and h.pocoes > 0
		elif id == "esperar":
			ok = turno
		s.disponivel = ok
		s.queue_redraw()
	var frac := float(h.hp) / h.hp_max
	(vinheta.material as ShaderMaterial).set_shader_parameter("forca", 0.55 + (0.25 if frac < 0.3 else 0.0))


func modo_habilidade(id: String) -> void:
	for k in slots:
		slots[k].selecionado = (k == id)
		slots[k].queue_redraw()


func dica(t: String) -> void:
	lbl_dica.text = t


func aviso(t: String) -> void:
	lbl_aviso.text = t
	var tw := create_tween()
	lbl_aviso.modulate.a = 1.0
	tw.tween_interval(0.8)
	tw.tween_property(lbl_aviso, "modulate:a", 0.0, 0.5)


func dano_heroi(frac: float) -> void:
	var m := vinheta.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("dano", v), clampf(frac * 2.5, 0.25, 0.9), 0.0, 0.6)


# ------------------------------------------------------------------ topo: turnos, chefe, alvo
func _topo() -> void:
	var caixa := Control.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caixa.position = Vector2(-430, 14)
	caixa.size = Vector2(860, 100)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada_jogo.add_child(caixa)
	var lbl := _label("ORDEM DOS TURNOS", f_titulo, 14, Dados.COR_TEXTO_FRACO)
	lbl.position = Vector2(0, 0)
	lbl.size = Vector2(860, 18)
	lbl.name = "rotulo_turnos"
	lbl.visible = false
	caixa.add_child(lbl)
	turnos = HBoxContainer.new()
	turnos.position = Vector2(0, 22)
	turnos.size = Vector2(860, 76)
	turnos.alignment = BoxContainer.ALIGNMENT_CENTER
	turnos.add_theme_constant_override("separation", 8)
	turnos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(turnos)
	chefe_barra = BarraChefe.new()
	chefe_barra.hud = self
	chefe_barra.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chefe_barra.position = Vector2(-470, 118)
	chefe_barra.size = Vector2(940, 78)
	chefe_barra.visible = false
	camada_jogo.add_child(chefe_barra)
	info = InfoAlvo.new()
	info.hud = self
	info.position = Vector2(24, 24)
	info.size = Vector2(420, 132)
	info.visible = false
	camada_jogo.add_child(info)


func ordem_turnos(lista: Array) -> void:
	for c in turnos.get_children():
		c.queue_free()
	turnos.get_parent().get_node("rotulo_turnos").visible = lista.size() > 0
	var i := 0
	for u in lista:
		var r := Retrato.new()
		r.hud = self
		r.unidade = u
		r.primeiro = (i == 0)
		r.custom_minimum_size = Vector2(76, 76) if i == 0 else Vector2(60, 60)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		turnos.add_child(r)
		i += 1


func unidade_ativa(_u: Unidade) -> void:
	pass


func barra_chefe(u: Unidade) -> void:
	chefe_barra.unidade = u
	chefe_barra.visible = u != null
	if u:
		chefe_barra.atraso = 1.0
		chefe_barra.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(chefe_barra, "modulate:a", 1.0, 0.6)


func info_alvo(u: Unidade) -> void:
	info.unidade = u
	info.visible = u != null and u.time != 0
	info.queue_redraw()


func atualizar_barras(unidades: Array, cam: Camera3D, em_combate: bool) -> void:
	barras.unidades = unidades
	barras.cam = cam
	barras.ativo = em_combate
	barras.queue_redraw()
	if chefe_barra.visible:
		chefe_barra.queue_redraw()
	if info.visible:
		info.queue_redraw()
	if lbl_fps.visible:
		lbl_fps.text = "%d FPS · %dx%d" % [Engine.get_frames_per_second(), get_viewport().get_texture().get_width(), get_viewport().get_texture().get_height()]


# ------------------------------------------------------------------ banners e dicas
func _banners() -> void:
	banner_caixa = Control.new()
	banner_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_caixa.position = Vector2(-800, 210)
	banner_caixa.size = Vector2(1600, 160)
	banner_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_caixa.modulate.a = 0.0
	raiz.add_child(banner_caixa)
	var orn := Ornamento.new()
	orn.position = Vector2(500, 96)
	orn.size = Vector2(600, 20)
	banner_caixa.add_child(orn)
	banner_titulo = _label("", f_titulo, 66, Dados.COR_OURO)
	banner_titulo.size = Vector2(1600, 90)
	banner_titulo.add_theme_constant_override("shadow_outline_size", 14)
	banner_titulo.add_theme_color_override("font_shadow_color", Color(0.25, 0.02, 0.0, 0.85))
	banner_caixa.add_child(banner_titulo)
	banner_sub = _label("", f_italico, 28, Dados.COR_TEXTO)
	banner_sub.position = Vector2(0, 116)
	banner_sub.size = Vector2(1600, 40)
	banner_caixa.add_child(banner_sub)
	curto = _label("", f_titulo, 34, Dados.COR_OURO)
	curto.set_anchors_preset(Control.PRESET_CENTER_TOP)
	curto.position = Vector2(-800, 250)
	curto.size = Vector2(1600, 50)
	curto.modulate.a = 0.0
	curto.add_theme_constant_override("shadow_outline_size", 10)
	raiz.add_child(curto)


func banner(titulo_t: String, sub: String, cor: Color, dur := 2.4) -> void:
	banner_titulo.text = titulo_t
	banner_titulo.add_theme_color_override("font_color", cor)
	banner_sub.text = sub
	if banner_tw and banner_tw.is_valid():
		banner_tw.kill()
	banner_caixa.modulate.a = 0.0
	banner_caixa.scale = Vector2(1.06, 1.06)
	banner_caixa.pivot_offset = banner_caixa.size * 0.5
	banner_tw = create_tween()
	banner_tw.tween_property(banner_caixa, "modulate:a", 1.0, 0.35)
	banner_tw.parallel().tween_property(banner_caixa, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	banner_tw.tween_interval(dur)
	banner_tw.tween_property(banner_caixa, "modulate:a", 0.0, 0.6)


func banner_curto(t: String, cor := Dados.COR_OURO) -> void:
	curto.text = t
	curto.add_theme_color_override("font_color", cor)
	if curto_tw and curto_tw.is_valid():
		curto_tw.kill()
	curto.modulate.a = 0.0
	curto_tw = create_tween()
	curto_tw.tween_property(curto, "modulate:a", 1.0, 0.2)
	curto_tw.tween_interval(1.1)
	curto_tw.tween_property(curto, "modulate:a", 0.0, 0.4)


func _tooltips() -> void:
	tooltip = Moldura.new()
	tooltip.visible = false
	tooltip.size = Vector2(380, 170)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(tooltip)
	tooltip_titulo = _label("", f_titulo, 24, Dados.COR_OURO_CLARO, HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_titulo.position = Vector2(20, 14)
	tooltip_titulo.size = Vector2(340, 30)
	tooltip.add_child(tooltip_titulo)
	tooltip_texto = _label("", f_corpo, 18, Dados.COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_texto.position = Vector2(20, 54)
	tooltip_texto.size = Vector2(340, 100)
	tooltip_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.add_child(tooltip_texto)
	previa = Moldura.new()
	previa.cantos = false
	previa.visible = false
	previa.size = Vector2(460, 44)
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(previa)
	previa_lbl = _label("", f_corpo_b, 18, Dados.COR_OURO_CLARO)
	previa_lbl.position = Vector2(8, 8)
	previa_lbl.size = Vector2(444, 28)
	previa.add_child(previa_lbl)


func mostrar_tooltip(id: String, onde: Vector2) -> void:
	var titulo_t := ""
	var texto := ""
	if Dados.HABILIDADES.has(id):
		var h: Dictionary = Dados.HABILIDADES[id]
		titulo_t = h["nome"]
		texto = h["desc"]
		if h["custo"] > 0:
			texto += "\n[Custa %d de Fúria]" % h["custo"]
		texto += "\nTecla %s" % h["tecla"]
	elif id == "pocao":
		titulo_t = "Poção de Vida"
		texto = "Restaura %d de Vida. Usa a ação do turno.\nTecla Q" % Dados.POCAO_CURA
	elif id == "esperar":
		titulo_t = "Esperar"
		texto = "Encerra o turno. Quem não age volta antes na ordem dos turnos.\nTecla Espaço"
	tooltip_titulo.text = titulo_t
	tooltip_texto.text = texto
	tooltip.size = Vector2(380, 70 + 26 * (texto.count("\n") + 2))
	tooltip.position = onde + Vector2(-190, -tooltip.size.y - 16)
	tooltip.visible = true
	tooltip.queue_redraw()


func esconder_tooltip() -> void:
	tooltip.visible = false


func previsao(t: String) -> void:
	previa.visible = t != ""
	previa_lbl.text = t
	if t != "":
		var w := clampf(f_corpo_b.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 48, 220, 760)
		previa.size = Vector2(w, 44)
		previa_lbl.size = Vector2(w - 16, 28)
		var mp := get_viewport().get_mouse_position()
		previa.position = mp + Vector2(24, 26)
		previa.queue_redraw()


func _fps() -> void:
	lbl_fps = _label("", f_corpo_b, 16, Color(0.7, 0.9, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_fps.position = Vector2(-420, 10)
	lbl_fps.size = Vector2(400, 24)
	lbl_fps.visible = false
	raiz.add_child(lbl_fps)


func alternar_fps() -> void:
	lbl_fps.visible = not lbl_fps.visible


func mostrar_hud(on: bool) -> void:
	camada_jogo.visible = on


func bloqueando_clique() -> bool:
	return pausa.visible or tela_fim.visible or titulo.visible or controles.visible


# ------------------------------------------------------------------ título, pausa, controles
func _botao(t: String, cb: Callable, largura := 360.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(largura, 58)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sons.tocar("clique", -6.0))
	b.mouse_entered.connect(func(): Sons.tocar("hover", -16.0))
	return b


func _titulo() -> void:
	titulo = Control.new()
	titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	titulo.visible = false
	raiz.add_child(titulo)
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.25)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titulo.add_child(escuro)
	var t := _label("CRIPTA DE CINZAS", f_deco, 118, Dados.COR_OURO)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-900, 150)
	t.size = Vector2(1800, 150)
	t.add_theme_color_override("font_shadow_color", Color(0.5, 0.05, 0.0, 0.9))
	t.add_theme_constant_override("shadow_outline_size", 28)
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	titulo.add_child(t)
	var orn := Ornamento.new()
	orn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	orn.position = Vector2(-380, 300)
	orn.size = Vector2(760, 22)
	titulo.add_child(orn)
	var s := _label("Um recorte jogável de ARPG tático · Primeira masmorra", f_italico, 30, Dados.COR_TEXTO)
	s.set_anchors_preset(Control.PRESET_CENTER_TOP)
	s.position = Vector2(-700, 330)
	s.size = Vector2(1400, 44)
	titulo.add_child(s)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-180, 40)
	v.size = Vector2(360, 260)
	v.add_theme_constant_override("separation", 16)
	titulo.add_child(v)
	v.add_child(_botao("INICIAR", func(): j.iniciar_jogo()))
	v.add_child(_botao("CONTROLES", func(): controles.visible = true))
	v.add_child(_botao("TELA CHEIA", func(): j._alternar_tela_cheia()))
	if not OS.has_feature("web"):
		v.add_child(_botao("SAIR", func(): get_tree().quit()))
	var cred := _label("Personagens e cenário: Tripo · Agentic Canvas      ·      Código: Claude Opus 5.5      ·      Motor: Godot 4.7", f_corpo, 18, Dados.COR_TEXTO_FRACO)
	cred.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cred.position = Vector2(-900, -60)
	cred.size = Vector2(1800, 30)
	titulo.add_child(cred)


func mostrar_titulo(on: bool) -> void:
	titulo.visible = on
	if on:
		titulo.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(titulo, "modulate:a", 1.0, 1.4)


func _pausa() -> void:
	pausa = Control.new()
	pausa.set_anchors_preset(Control.PRESET_FULL_RECT)
	pausa.visible = false
	raiz.add_child(pausa)
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.6)
	pausa.add_child(escuro)
	var painel := Moldura.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.position = Vector2(-240, -250)
	painel.size = Vector2(480, 500)
	pausa.add_child(painel)
	var t := _label("PAUSA", f_titulo, 48, Dados.COR_OURO)
	t.position = Vector2(0, 30)
	t.size = Vector2(480, 60)
	painel.add_child(t)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 120)
	v.size = Vector2(360, 340)
	v.add_theme_constant_override("separation", 14)
	painel.add_child(v)
	v.add_child(_botao("CONTINUAR", func(): alternar_pausa()))
	v.add_child(_botao("CONTROLES", func(): controles.visible = true))
	v.add_child(_botao("TELA CHEIA", func(): j._alternar_tela_cheia()))
	v.add_child(_botao("MENU PRINCIPAL", _menu_da_pausa))
	if not OS.has_feature("web"):
		v.add_child(_botao("SAIR", func(): get_tree().quit()))


func _menu_da_pausa() -> void:
	get_tree().paused = false
	j.voltar_menu()


func alternar_pausa() -> void:
	pausa.visible = not pausa.visible
	get_tree().paused = pausa.visible
	if not pausa.visible:
		controles.visible = false


func _controles() -> void:
	controles = Control.new()
	controles.set_anchors_preset(Control.PRESET_FULL_RECT)
	controles.visible = false
	raiz.add_child(controles)
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.55)
	controles.add_child(escuro)
	var painel := Moldura.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.position = Vector2(-430, -330)
	painel.size = Vector2(860, 660)
	controles.add_child(painel)
	var t := _label("CONTROLES", f_titulo, 42, Dados.COR_OURO)
	t.position = Vector2(0, 26)
	t.size = Vector2(860, 56)
	painel.add_child(t)
	var linhas := [
		["Clique esquerdo", "Andar · atacar · confirmar alvo"],
		["Botão direito", "Cancelar habilidade"],
		["1  ·  2  ·  3  ·  4", "Golpe · Redemoinho · Investida · Martelo"],
		["Q", "Poção de vida"],
		["Espaço", "Esperar (encerrar o turno)"],
		["W  A  S  D", "Virar o herói (as costas tomam +50%)"],
		["Z  ·  C", "Girar a câmera 90°"],
		["Roda do mouse", "Zoom"],
		["F11 · Alt+Enter", "Tela cheia"],
		["F3", "Mostrar FPS"],
		["Esc", "Pausa"],
	]
	var y := 104.0
	for l in linhas:
		var a := _label(l[0], f_titulo, 21, Dados.COR_OURO_CLARO, HORIZONTAL_ALIGNMENT_RIGHT)
		a.position = Vector2(40, y)
		a.size = Vector2(300, 30)
		painel.add_child(a)
		var b := _label(l[1], f_corpo, 21, Dados.COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT)
		b.position = Vector2(370, y)
		b.size = Vector2(460, 30)
		painel.add_child(b)
		y += 40.0
	var reg := _label("Cada turno: mover e agir, em qualquer ordem. Quem age mais rápido joga mais vezes.\nAtacar pelas costas causa +50% de dano; pelo flanco, +25%. O Bruto bloqueia golpes de frente.", f_italico, 18, Dados.COR_TEXTO_FRACO)
	reg.position = Vector2(40, 552)
	reg.size = Vector2(780, 50)
	painel.add_child(reg)
	var bt := _botao("FECHAR", func(): controles.visible = false, 220.0)
	bt.position = Vector2(320, 596)
	painel.add_child(bt)


# ------------------------------------------------------------------ morte, loot e vitória
func esconder_telas() -> void:
	for c in tela_fim.get_children():
		c.queue_free()
	tela_fim.visible = false


func tela_morte() -> void:
	esconder_telas()
	tela_fim.visible = true
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0.12, 0.0, 0.0, 0.0)
	tela_fim.add_child(escuro)
	var t := _label("VOCÊ MORREU", f_titulo, 120, Color(0.75, 0.08, 0.06))
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-800, -170)
	t.size = Vector2(1600, 150)
	t.add_theme_constant_override("shadow_outline_size", 24)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	t.modulate.a = 0.0
	tela_fim.add_child(t)
	var v := HBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-380, 40)
	v.size = Vector2(760, 60)
	v.add_theme_constant_override("separation", 40)
	v.modulate.a = 0.0
	tela_fim.add_child(v)
	v.add_child(_botao("TENTAR DE NOVO", func(): j.tentar_de_novo()))
	v.add_child(_botao("MENU PRINCIPAL", func(): j.voltar_menu()))
	var tw := create_tween()
	tw.tween_property(escuro, "color:a", 0.65, 1.2)
	tw.parallel().tween_property(t, "modulate:a", 1.0, 1.6)
	tw.tween_property(v, "modulate:a", 1.0, 0.6)


func mostrar_loot(item: Dictionary) -> void:
	esconder_telas()
	tela_fim.visible = true
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.45)
	tela_fim.add_child(escuro)
	var card := Moldura.new()
	card.cor_borda = Dados.COR_LENDARIO
	card.cor_fio = Color(1.0, 0.7, 0.35)
	card.lendario = true
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-280, -290)
	card.size = Vector2(560, 560)
	tela_fim.add_child(card)
	var n := _label(item["nome"], f_titulo, 36, Dados.COR_LENDARIO)
	n.position = Vector2(0, 34)
	n.size = Vector2(560, 46)
	card.add_child(n)
	var tp := _label(item["tipo"], f_corpo_b, 22, Dados.COR_LENDARIO)
	tp.position = Vector2(0, 84)
	tp.size = Vector2(560, 30)
	card.add_child(tp)
	var pw := _label(item["poder"], f_corpo, 20, Dados.COR_TEXTO)
	pw.position = Vector2(0, 118)
	pw.size = Vector2(560, 28)
	card.add_child(pw)
	var orn := Ornamento.new()
	orn.cor = Dados.COR_LENDARIO
	orn.position = Vector2(60, 160)
	orn.size = Vector2(440, 18)
	card.add_child(orn)
	var y := 198.0
	for l in item["linhas"]:
		var marca := _label("◆", f_corpo, 15, Color(0.62, 0.72, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		marca.position = Vector2(48, y + 4)
		marca.size = Vector2(20, 30)
		card.add_child(marca)
		var a := _label(l, f_corpo, 21, Color(0.62, 0.72, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		a.position = Vector2(74, y)
		a.size = Vector2(440, 60)
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(a)
		y += 62.0 if l.length() > 40 else 38.0
	var q := _label("\"%s\"" % item["citacao"], f_italico, 20, Color(0.85, 0.6, 0.35))
	q.position = Vector2(40, y + 14)
	q.size = Vector2(480, 60)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(q)
	var b := _botao("RECOLHER", func(): j.concluir_loot(), 240.0)
	b.position = Vector2(160, y + 78)
	card.add_child(b)
	var alt := y + 78 + 48 + 36
	card.offset_top = -alt * 0.5
	card.offset_bottom = alt * 0.5
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func tela_vitoria(stats: Dictionary) -> void:
	esconder_telas()
	tela_fim.visible = true
	var escuro := ColorRect.new()
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.6)
	tela_fim.add_child(escuro)
	var t := _label("MASMORRA CONCLUÍDA", f_titulo, 76, Dados.COR_OURO)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-900, 170)
	t.size = Vector2(1800, 100)
	t.add_theme_constant_override("shadow_outline_size", 16)
	t.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.0, 0.9))
	tela_fim.add_child(t)
	var orn := Ornamento.new()
	orn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	orn.position = Vector2(-340, 280)
	orn.size = Vector2(680, 20)
	tela_fim.add_child(orn)
	var painel := Moldura.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.position = Vector2(-300, -180)
	painel.size = Vector2(600, 360)
	tela_fim.add_child(painel)
	var mins := int(stats.get("tempo", 0.0)) / 60
	var segs := int(stats.get("tempo", 0.0)) % 60
	var linhas := [
		["Tempo", "%d min %02d s" % [mins, segs]],
		["Turnos do herói", str(stats.get("turnos", 0))],
		["Dano causado", str(stats.get("dano_causado", 0))],
		["Dano recebido", str(stats.get("dano_recebido", 0))],
		["Poções usadas", str(stats.get("pocoes", 0))],
		["Mortes", str(stats.get("mortes", 0))],
	]
	var y := 40.0
	for l in linhas:
		var a := _label(l[0], f_corpo, 24, Dados.COR_TEXTO_FRACO, HORIZONTAL_ALIGNMENT_LEFT)
		a.position = Vector2(60, y)
		a.size = Vector2(300, 34)
		painel.add_child(a)
		var b := _label(l[1], f_titulo, 26, Dados.COR_OURO_CLARO, HORIZONTAL_ALIGNMENT_RIGHT)
		b.position = Vector2(300, y)
		b.size = Vector2(240, 34)
		painel.add_child(b)
		y += 48.0
	var v := HBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.position = Vector2(-380, -200)
	v.size = Vector2(760, 60)
	v.add_theme_constant_override("separation", 40)
	tela_fim.add_child(v)
	v.add_child(_botao("JOGAR DE NOVO", func(): j.voltar_menu()))
	if not OS.has_feature("web"):
		v.add_child(_botao("SAIR", func(): get_tree().quit()))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_ESCAPE:
		if controles.visible:
			controles.visible = false
			get_viewport().set_input_as_handled()
		elif pausa.visible:
			alternar_pausa()
			get_viewport().set_input_as_handled()


# ==================================================================== componentes desenhados
class Moldura extends Control:
	var cor_fundo := Color(0.04, 0.032, 0.028, 0.95)
	var cor_borda := Dados.COR_BRONZE
	var cor_fio := Dados.COR_OURO
	var cantos := true
	var lendario := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, cor_fundo)
		var topo := Color(1, 1, 1, 0.045) if not lendario else Color(1.0, 0.45, 0.1, 0.16)
		var meio := r.position.y + r.size.y * (0.5 if not lendario else 0.35)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, meio), Vector2(r.position.x, meio)]),
			PackedColorArray([topo, topo, Color(topo, 0), Color(topo, 0)]))
		draw_rect(r.grow(-1), Color(0, 0, 0, 0.95), false, 2.0)
		draw_rect(r.grow(-3), cor_borda, false, 2.0)
		draw_rect(r.grow(-7), Color(cor_fio, 0.45), false, 1.0)
		if cantos:
			for c in [Vector2(5, 5), Vector2(size.x - 5, 5), Vector2(5, size.y - 5), Vector2(size.x - 5, size.y - 5)]:
				var s := 9.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Color(0.05, 0.04, 0.03))
				draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)]), cor_fio, 1.5)
				draw_circle(c, 2.2, cor_fio)
			var mx := size.x * 0.5
			for yy in [3.0, size.y - 3.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(mx - 14, yy), Vector2(mx, yy - 6), Vector2(mx + 14, yy), Vector2(mx, yy + 6)]), cor_borda)
				draw_circle(Vector2(mx, yy), 2.0, cor_fio)


class Ornamento extends Control:
	var cor := Dados.COR_OURO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var mx := size.x * 0.5
		draw_line(Vector2(0, y), Vector2(mx - 22, y), Color(cor, 0.0), 1.0)
		var pts := PackedVector2Array([Vector2(0, y), Vector2(mx - 22, y)])
		draw_polyline_colors(pts, PackedColorArray([Color(cor, 0.0), Color(cor, 0.9)]), 1.5)
		draw_polyline_colors(PackedVector2Array([Vector2(mx + 22, y), Vector2(size.x, y)]), PackedColorArray([Color(cor, 0.9), Color(cor, 0.0)]), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 16, y), Vector2(mx, y - 8), Vector2(mx + 16, y), Vector2(mx, y + 8)]), Color(cor, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 8, y), Vector2(mx, y - 4), Vector2(mx + 8, y), Vector2(mx, y + 4)]), Color(0.1, 0.03, 0.02))
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(mx + s * 26, y), Vector2(mx + s * 32, y - 4), Vector2(mx + s * 38, y), Vector2(mx + s * 32, y + 4)]), Color(cor, 0.8))


class Orbe extends Control:
	var liquido: ColorRect
	var mat: ShaderMaterial
	var nivel := 1.0
	var nivel_alvo := 1.0
	var atraso := 1.0
	var texto := ""
	var rotulo := ""
	var f_rot: Font
	var f_val: Font

	func configurar(a: Color, b: Color, rot: String, fr: Font, fv: Font) -> void:
		rotulo = rot
		f_rot = fr
		f_val = fv
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		liquido = ColorRect.new()
		liquido.position = Vector2(14, 14)
		liquido.size = size - Vector2(28, 28)
		liquido.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/orbe.gdshader")
		mat.set_shader_parameter("cor_a", a)
		mat.set_shader_parameter("cor_b", b)
		mat.set_shader_parameter("ruido", load("res://assets/textures/ruido.png"))
		liquido.material = mat
		add_child(liquido)

	func definir(v: float, t: String) -> void:
		nivel_alvo = clampf(v, 0.0, 1.0)
		texto = t
		queue_redraw()

	func _process(delta: float) -> void:
		nivel = lerpf(nivel, nivel_alvo, 1.0 - exp(-10.0 * delta))
		if atraso > nivel:
			atraso = maxf(nivel, atraso - delta * 0.35)
		else:
			atraso = nivel
		if mat:
			mat.set_shader_parameter("nivel", nivel)
			mat.set_shader_parameter("nivel_atraso", atraso)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r - 2, Color(0.02, 0.015, 0.012))
		# moldura metálica com rebites e espinhos
		for i in 12:
			var a := TAU * i / 12.0 - PI * 0.5
			var p := c + Vector2(cos(a), sin(a)) * (r - 3)
			var t := Vector2(-sin(a), cos(a))
			var ext := c + Vector2(cos(a), sin(a)) * (r + 7)
			if i % 3 == 0:
				draw_colored_polygon(PackedVector2Array([p + t * 7, ext, p - t * 7]), Dados.COR_BRONZE)
		draw_arc(c, r - 6, 0, TAU, 96, Color(0.08, 0.06, 0.05), 10.0, true)
		draw_arc(c, r - 2, 0, TAU, 96, Dados.COR_BRONZE, 3.0, true)
		draw_arc(c, r - 11, 0, TAU, 96, Dados.COR_OURO, 1.5, true)
		for i in 24:
			var a2 := TAU * i / 24.0
			draw_circle(c + Vector2(cos(a2), sin(a2)) * (r - 6), 1.6, Color(Dados.COR_OURO, 0.7))
		if f_val:
			var tam := 20
			var w := f_val.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, -1, tam).x
			draw_string_outline(f_val, Vector2(c.x - w * 0.5, c.y + 8), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 6, Color(0, 0, 0, 0.85))
			draw_string(f_val, Vector2(c.x - w * 0.5, c.y + 8), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 0.96, 0.9))


class Slot extends Control:
	var id := ""
	var hud
	var disponivel := false
	var selecionado := false
	var sob := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_entrar)
		mouse_exited.connect(_sair)

	func _entrar() -> void:
		sob = true
		hud.mostrar_tooltip(id, global_position + Vector2(size.x * 0.5, 0))
		queue_redraw()

	func _sair() -> void:
		sob = false
		hud.esconder_tooltip()
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hud.clicar_slot(id)
			accept_event()

	func _process(_d: float) -> void:
		if selecionado:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var fundo := Color(0.12, 0.05, 0.035) if id != "pocao" else Color(0.1, 0.03, 0.03)
		draw_rect(r, Color(0.02, 0.015, 0.012))
		draw_rect(r.grow(-4), fundo)
		draw_polygon(PackedVector2Array([r.position + Vector2(4, 4), Vector2(r.end.x - 4, 4), Vector2(r.end.x - 4, size.y * 0.55), Vector2(4, size.y * 0.55)]),
			PackedColorArray([Color(1, 0.8, 0.5, 0.08), Color(1, 0.8, 0.5, 0.08), Color(1, 0.8, 0.5, 0), Color(1, 0.8, 0.5, 0)]))
		Icones.desenhar(self, id, r.grow(-12), disponivel)
		var cor_b := Dados.COR_BRONZE
		if selecionado:
			var p := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
			cor_b = Color(1.0, 0.35 + 0.2 * p, 0.1)
			draw_rect(r.grow(2), Color(1.0, 0.4, 0.1, 0.35 * p), false, 6.0)
		elif sob:
			cor_b = Dados.COR_OURO_CLARO
		draw_rect(r.grow(-1), Color(0, 0, 0), false, 2.0)
		draw_rect(r.grow(-3), cor_b, false, 2.0)
		if not disponivel:
			draw_rect(r.grow(-4), Color(0, 0, 0, 0.55))
		var tecla := ""
		match id:
			"golpe": tecla = "1"
			"redemoinho": tecla = "2"
			"investida": tecla = "3"
			"martelo": tecla = "4"
			"pocao": tecla = "Q"
			"esperar": tecla = "␣"
		var f: Font = hud.f_titulo
		draw_rect(Rect2(Vector2(-2, size.y - 20), Vector2(22, 22)), Color(0.03, 0.02, 0.02))
		draw_rect(Rect2(Vector2(-2, size.y - 20), Vector2(22, 22)), Dados.COR_BRONZE, false, 1.0)
		draw_string(f, Vector2(4, size.y - 3), tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Dados.COR_OURO_CLARO)
		if Dados.HABILIDADES.has(id) and Dados.HABILIDADES[id]["custo"] > 0:
			var cs := str(Dados.HABILIDADES[id]["custo"])
			draw_string_outline(f, Vector2(size.x - 26, 18), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0))
			draw_string(f, Vector2(size.x - 26, 18), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Dados.COR_FURIA)


class Icones:
	static func desenhar(ci: CanvasItem, id: String, r: Rect2, ativo: bool) -> void:
		var c := r.get_center()
		var s := r.size.x * 0.5
		var ouro := Color(0.95, 0.78, 0.42) if ativo else Color(0.55, 0.47, 0.35)
		var claro := Color(1.0, 0.95, 0.85) if ativo else Color(0.6, 0.58, 0.55)
		var escuro := Color(0.25, 0.12, 0.06)
		match id:
			"golpe":
				var a := c + Vector2(-s * 0.75, s * 0.75)
				var b := c + Vector2(s * 0.8, -s * 0.8)
				ci.draw_line(a.lerp(b, 0.28), b, claro, s * 0.22)
				ci.draw_line(a.lerp(b, 0.28), b, Color(0.6, 0.65, 0.75), s * 0.07)
				var g := a.lerp(b, 0.28)
				var n := Vector2(1, 1).normalized() * s * 0.38
				ci.draw_line(g - n, g + n, ouro, s * 0.14)
				ci.draw_line(a, g, escuro.lightened(0.3), s * 0.14)
				ci.draw_circle(a, s * 0.12, ouro)
			"redemoinho":
				for k in 3:
					var rr := s * (0.35 + k * 0.22)
					ci.draw_arc(c, rr, k * 2.1, k * 2.1 + 3.6, 24, Color(ouro, 0.5 + k * 0.2), s * 0.09, true)
				ci.draw_line(c, c + Vector2(s * 0.8, -s * 0.3), claro, s * 0.12)
				ci.draw_circle(c, s * 0.13, ouro)
			"investida":
				for k in 3:
					var x := c.x - s * 0.7 + k * s * 0.5
					var pts := PackedVector2Array([Vector2(x, c.y - s * 0.5), Vector2(x + s * 0.42, c.y), Vector2(x, c.y + s * 0.5)])
					ci.draw_polyline(pts, Color(ouro, 0.45 + k * 0.27), s * 0.17)
				ci.draw_line(c + Vector2(-s * 0.9, -s * 0.7), c + Vector2(-s * 0.4, -s * 0.7), Color(claro, 0.5), 2.0)
				ci.draw_line(c + Vector2(-s * 0.9, s * 0.7), c + Vector2(-s * 0.5, s * 0.7), Color(claro, 0.5), 2.0)
			"martelo":
				var raio := PackedVector2Array([c + Vector2(s * 0.15, -s * 0.95), c + Vector2(-s * 0.45, s * 0.05), c + Vector2(-s * 0.02, s * 0.05),
					c + Vector2(-s * 0.25, s * 0.95), c + Vector2(s * 0.5, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15), c + Vector2(s * 0.3, -s * 0.95)])
				ci.draw_colored_polygon(raio, ouro)
				ci.draw_polyline(raio + PackedVector2Array([raio[0]]), claro, 1.5)
				ci.draw_arc(c + Vector2(0, s * 0.85), s * 0.6, PI * 1.1, PI * 1.9, 16, Color(ouro, 0.6), 2.0)
			"pocao":
				ci.draw_circle(c + Vector2(0, s * 0.2), s * 0.62, Color(0.15, 0.03, 0.03))
				ci.draw_circle(c + Vector2(0, s * 0.28), s * 0.52, Color(0.85, 0.08, 0.06) if ativo else Color(0.4, 0.1, 0.1))
				ci.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.75), Vector2(s * 0.36, s * 0.42)), Color(0.3, 0.25, 0.22))
				ci.draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.85), Vector2(s * 0.52, s * 0.16)), ouro)
				ci.draw_circle(c + Vector2(-s * 0.2, 0), s * 0.12, Color(1, 1, 1, 0.5))
				ci.draw_arc(c + Vector2(0, s * 0.2), s * 0.62, 0, TAU, 32, ouro, 2.0, true)
			"esperar":
				var t := PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.8), c + Vector2(s * 0.55, -s * 0.8), c + Vector2(0, 0)])
				var b2 := PackedVector2Array([c + Vector2(-s * 0.55, s * 0.8), c + Vector2(s * 0.55, s * 0.8), c + Vector2(0, 0)])
				ci.draw_colored_polygon(t, Color(ouro, 0.35))
				ci.draw_colored_polygon(b2, Color(ouro, 0.8))
				ci.draw_polyline(PackedVector2Array([t[0], t[1], t[2], t[0]]), ouro, 2.0)
				ci.draw_polyline(PackedVector2Array([b2[0], b2[1], b2[2], b2[0]]), ouro, 2.0)
				ci.draw_line(c + Vector2(-s * 0.7, -s * 0.8), c + Vector2(s * 0.7, -s * 0.8), claro, 3.0)
				ci.draw_line(c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.7, s * 0.8), claro, 3.0)


class Retrato extends Control:
	var hud
	var unidade: Unidade
	var primeiro := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var heroi := unidade.time == 0
		var cor := Dados.COR_OURO if heroi else Color(0.75, 0.15, 0.1)
		draw_rect(r, Color(0.03, 0.02, 0.02))
		var tex: Texture2D = hud.retratos.get(unidade.tipo)
		if tex:
			draw_texture_rect(tex, r.grow(-4), false)
		else:
			var f: Font = hud.f_titulo
			draw_string(f, Vector2(size.x * 0.3, size.y * 0.66), unidade.nome.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.45), cor)
		draw_rect(r.grow(-1), Color(0, 0, 0), false, 2.0)
		draw_rect(r.grow(-3), cor, false, 2.0 if not primeiro else 3.0)
		var frac: float = float(unidade.hp) / unidade.hp_max
		draw_rect(Rect2(Vector2(4, size.y - 8), Vector2((size.x - 8) * frac, 4)), Color(0.85, 0.12, 0.08) if not heroi else Color(0.9, 0.3, 0.2))
		if primeiro:
			var f2: Font = hud.f_titulo
			var w := f2.get_string_size("AGORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string_outline(f2, Vector2((size.x - w) * 0.5, size.y + 15), "AGORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0))
			draw_string(f2, Vector2((size.x - w) * 0.5, size.y + 15), "AGORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Dados.COR_OURO_CLARO)


class BarraChefe extends Control:
	var hud
	var unidade: Unidade
	var atraso := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if unidade:
			var f := float(unidade.hp) / unidade.hp_max
			if atraso > f:
				atraso = maxf(f, atraso - delta * 0.25)
			else:
				atraso = f

	func _draw() -> void:
		if unidade == null:
			return
		var f1: Font = hud.f_titulo
		var f2: Font = hud.f_italico
		var nome := unidade.nome.to_upper()
		var w := f1.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string_outline(f1, Vector2((size.x - w) * 0.5, 26), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0))
		draw_string(f1, Vector2((size.x - w) * 0.5, 26), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Dados.COR_LENDARIO)
		var r := Rect2(Vector2(40, 38), Vector2(size.x - 80, 22))
		draw_rect(r.grow(4), Color(0.02, 0.01, 0.01))
		draw_rect(r, Color(0.12, 0.02, 0.02))
		var frac: float = float(unidade.hp) / unidade.hp_max
		draw_rect(Rect2(r.position, Vector2(r.size.x * atraso, r.size.y)), Color(0.95, 0.85, 0.6))
		var fill := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		draw_rect(fill, Color(0.62, 0.05, 0.04) if not unidade.furioso else Color(0.85, 0.2, 0.02))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, r.size.y * 0.4)), Color(1, 0.4, 0.3, 0.25))
		for i in range(1, 10):
			var x := r.position.x + r.size.x * i / 10.0
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.5), 1.0)
		draw_rect(r.grow(2), Dados.COR_BRONZE, false, 2.0)
		draw_rect(r.grow(5), Color(0, 0, 0), false, 2.0)
		for s in [-1.0, 1.0]:
			var x0 := r.position.x - 6 if s < 0 else r.end.x + 6
			var pts := PackedVector2Array([Vector2(x0, r.position.y - 6), Vector2(x0 + s * 30, r.get_center().y), Vector2(x0, r.end.y + 6), Vector2(x0 + s * 10, r.get_center().y)])
			draw_colored_polygon(pts, Dados.COR_BRONZE)
		var txt := "%d / %d" % [unidade.hp, unidade.hp_max]
		var w2 := f1.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(f1, Vector2((size.x - w2) * 0.5, r.position.y + 17), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0))
		draw_string(f1, Vector2((size.x - w2) * 0.5, r.position.y + 17), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var tit: String = Dados.TIPOS["chefe"]["titulo"]
		if unidade.furioso:
			tit += " · Enfurecido"
		var w3 := f2.get_string_size(tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string_outline(f2, Vector2((size.x - w3) * 0.5, 82), tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0))
		draw_string(f2, Vector2((size.x - w3) * 0.5, 82), tit, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Dados.COR_TEXTO)


class InfoAlvo extends Control:
	var hud
	var unidade: Unidade

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if unidade == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.035, 0.028, 0.025, 0.92))
		draw_rect(r.grow(-1), Color(0, 0, 0), false, 2.0)
		draw_rect(r.grow(-3), Color(0.55, 0.12, 0.08), false, 2.0)
		var pr := Rect2(Vector2(12, 12), Vector2(108, 108))
		draw_rect(pr, Color(0.02, 0.015, 0.015))
		var tex: Texture2D = hud.retratos.get(unidade.tipo)
		if tex:
			draw_texture_rect(tex, pr.grow(-3), false)
		draw_rect(pr, Dados.COR_BRONZE, false, 2.0)
		var f1: Font = hud.f_titulo
		var f2: Font = hud.f_corpo
		draw_string(f1, Vector2(134, 38), unidade.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.45, 0.35) if unidade.tipo != "chefe" else Dados.COR_LENDARIO)
		var br := Rect2(Vector2(134, 52), Vector2(266, 16))
		draw_rect(br, Color(0.1, 0.02, 0.02))
		draw_rect(Rect2(br.position, Vector2(br.size.x * float(unidade.hp) / unidade.hp_max, br.size.y)), Color(0.7, 0.07, 0.05))
		draw_rect(br, Dados.COR_BRONZE, false, 1.0)
		var t := "%d / %d" % [unidade.hp, unidade.hp_max]
		draw_string(f1, Vector2(br.position.x + 6, br.end.y - 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(f2, Vector2(134, 92), "Ataque %d   Defesa %d   Mov %d   Vel %d" % [unidade.atk, unidade.def, unidade.mov, unidade.vel], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Dados.COR_TEXTO)
		var st := ""
		if unidade.dados.get("escudo", false):
			st = "Escudo: bloqueia metade do dano frontal"
		elif unidade.dados.get("ia", "") == "mago":
			st = "Bola de fogo a 2–4 casas"
		elif unidade.dados.get("ia", "") == "flanco":
			st = "Busca as suas costas"
		elif unidade.tipo == "chefe":
			st = "Imune a atordoar e empurrar"
		if unidade.atordoado > 0:
			st = "Atordoado"
		draw_string(hud.f_italico, Vector2(134, 116), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Dados.COR_TEXTO_FRACO)


class CamadaBarras extends Control:
	var hud
	var unidades: Array = []
	var cam: Camera3D
	var ativo := false

	func _draw() -> void:
		if cam == null:
			return
		for u in unidades:
			if not is_instance_valid(u) or not u.vivo or not u.visible:
				continue
			if u.time != 0 and (u.dormindo or not ativo):
				continue
			if u.tipo == "chefe":
				continue
			var p3: Vector3 = u.global_position + Vector3(0, u.altura + 0.32, 0)
			if cam.is_position_behind(p3):
				continue
			var p := cam.unproject_position(p3)
			var w := 70.0
			var r := Rect2(p - Vector2(w * 0.5, 4), Vector2(w, 7))
			draw_rect(r.grow(2), Color(0, 0, 0, 0.85))
			draw_rect(r, Color(0.14, 0.03, 0.03))
			var frac: float = float(u.hp) / u.hp_max
			var cor := Color(0.82, 0.1, 0.06) if u.time != 0 else Color(0.95, 0.72, 0.3)
			draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), cor)
			draw_rect(r.grow(1), Color(Dados.COR_BRONZE, 0.9), false, 1.0)
			if u.atordoado > 0:
				var f: Font = hud.f_titulo
				draw_string_outline(f, p + Vector2(-34, -10), "ATORDOADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0))
				draw_string(f, p + Vector2(-34, -10), "ATORDOADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.82, 1.0))
