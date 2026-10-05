class_name FirePatch
extends Node3D
## Una chiazza di fuoco a terra, lasciata dall'aereo che atterra di pancia:
## qualche fiamma bassa che brucia chi ci passa, poi si spegne da sola.

## Raggio, vita tolta al secondo e secondi prima di spegnersi.
var radius := 1.6
var burn := 50.0
var lifetime := 3.5

var _area: Area3D
var _left := 0.0
var _flames: Array[MeshInstance3D] = []


func _ready() -> void:
	_left = lifetime
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.45
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	cone.material = Style.material("fire")
	# Cinque fiamme sparse nella chiazza, sempre nello stesso schema.
	for i in 5:
		var flame := MeshInstance3D.new()
		flame.mesh = cone
		var angle := i * 2.4
		var r := radius * (0.25 + 0.6 * fmod(i * 0.618, 1.0))
		flame.position = Vector3(cos(angle) * r, 0.5, sin(angle) * r)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(flame)
		_flames.append(flame)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2 # rana
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.8
	_area.add_child(collision)
	add_child(_area)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	for body in _area.get_overlapping_bodies():
		if body is Frog:
			body.burn(burn, delta)


func _process(_delta: float) -> void:
	# Le fiamme tremolano e, verso la fine, si abbassano.
	var fade := clampf(_left / 1.0, 0.0, 1.0)
	for i in _flames.size():
		var height := (0.8 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.012 + i * 1.7))) * fade
		_flames[i].scale = Vector3(1.0, maxf(height, 0.01), 1.0)
		_flames[i].position.y = height * 0.5
