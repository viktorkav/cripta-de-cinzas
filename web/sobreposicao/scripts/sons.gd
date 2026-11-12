extends Node
## Toca efeitos sonoros gerados (assets/audio/*.wav) com um pool de players.

var sons := {}
var players: Array[AudioStreamPlayer] = []
var ambiente: AudioStreamPlayer
var volume_geral := 0.0


func _ready() -> void:
	for f in ResourceLoader.list_directory("res://assets/audio"):
		if f.ends_with(".wav"):
			sons[f.get_basename()] = load("res://assets/audio/" + f)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	ambiente = AudioStreamPlayer.new()
	add_child(ambiente)


func tocar(nome: String, db := 0.0, tom := 1.0) -> void:
	if not sons.has(nome):
		return
	for p in players:
		if not p.playing:
			p.stream = sons[nome]
			p.volume_db = db + volume_geral
			p.pitch_scale = tom
			p.play()
			return


func tocar_ambiente(nome: String, db := -8.0) -> void:
	if not sons.has(nome):
		return
	var s: AudioStream = sons[nome]
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	ambiente.stream = s
	ambiente.volume_db = db + volume_geral
	ambiente.play()
