class_name Crane
extends AnimatableBody3D
## Una gru a portale del porto: scorre lungo X sopra il blocco e lascia
## cadere container. L'ombra a terra lampeggia warning_time secondi prima
## della caduta. Più sale il calore, più spesso la gru mira alla rana: il
## mondo reagisce. Le gambe sono solide e spingono via chi è in mezzo.

const MODEL := preload("res://assets/models/crane.glb")
const HALF_SPAN := 7.0
## Quota del centro del container appeso sotto lo spreader.
const HANG_Y := 11.5

enum Phase { MOVING, WARNING, RELOADING }

var play_half_width := 37.0
var speed := 4.0
var warning_time := 1.5
var reload_time := 2.5
## Probabilità che miri alla rana: base e in più al calore massimo.
var aim_chance := 0.25
var max_heat_aim_bonus := 0.6

var phase := Phase.MOVING
var target_x := 0.0

var _timer := 0.0
var _hanging: Node3D
var _shadow: MeshInstance3D
var _blink := 0.0
var _frog: Node3D


func _init() -> void:
	# Da impostare prima che il corpo entri nella scena (vedi Airplane.create).
	sync_to_physics = true


func _ready() -> void:
	collision_layer = 1 # come il terreno: le gambe sono muri che si muovono
	collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	Style.apply_palette(model)
	for z in [HALF_SPAN, -HALF_SPAN]:
		for x in [2.2, -2.2]:
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 15.0, 0.6)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = Vector3(x, 7.5, z)
			add_child(collision)

	_shadow = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ShippingContainer.SIZE.x + 0.4, 0.04, ShippingContainer.SIZE.z + 0.4)
	mesh.material = Style.material("drop_warning")
	_shadow.mesh = mesh
	_shadow.visible = false
	add_child(_shadow)
	_frog = get_tree().get_first_node_in_group("frog")
	_reload()
	_choose_target()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.MOVING:
			position.x = move_toward(position.x, target_x, speed * delta)
			if is_equal_approx(position.x, target_x):
				phase = Phase.WARNING
				_timer = warning_time
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_drop()
		Phase.RELOADING:
			_timer -= delta
			if _timer <= 0.0:
				_reload()
				_choose_target()
	_blink = fmod(_blink + delta, 0.3)
	_shadow.visible = phase == Phase.WARNING and _blink < 0.18
	_shadow.global_position = Vector3(global_position.x, 0.33, global_position.z)


## Vero mentre l'ombra lampeggia, prima della caduta.
func is_warning() -> bool:
	return phase == Phase.WARNING


func _choose_target() -> void:
	var limit := play_half_width - 6.0
	var chance := aim_chance + max_heat_aim_bonus * Heat.ratio()
	if _frog and randf() < chance:
		target_x = clampf(_frog.global_position.x - get_parent().global_position.x, -limit, limit)
	else:
		target_x = randf_range(-limit, limit)
	phase = Phase.MOVING


func _drop() -> void:
	var drop := ShippingContainer.new()
	get_parent().add_child(drop)
	drop.global_transform = _hanging.global_transform
	_hanging.queue_free()
	_hanging = null
	phase = Phase.RELOADING
	_timer = reload_time


## Un nuovo container appeso: per ora solo da vedere, cade come corpo fisico.
func _reload() -> void:
	_hanging = ShippingContainer.MODEL.instantiate()
	_hanging.position.y = HANG_Y
	add_child(_hanging)
	Style.apply_palette(_hanging, {"paint": "container_%d" % (randi() % ShippingContainer.COLORS)})
