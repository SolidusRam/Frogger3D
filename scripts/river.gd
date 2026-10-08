class_name River
extends Node3D
## Un tratto di fiume: un canale largo lane_count correnti, con il letto in
## fondo e l'acqua in superficie. Le correnti corrono lungo X e si susseguono
## lungo Z. L'acqua fa galleggiare i rottami e li trascina con la corrente.
## Le sponde sono il terreno ai due lati del canale, fuori da questa scena.
## Nel cielo (vedi Worlds) al posto dell'acqua c'è il vuoto: niente letto né
## superficie, le scie sono il vento, chi ci finisce cade (lo gestisce la
## rana) e i rottami precipitano.

@export var lane_count := 4
@export var lane_width := 3.5
@export var length := 120.0
@export var min_speed := 2.0
@export var max_speed := 5.0
@export var crocodile_chance := 0.25
## Quota della superficie rispetto alle sponde (che stanno a 0).
@export var water_level := -0.4
@export var depth := 3.0
## Acqua ferma, come quella del porto: niente correnti, tronchi o coccodrilli.
@export var still := false
## Il vuoto del cielo invece dell'acqua.
@export var sky := false

@export_group("Galleggiamento dei rottami")
## Oltre 1 il rottame galleggia: a 2 resta immerso per circa metà.
@export var buoyancy := 2.0
@export var water_drag := 1.5
@export var angular_drag := 2.0
## Quanto in fretta la corrente porta un rottame alla sua velocità.
@export var current_pull := 1.0

var _lanes: Array[RiverLane] = []
var _water: Area3D
## Le scie sulla superficie: scorrono come le correnti, così si legge dove
## e quanto in fretta va l'acqua.
var _streaks: MultiMesh
var _streak_base := PackedFloat32Array()
var _streak_lane := PackedInt32Array()
var _streak_z := PackedFloat32Array()
var _lane_shift: Array[float] = []


## Da dove si sente l'acqua: lungo il fiume, all'altezza della rana.
var _voice: Node3D


func _ready() -> void:
	_build_bed_and_water()
	_voice = Node3D.new()
	add_child(_voice)
	if not sky:
		Sfx.loop(_voice, &"harbor_loop" if still else &"river_loop", 0.0, 1.0, 1.5)
	if still:
		_build_streaks()
		return
	for i in lane_count:
		var lane := RiverLane.new()
		lane.position.z = _lane_offset(i)
		lane.direction = 1.0 if i % 2 == 0 else -1.0
		lane.speed = randf_range(min_speed, max_speed)
		lane.half_length = length / 2.0 - 12.0
		lane.float_height = water_level + 0.1
		lane.crocodile_chance = crocodile_chance
		lane.sky = sky
		add_child(lane)
		_lanes.append(lane)
	_build_streaks()


## Due file di scie chiare per corrente, sfalsate; la lunghezza varia un po'.
## Sull'acqua ferma (il porto) sono onde corte che dondolano sul posto.
## Nessun numero casuale: la sequenza casuale è del percorso.
func _build_streaks() -> void:
	var spacing := 8.0
	var per_row := int(length / spacing)
	var rows := 2 if not still else maxi(int(lane_width / 2.5), 2)
	for i in lane_count:
		_lane_shift.append(0.0)
		for row in rows:
			var z := _lane_offset(i) + ((row + 0.5) / rows - 0.5) * lane_width * 0.9
			for k in per_row:
				_streak_base.append(-length / 2.0 + (k + 0.5 * row + fmod(i * 0.37, 1.0)) * spacing)
				_streak_lane.append(i)
				_streak_z.append(z)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.03, 0.16)
	# Piene, non trasparenti: l'acqua semitrasparente le coprirebbe.
	mesh.material = Style.material("current")
	_streaks = MultiMesh.new()
	_streaks.transform_format = MultiMesh.TRANSFORM_3D
	_streaks.mesh = mesh
	_streaks.instance_count = _streak_base.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _streaks
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Si aggiornano a ogni fotogramma: niente interpolazione fisica.
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(instance)


