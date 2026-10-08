class_name Portal
extends Area3D
## Il teletrasporto per il mondo successivo (vedi Worlds). Compare su una
## striscia sicura quando il calore arriva al livello 5, spostato di lato:
## andarci costa strada col fuoco alle spalle. Una colonna di luce lo fa
## vedere da lontano, qualche pericolo prima, per scegliere la traiettoria.
## La rana che ci entra passa al mondo nuovo (lo fa la partita).

signal entered(frog: Node3D)

## Raggio dell'anello.
const RADIUS := 2.2
const BEAM_HEIGHT := 140.0

var _ring: MeshInstance3D
var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # rana
	var shape := BoxShape3D.new()
	shape.size = Vector3(RADIUS * 1.6, RADIUS * 2.0, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = RADIUS
	add_child(collision)
	body_entered.connect(_on_body_entered)
	_build()


func _process(delta: float) -> void:
	_ring.rotate_object_local(Vector3.FORWARD, delta * 1.5)


func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("frog"):
		return
	_used = true
	entered.emit(body)


func _build() -> void:
	# L'anello, in piedi di fronte alla rana che arriva.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.35
	torus.outer_radius = RADIUS
	torus.rings = 12
	torus.ring_segments = 5
	torus.material = Style.material("portal")
	_ring.mesh = torus
	_ring.rotation.x = PI / 2.0
	_ring.position.y = RADIUS + 0.2
	add_child(_ring)

	# Il velo dentro l'anello.
	var veil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS - 0.3
	disc.bottom_radius = RADIUS - 0.3
	disc.height = 0.05
	disc.radial_segments = 12
	disc.rings = 1
	disc.material = Style.material("portal_veil")
	veil.mesh = disc
	veil.rotation.x = PI / 2.0
	veil.position.y = RADIUS + 0.2
	add_child(veil)

	# La colonna di luce: si vede da lontano, anche sopra gli altri pericoli.
	var beam := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 1.2
	column.bottom_radius = 0.6
	column.height = BEAM_HEIGHT
	column.radial_segments = 6
	column.rings = 1
	column.material = Style.material("portal_beam")
	beam.mesh = column
	beam.position.y = BEAM_HEIGHT / 2.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	# Scintille che salgono lungo la colonna.
	var sparks := CPUParticles3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.radial_segments = 4
	dot.rings = 2
	dot.material = Style.material("portal")
	sparks.mesh = dot
	sparks.amount = 30
	sparks.lifetime = 2.5
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = RADIUS
	sparks.direction = Vector3.UP
	sparks.spread = 15.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.0
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.position.y = RADIUS
	add_child(sparks)

	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 10.0
	light.position.y = RADIUS
	add_child(light)
