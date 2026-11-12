extends Node
## Dados fixos do jogo: tipos de unidade, habilidades, mapa e paleta.

const TILE := 1.0
const NIVEL := 0.5 # altura de um degrau (h=1 -> 0,5 m)

# Paleta inspirada na UI de Diablo 4
const COR_FUNDO := Color("0b0908")
const COR_PAINEL := Color("16110e")
const COR_BRONZE := Color("6e5634")
const COR_OURO := Color("c8a45c")
const COR_OURO_CLARO := Color("e9d39a")
const COR_SANGUE := Color("8b1a1a")
const COR_VERMELHO := Color("c4302a")
const COR_TEXTO := Color("d9cfb8")
const COR_TEXTO_FRACO := Color("8d8270")
const COR_LENDARIO := Color("e07b22")
const COR_RARO := Color("e8d34a")
const COR_MAGICO := Color("6a8cff")
const COR_FURIA := Color("e8822a")

const TIPOS := {
	"heroi": {"nome": "Aldric, o Guardião", "modelo": "heroi", "altura": 1.14, "hp": 165, "atk": 31, "def": 8,
		"mov": 4, "pulo": 2, "vel": 10, "time": 0},
	"esqueleto": {"nome": "Esqueleto Guerreiro", "modelo": "esqueleto", "altura": 1.08, "hp": 52, "atk": 12, "def": 2,
		"mov": 3, "pulo": 1, "vel": 7, "time": 1, "ia": "melee", "xp": 1},
	"diabrete": {"nome": "Diabrete", "modelo": "diabrete", "altura": 0.8, "hp": 34, "atk": 11, "def": 1,
		"mov": 5, "pulo": 2, "vel": 9, "time": 1, "ia": "flanco", "xp": 1},
	"cultista": {"nome": "Cultista das Cinzas", "modelo": "cultista", "altura": 1.12, "hp": 44, "atk": 13, "def": 1,
		"mov": 3, "pulo": 1, "vel": 6, "time": 1, "ia": "mago", "alcance_min": 2, "alcance_max": 4, "xp": 1},
	"bruto": {"nome": "Bruto Encouraçado", "modelo": "bruto", "altura": 1.42, "hp": 96, "atk": 16, "def": 6,
		"mov": 2, "pulo": 1, "vel": 5, "time": 1, "ia": "melee", "escudo": true, "xp": 2},
	"chefe": {"nome": "Vorgath, o Chifrudo", "titulo": "Senhor da Cripta", "modelo": "chefe", "altura": 2.3,
		"hp": 400, "atk": 24, "def": 5, "mov": 3, "pulo": 2, "vel": 8, "time": 1, "ia": "chefe", "xp": 10},
}

# Habilidades do herói (custo em Fúria)
const HABILIDADES := {
	"golpe": {"nome": "Golpe", "tecla": "1", "custo": 0, "alcance": 1, "mult": 1.0, "area": "alvo",
		"desc": "Um corte firme num inimigo adjacente.\nGera 15 de Fúria."},
	"redemoinho": {"nome": "Redemoinho de Aço", "tecla": "2", "custo": 30, "alcance": 0, "mult": 0.85, "area": "volta",
		"desc": "Gira a espada e atinge todos os 8 espaços ao seu redor."},
	"investida": {"nome": "Investida", "tecla": "3", "custo": 25, "alcance": 5, "mult": 1.3, "area": "linha",
		"desc": "Avança em linha reta até o primeiro inimigo, golpeia e o empurra 1 espaço.\nAtordoa por 1 turno."},
	"martelo": {"nome": "Martelo dos Céus", "tecla": "4", "custo": 50, "alcance": 3, "mult": 1.15, "area": "cruz",
		"desc": "Invoca um raio sagrado sobre uma área em cruz.\nAtordoa os atingidos por 1 turno."},
}

const POCAO_CURA := 65
const POCOES_INICIAIS := 3
const FURIA_MAX := 100

