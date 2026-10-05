class_name RiverLog
extends Floater
## Un tronco: una piattaforma sicura. Dal livello Heat.STEP_LEVEL di calore
## (il gradino del fiume) affonda sotto il peso della rana: appena lei sale
## trema, dopo sink_delay secondi comincia ad affondare, facendo bolle, e in
## sink_time secondi va sott'acqua. Quando la rana scende torna su.

## Secondi con la rana sopra prima di cominciare ad affondare.
var sink_delay := 1.0
## Secondi per andare del tutto sott'acqua.
var sink_time := 2.0

const MODEL := preload("res://assets/models/log.glb")

## Il modello del tronco: trema tutto insieme quando sta per affondare.
var _bark: Node3D
var _bubbles: CPUParticles3D
## Secondi passati con la rana sopra.
var _weighted := 0.0
## Quanto è sceso sotto la quota di galleggiamento, in metri.
var _sunk := 0.0


func _build() -> void:
	super()
	# Il modello è lungo 1 m: la corteccia si allunga, teste e moncone vanno
	# al loro posto.
	_bark = MODEL.instantiate()
	add_child(_bark)
	Style.apply_palette(_bark)
	(_bark.get_node("Bark") as Node3D).scale.z = size.z
	for end: Node3D in [_bark.get_node("EndA"), _bark.get_node("EndB")]:
		end.position.z = signf(end.position.z) * size.z / 2.0
	(_bark.get_node("Stub") as Node3D).position.z = -size.z * 0.2


func _physics_process(delta: float) -> void:
	var depth := size.y + 0.3
	var loaded := Heat.level() >= Heat.STEP_LEVEL and _frog_on_top()
	_weighted = _weighted + delta if loaded else 0.0
	var before := _sunk
	if loaded and _weighted > sink_delay:
		_sunk = minf(_sunk + depth / sink_time * delta, depth)
	elif not loaded:
		_sunk = maxf(_sunk - depth / sink_time * delta, 0.0)
	# Corrente e affondamento in una sola scrittura: con sync_to_physics una
	# seconda scrittura partirebbe dalla posizione vecchia e annullerebbe la
	# prima.
	global_position = global_position + drift_velocity * delta + Vector3.DOWN * (_sunk - before)
	# L'avviso: trema appena la rana sale, fa bolle mentre affonda.
	var trembling := loaded or _sunk > 0.0
	_bark.position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), 0.0) if trembling else Vector3.ZERO
	_set_bubbling(loaded and _weighted > sink_delay * 0.5)


## Vero mentre il tronco è sotto la sua quota di galleggiamento.
func is_sinking() -> bool:
	return _sunk > 0.0


## La rana sopra il tronco, in piedi o in aria appena sopra: saltellare sul
## posto non lo tiene a galla.
func _frog_on_top() -> bool:
	var frog := get_tree().get_first_node_in_group("frog") as Frog
	if frog == null:
		return false
	if frog.floor_body() == self:
		return true
	if frog.is_on_floor() or frog.is_swimming():
		return false
	var local := to_local(frog.global_position)
	return absf(local.x) < size.x / 2.0 + 0.3 and absf(local.z) < size.z / 2.0 and local.y > 0.0 and local.y < size.y / 2.0 + 3.0


func _set_bubbling(on: bool) -> void:
	if on and _bubbles == null:
		_bubbles = CPUParticles3D.new()
		var bubble := SphereMesh.new()
		bubble.radius = 0.12
		bubble.height = 0.24
		bubble.radial_segments = 6
		bubble.rings = 3
		bubble.material = Style.material("sign_white")
		_bubbles.mesh = bubble
		_bubbles.amount = 24
		_bubbles.lifetime = 0.6
		_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_bubbles.emission_box_extents = Vector3(size.x * 0.7, 0.1, size.z * 0.5)
		_bubbles.direction = Vector3.UP
		_bubbles.spread = 25.0
		_bubbles.gravity = Vector3.ZERO
		_bubbles.initial_velocity_min = 1.0
		_bubbles.initial_velocity_max = 2.0
		_bubbles.scale_amount_min = 0.6
		_bubbles.scale_amount_max = 1.3
		add_child(_bubbles)
	if _bubbles:
		_bubbles.emitting = on
