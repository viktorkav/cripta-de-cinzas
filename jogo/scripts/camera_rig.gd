class_name CameraRig
extends Node3D
## Câmera tática: segue um alvo, gira em passos de 90° (estilo FFT), zoom e tremor.

var cam: Camera3D
var alvo := Vector3.ZERO
var yaw := deg_to_rad(45.0)
var yaw_alvo := deg_to_rad(45.0)
var pitch := deg_to_rad(-50.0)
var dist := 16.5
var dist_alvo := 16.5
var tremor := 0.0
var ruido := FastNoiseLite.new()
var t := 0.0
var orbitar := false
var vel_seguir := 4.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.5
	cam.far = 120.0
	add_child(cam)
	ruido.frequency = 18.0
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = false
	cam.attributes = attr
	cam.current = true


func girar(passos: int) -> void:
	yaw_alvo += deg_to_rad(90.0) * passos


func zoom(d: float) -> void:
	dist_alvo = clampf(dist_alvo + d, 10.0, 30.0)


func focar(p: Vector3, imediato := false) -> void:
	alvo = p
	if imediato:
		global_position = p


func tremer(f: float) -> void:
	tremor = maxf(tremor, f)


func _process(delta: float) -> void:
	t += delta
	if orbitar:
		yaw_alvo += delta * 0.08
	global_position = global_position.lerp(alvo, 1.0 - exp(-vel_seguir * delta))
	yaw = lerp_angle(yaw, yaw_alvo, 1.0 - exp(-8.0 * delta))
	dist = lerpf(dist, dist_alvo, 1.0 - exp(-6.0 * delta))
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var sh := Vector3.ZERO
	if tremor > 0.001:
		sh = Vector3(ruido.get_noise_2d(t * 60.0, 0.0), ruido.get_noise_2d(0.0, t * 60.0), ruido.get_noise_2d(t * 60.0, 50.0)) * tremor * 0.35
		tremor = maxf(0.0, tremor - delta * 1.6)
	cam.global_position = global_position + off + sh
	cam.look_at(global_position + sh * 0.5 + Vector3(0, 0.6, 0), Vector3.UP)


## Direção da tela em coordenadas da grade (para teclas e leitura)
func direcao_tela_para_grade() -> float:
	return yaw
