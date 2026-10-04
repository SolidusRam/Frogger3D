class_name SuperJumpPower
extends Node
## Il super salto: un balzo alto con slancio in avanti, nella direzione dei
## tasti o, da fermi, in quella della telecamera. Funziona anche dall'acqua.
## L'attrezzo sono le molle sotto le zampe. I potenziamenti cambiano questi
## valori.

@export var height := 5.0
## Velocità orizzontale data dal salto.
@export var boost := 9.0
@export var cooldown := 2.5
## Controllo in aria: si sterza senza perdere slancio.
@export var air_acceleration := 6.0

var cooldown_left := 0.0
## Vero dal salto fino all'atterraggio.
var active := false

var _frog: Frog
var _springs: Array[Node3D] = []


func setup(frog: Frog) -> void:
	_frog = frog
	for side in [-1.0, 1.0]:
		var spring := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.1
		mesh.bottom_radius = 0.1
		mesh.height = 0.14
		mesh.material = Style.material("metal")
		spring.mesh = mesh
		spring.position = Vector3(side * 0.25, 0.04, 0.32)
		frog.visual.add_child(spring)
		_springs.append(spring)


## Il colore delle molle dice cosa portano: "" per quelle normali.
func set_spring_color(palette_key: String) -> void:
	for spring: MeshInstance3D in _springs:
		spring.material_override = Style.material(palette_key) if palette_key != "" else null


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _frog.is_on_floor() and _frog.velocity.y <= 0.0:
		active = false


func is_ready() -> bool:
	return cooldown_left == 0.0


## Da 0 (appena usato) a 1 (pronto).
func ready_ratio() -> float:
	return 1.0 - cooldown_left / cooldown


func use(direction: Vector3) -> void:
	cooldown_left = cooldown
	if direction.length_squared() < 0.01:
		direction = -_frog.camera_rig.flat_basis().z
	var push := direction.normalized() * boost
	_frog.launch(Vector3(push.x, sqrt(2.0 * _frog.gravity_up * height), push.z))
	active = true
	# Si accuccia sulle molle e poi si allunga verso l'alto.
	var tween := _frog.new_squash_tween()
	_frog.visual.scale = Vector3(1.4, 0.55, 1.4)
	tween.tween_property(_frog.visual, "scale", Vector3(0.75, 1.4, 0.75), 0.08)
	tween.tween_property(_frog.visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for spring in _springs:
		var spring_tween := create_tween()
		spring.scale = Vector3(1.0, 0.3, 1.0)
		spring_tween.tween_property(spring, "scale", Vector3(1.0, 2.2, 1.0), 0.08)
		spring_tween.tween_property(spring, "scale", Vector3.ONE, 0.4)
	_frog.power_used.emit(&"super_jump")