# Mapa: x de 0 a 22, z de 0 a 32. Legenda:
# '#' rocha  '.' piso  '-' piso alto (0,5 m)  '=' piso mais alto (1 m)
# 'P' pilar  'B' barril  'o' ossos  'R' braseiro (no piso alto)  'C' baú (no piso mais alto)  'D' porta
const MAPA := [
	"#######################",
	"##########=C=##########",
	"####....R-----R....####",
	"####....-------....####",
	"####....-------....####",
	"####...............####",
	"####..P.........P..####",
	"####...............####",
	"####...............####",
	"####..P.........P..####",
	"####...............####",
	"####o.............o####",
	"###########D###########",
	"#######B.P...P.B#######",
	"#######.........#######",
	"#######--.....--#######",
	"#######--.....--#######",
	"#######--.....--#######",
	"#######--.....--#######",
	"#######...o.....#######",
	"#######B.P...P.B#######",
	"###########D###########",
	"#####BB..........B#####",
	"#####.............#####",
	"#####..P.......P..#####",
	"#####.............#####",
	"#####..........o..#####",
	"#####.............#####",
	"#####..P.......P..#####",
	"#####.............#####",
	"#####.............#####",
	"#####B...........B#####",
	"#######################",
]

const INICIO_HEROI := Vector2i(11, 30)

# Salas: retângulos (x0, z0, x1, z1) e a porta que se abre quando a sala é limpa
const SALAS := [
	{"nome": "Salão das Cinzas", "ret": Rect2i(5, 22, 13, 10), "porta": Vector2i(11, 21),
		"inimigos": [["esqueleto", Vector2i(9, 24)], ["esqueleto", Vector2i(13, 24)], ["diabrete", Vector2i(11, 23)]],
		"gatilho": 5},
	{"nome": "Galeria dos Penitentes", "ret": Rect2i(7, 13, 9, 8), "porta": Vector2i(11, 12),
		"inimigos": [["bruto", Vector2i(11, 15)], ["cultista", Vector2i(15, 16)], ["esqueleto", Vector2i(7, 17)]],
		"gatilho": 4},
	{"nome": "Santuário do Chifrudo", "ret": Rect2i(4, 1, 15, 11), "porta": Vector2i(-1, -1),
		"inimigos": [["chefe", Vector2i(11, 3)], ["cultista", Vector2i(5, 5)]],
		"gatilho": 6},
]

# Tochas: (posição da parede, direção para dentro da sala)
const TOCHAS := [
	[Vector2i(4, 23), Vector2i(1, 0)], [Vector2i(4, 29), Vector2i(1, 0)],
	[Vector2i(18, 23), Vector2i(-1, 0)], [Vector2i(18, 29), Vector2i(-1, 0)],
	[Vector2i(9, 21), Vector2i(0, 1)], [Vector2i(13, 21), Vector2i(0, 1)],
	[Vector2i(6, 14), Vector2i(1, 0)], [Vector2i(6, 19), Vector2i(1, 0)],
	[Vector2i(16, 14), Vector2i(-1, 0)], [Vector2i(16, 19), Vector2i(-1, 0)],
	[Vector2i(10, 12), Vector2i(0, 1)], [Vector2i(12, 12), Vector2i(0, 1)],
	[Vector2i(3, 5), Vector2i(1, 0)], [Vector2i(3, 9), Vector2i(1, 0)],
	[Vector2i(19, 5), Vector2i(-1, 0)], [Vector2i(19, 9), Vector2i(-1, 0)],
	[Vector2i(6, 1), Vector2i(0, 1)], [Vector2i(16, 1), Vector2i(0, 1)],
]

const ESTANDARTES := [
	[Vector2i(9, 1), Vector2i(0, 1)], [Vector2i(13, 1), Vector2i(0, 1)],
	[Vector2i(8, 12), Vector2i(0, 1)], [Vector2i(14, 12), Vector2i(0, 1)],
]

# Feixes de luar que entram por frestas do teto
const FEIXES := [Vector2(11, 26.5), Vector2(11, 17), Vector2(6.5, 8)]

const ITEM_LENDARIO := {
	"nome": "Lâmina do Crepúsculo",
	"tipo": "Espada Lendária",
	"poder": "Poder do Item 925",
	"linhas": ["+38 de Dano por Golpe", "+12% de Chance de Golpe Crítico", "Redemoinho de Aço gera 10 de Fúria por inimigo atingido"],
	"citacao": "Forjada nas brasas do Chifrudo, ainda quente ao toque.",
}
