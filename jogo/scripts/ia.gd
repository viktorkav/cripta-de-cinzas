class_name IA
extends RefCounted
## Decisões dos inimigos. Cada método é uma corrotina chamada pelo Jogo.

var j: Jogo
var rng := RandomNumberGenerator.new()


func _init(jogo: Jogo) -> void:
	j = jogo
	rng.seed = jogo.rng.seed * 31 + 7


func turno(u: Unidade) -> Dictionary:
	var ia: String = u.dados.get("ia", "melee")
	if ia == "chefe":
		return await _chefe(u)
	if ia == "mago":
		return await _mago(u)
	return await _melee(u, ia == "flanco")


func _pode_corpo_a_corpo(u: Unidade, alvo: Unidade) -> bool:
	return Mapa.dist(u.celula, alvo.celula) == 1 and absi(j.mapa.h(u.celula) - j.mapa.h(alvo.celula)) <= 2


## Melhor casa para ficar adjacente ao herói (preferindo as costas no modo flanco)
func _destino_adjacente(u: Unidade, alc: Dictionary, flanco: bool):
	var h: Unidade = j.heroi
	var melhor = null
	var melhor_pont := 1e9
	for d in Mapa.DIRS:
		var c: Vector2i = h.celula + d
		if not alc.has(c) or alc[c].get("ocupada", false):
			continue
		if c != u.celula and j.mapa.ocupante.has(c):
			continue
		if absi(j.mapa.h(c) - j.mapa.h(h.celula)) > 2:
			continue
		var pont: float = alc[c]["custo"]
		var lado := j.lado_ataque(c, h)
		if lado == "costas":
			pont -= 2.5 if flanco else 0.6
		elif lado == "lado":
			pont -= 1.0 if flanco else 0.3
		if pont < melhor_pont:
			melhor_pont = pont
			melhor = c
	return melhor


func _aproximar(u: Unidade, alc: Dictionary, alvo_cel: Vector2i, faixa_min := 1, faixa_max := 1) -> Vector2i:
	var dist := j.mapa.mapa_distancias(alvo_cel, u.pulo, u.time)
	var melhor := u.celula
	var melhor_pont := 1e9
	for c in alc:
		if alc[c].get("ocupada", false) and c != u.celula:
			continue
		var dd: int = dist.get(c, 999)
		var md := Mapa.dist(c, alvo_cel)
		var pont := float(dd)
		if faixa_max > 1:
			# magos querem ficar na faixa ideal de distância
			if md >= faixa_min and md <= faixa_max:
				pont = -10.0 + absf(md - 3.0) - j.mapa.h(c) * 0.5 + alc[c]["custo"] * 0.05
			else:
				pont = 10.0 + absf(md - 3.0)
		pont += alc[c]["custo"] * 0.01
		if pont < melhor_pont:
			melhor_pont = pont
			melhor = c
	return melhor


func _melee(u: Unidade, flanco: bool) -> Dictionary:
	var h: Unidade = j.heroi
	var moveu := false
	var agiu := false
	if not _pode_corpo_a_corpo(u, h) or (flanco and j.lado_ataque(u.celula, h) == "frente" and rng.randf() < 0.7):
		var alc := j.mapa.alcance(u.celula, u.mov, u.pulo, u.time)
		var dest = _destino_adjacente(u, alc, flanco)
		if dest == null:
			dest = _aproximar(u, alc, h.celula)
		if dest != u.celula:
			await j.mover_unidade(u, j.mapa.caminho(alc, dest))
			moveu = true
	if _pode_corpo_a_corpo(u, h):
		await j.ataque_corpo(u, h, 1.0)
		agiu = true
	else:
		u.virar_para(h.celula)
	return {"moveu": moveu, "agiu": agiu}


func _mago(u: Unidade) -> Dictionary:
	var h: Unidade = j.heroi
	var moveu := false
	var agiu := false
	var amin: int = u.dados.get("alcance_min", 2)
	var amax: int = u.dados.get("alcance_max", 4)
	var d := Mapa.dist(u.celula, h.celula)
	if d >= amin and d <= amax:
		await j.bola_de_fogo(u, h)
		agiu = true
		# recua depois de lançar, se o herói estiver perto
		if d <= 2:
			var alc := j.mapa.alcance(u.celula, u.mov, u.pulo, u.time)
			var dest := _aproximar(u, alc, h.celula, 3, amax)
			if dest != u.celula:
				await j.mover_unidade(u, j.mapa.caminho(alc, dest))
				moveu = true
	else:
		var alc := j.mapa.alcance(u.celula, u.mov, u.pulo, u.time)
		var dest := _aproximar(u, alc, h.celula, amin, amax)
		if dest != u.celula:
			await j.mover_unidade(u, j.mapa.caminho(alc, dest))
			moveu = true
		d = Mapa.dist(u.celula, h.celula)
		if d >= amin and d <= amax:
			await j.bola_de_fogo(u, h)
			agiu = true
		elif d == 1:
			await j.ataque_corpo(u, h, 0.6)
			agiu = true
	u.virar_para(h.celula)
	return {"moveu": moveu, "agiu": agiu}


func _chefe(u: Unidade) -> Dictionary:
	var h: Unidade = j.heroi
	var moveu := false
	var agiu := false
	var est: Dictionary = j.estado_chefe
	est["cd_nova"] = maxi(0, est.get("cd_nova", 0) - 1)
	est["cd_chuva"] = maxi(0, est.get("cd_chuva", 0) - 1)
	# 1) detona o telégrafo pendente
	if est.get("telegrafo", []).size() > 0:
		await j.detonar_telegrafo(u)
		agiu = true
	# 2) invoca diabretes na metade da vida
	elif u.hp <= u.hp_max * 0.5 and not est.get("invocou", false):
		est["invocou"] = true
		await j.invocar(u)
		agiu = true
	if not agiu:
		if _pode_corpo_a_corpo(u, h):
			if est["cd_nova"] == 0 and rng.randf() < 0.45:
				await j.telegrafar(u, j.mapa.losango(u.celula, 2), "nova")
				est["cd_nova"] = 3
			else:
				await j.clivar(u, h)
			agiu = true
		else:
			var alc := j.mapa.alcance(u.celula, u.mov, u.pulo, u.time)
			var dest = _destino_adjacente(u, alc, false)
			if dest == null:
				dest = _aproximar(u, alc, h.celula)
			if dest != u.celula:
				await j.mover_unidade(u, j.mapa.caminho(alc, dest))
				moveu = true
			if _pode_corpo_a_corpo(u, h):
				await j.clivar(u, h)
				agiu = true
			elif est["cd_chuva"] == 0:
				await j.telegrafar(u, j.mapa.quadrado(h.celula, 1), "chuva")
				est["cd_chuva"] = 3
				agiu = true
	elif not moveu and not _pode_corpo_a_corpo(u, h):
		var alc2 := j.mapa.alcance(u.celula, u.mov, u.pulo, u.time)
		var dest2 = _destino_adjacente(u, alc2, false)
		if dest2 == null:
			dest2 = _aproximar(u, alc2, h.celula)
		if dest2 != u.celula:
			await j.mover_unidade(u, j.mapa.caminho(alc2, dest2))
			moveu = true
	if not u.furioso and u.hp <= u.hp_max * 0.25 and u.vivo:
		u.furioso = true
		await j.enfurecer(u)
	u.virar_para(h.celula)
	return {"moveu": moveu, "agiu": agiu}
