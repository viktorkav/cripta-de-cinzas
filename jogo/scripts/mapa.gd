class_name Mapa
extends RefCounted
## Grade do jogo: alturas, bloqueios, ocupantes e caminhos (estilo Final Fantasy Tactics).

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var largura := 0
var profundidade := 0
var altura := {} # Vector2i -> int (nível)
var piso := {} # Vector2i -> char do mapa
var bloqueado := {} # Vector2i -> true (props, portas fechadas)
var ocupante := {} # Vector2i -> Unidade


func carregar(linhas: Array) -> void:
	profundidade = linhas.size()
	largura = (linhas[0] as String).length()
	for z in profundidade:
		var s: String = linhas[z]
		for x in s.length():
			var ch := s[x]
			var c := Vector2i(x, z)
			if ch == "#":
				continue
			piso[c] = ch
			var h := 0
			if ch == "-" or ch == "R":
				h = 1
			elif ch == "=" or ch == "C":
				h = 2
			altura[c] = h
			if ch in ["P", "B", "o", "R", "C", "D"]:
				bloqueado[c] = true


func eh_piso(c: Vector2i) -> bool:
	return piso.has(c)


func eh_parede(c: Vector2i) -> bool:
	return not piso.has(c)


func livre(c: Vector2i) -> bool:
	return piso.has(c) and not bloqueado.has(c) and not ocupante.has(c)


func caminhavel(c: Vector2i) -> bool:
	return piso.has(c) and not bloqueado.has(c)


func h(c: Vector2i) -> int:
	return altura.get(c, 0)


func y(c: Vector2i) -> float:
	return float(h(c)) * Dados.NIVEL


func mundo(c: Vector2i) -> Vector3:
	return Vector3(c.x, y(c), c.y)


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## BFS de movimento. Retorna {celula: {"custo": n, "ant": celula_anterior}}.
## Passa por aliados, não por inimigos; respeita o pulo (diferença de nível).
func alcance(origem: Vector2i, mov: int, pulo: int, time: int, ignorar_unidades := false) -> Dictionary:
	var res := {origem: {"custo": 0, "ant": origem}}
	var fila: Array[Vector2i] = [origem]
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		var custo: int = res[c]["custo"]
		if custo >= mov:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if res.has(n) or not caminhavel(n):
				continue
			if absi(h(n) - h(c)) > pulo:
				continue
			if not ignorar_unidades and ocupante.has(n):
				var u = ocupante[n]
				if u.time != time:
					continue
			res[n] = {"custo": custo + 1, "ant": c}
			fila.push_back(n)
	# não termina em casa ocupada
	var finais := {}
	for c in res:
		if c == origem or not ocupante.has(c):
			finais[c] = res[c]
		else:
			finais[c] = res[c].duplicate()
			finais[c]["ocupada"] = true
	return finais


func caminho(alc: Dictionary, destino: Vector2i) -> Array[Vector2i]:
	var cam: Array[Vector2i] = []
	if not alc.has(destino):
		return cam
	var c := destino
	while true:
		cam.push_front(c)
		var a: Vector2i = alc[c]["ant"]
		if a == c:
			break
		c = a
	return cam


## Distância de caminhada real até um alvo (ignorando o alvo como obstáculo), para a IA.
func mapa_distancias(alvo: Vector2i, pulo: int, time: int) -> Dictionary:
	var res := {alvo: 0}
	var fila: Array[Vector2i] = [alvo]
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if res.has(n) or not caminhavel(n):
				continue
			if absi(h(n) - h(c)) > pulo:
				continue
			if ocupante.has(n) and ocupante[n].time != time:
				res[n] = res[c] + 1 # conta, mas não expande através de inimigos
				continue
			res[n] = res[c] + 1
			fila.push_back(n)
	return res


func vizinhos4(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in DIRS:
		r.append(c + d)
	return r


func vizinhos8(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in DIRS8:
		r.append(c + d)
	return r


## Células em cruz (raio 1) em volta de um centro
func cruz(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = [c]
	for d in DIRS:
		if eh_piso(c + d):
			r.append(c + d)
	return r


func losango(c: Vector2i, raio: int) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for dx in range(-raio, raio + 1):
		for dz in range(-raio, raio + 1):
			var n := c + Vector2i(dx, dz)
			if absi(dx) + absi(dz) <= raio and eh_piso(n):
				r.append(n)
	return r


func quadrado(c: Vector2i, raio: int) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for dx in range(-raio, raio + 1):
		for dz in range(-raio, raio + 1):
			var n := c + Vector2i(dx, dz)
			if eh_piso(n):
				r.append(n)
	return r