func _process(delta: float) -> void:
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	if frog:
		_voice.position = Vector3(clampf(to_local(frog.global_position).x, -length / 2.0, length / 2.0), water_level, 0.0)
	if _streaks == null:
		return
	for i in _lanes.size():
		_lane_shift[i] += _lanes[i].direction * _lanes[i].speed * delta
	var time := Time.get_ticks_msec() / 1000.0
	for n in _streak_base.size():
		var lane := _streak_lane[n]
		var x := wrapf(_streak_base[n] + _lane_shift[lane], -length / 2.0, length / 2.0)
		if still:
			x += sin(time * 0.7 + n * 1.3) * 0.6
		var golden := fmod(n * 0.618, 1.0)
		var stretch := 0.8 + 1.4 * golden
		var z := _streak_z[n] + (golden - 0.5) * lane_width * 0.3
		_streaks.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(stretch, 1.0, 1.0)), Vector3(x, water_level + 0.05, z)))


func _physics_process(_delta: float) -> void:
	if sky:
		return
	for body in _water.get_overlapping_bodies():
		var wreck := body as Car
		if wreck and wreck.state == Car.State.WRECK:
			_float(wreck)


## Quota della superficie nel mondo.
func surface_y() -> float:
	return global_position.y + water_level


## Velocità della corrente nel punto dato (zero fuori dalle correnti).
func current_at(point: Vector3) -> Vector3:
	if still:
		return Vector3.ZERO
	var local_z := to_local(point).z
	for i in lane_count:
		if absf(local_z - _lane_offset(i)) <= lane_width / 2.0:
			var lane := _lanes[i]
			return global_basis.x.normalized() * lane.direction * lane.speed
	return Vector3.ZERO


func _float(wreck: Car) -> void:
	wreck.mark_floating()
	# Ingombro verticale reale: un'auto su un fianco è alta quanto è larga.
	var b := wreck.global_basis
	var height := absf(b.x.y) * wreck.size.x + absf(b.y.y) * wreck.size.y + absf(b.z.y) * wreck.size.z
	var bottom := wreck.global_position.y - height / 2.0
	var submerged := clampf((surface_y() - bottom) / height, 0.0, 1.0)
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var force := Vector3.UP * wreck.mass * gravity * buoyancy * submerged
	force -= wreck.linear_velocity * wreck.mass * water_drag * submerged
	var current := current_at(wreck.global_position)
	var horizontal := Vector3(wreck.linear_velocity.x, 0.0, wreck.linear_velocity.z)
	force += (current - horizontal) * wreck.mass * current_pull * submerged
	wreck.apply_central_force(force)
	wreck.apply_torque(-wreck.angular_velocity * wreck.mass * angular_drag * submerged)


func _lane_offset(index: int) -> float:
	return (index - (lane_count - 1) / 2.0) * lane_width


func _build_bed_and_water() -> void:
	var width := lane_count * lane_width

	if sky:
		return
	var bed := StaticBody3D.new()
	bed.collision_mask = 0
	bed.position.y = -depth - 0.5
	var bed_shape := BoxShape3D.new()
	bed_shape.size = Vector3(length, 1.0, width)
	var bed_collision := CollisionShape3D.new()
	bed_collision.shape = bed_shape
	bed.add_child(bed_collision)
	add_child(bed)

	var surface := MeshInstance3D.new()
	var surface_mesh := BoxMesh.new()
	surface_mesh.size = Vector3(length, 0.05, width)
	surface_mesh.material = Style.material("water")
	surface.mesh = surface_mesh
	surface.position.y = water_level
	add_child(surface)

	# L'area dell'acqua arriva poco sotto la superficie: chi sta su un tronco
	# non la tocca, chi galleggia sì.
	_water = Area3D.new()
	_water.collision_layer = 16 # acqua
	_water.collision_mask = 2 | 4 # rana, veicoli
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(length, depth, width)
	var water_collision := CollisionShape3D.new()
	water_collision.shape = water_shape
	_water.add_child(water_collision)
	_water.position.y = water_level - 0.1 - depth / 2.0
	_water.body_entered.connect(_on_body_entered)
	_water.body_exited.connect(_on_body_exited)
	add_child(_water)


func _on_body_entered(body: Node3D) -> void:
	if body is Frog:
		body.enter_water(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Frog:
		body.exit_water(self)
