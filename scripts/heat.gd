extends Node
## Il calore (autoload "Heat"): una barra unica da 0 a 100 per strada e fiume.
## Sale di continuo col tempo, più in fretta con i poteri e con gli incidenti,
## e non scende mai. Il mondo lo legge quando crea veicoli e correnti.

signal changed(value: float, level: int)
## Un veicolo è appena diventato rottame (anche nelle catene).
signal wreck_created(car: Node3D)

const MAX := 100.0
const LEVELS := 5

@export_group("Crescita")
## Calore al secondo anche senza fare niente.
@export var per_second := 0.15
@export var per_punch := 1.0
@export var per_super_jump := 3.0
@export var per_glide := 2.0
## Ogni veicolo trasformato in rottame, anche nelle catene.
@export var per_wreck := 0.6

@export_group("Effetti al massimo del calore")
## Velocità dei veicoli e delle correnti: +50% e +40% al massimo.
@export var max_traffic_speed_bonus := 0.5
@export var max_river_speed_bonus := 0.4
## Spazio tra i veicoli: -50% al massimo.
@export var max_gap_reduction := 0.5
## Frenata dei veicoli e soglia di schianto: -60% e -50% al massimo.
@export var max_braking_reduction := 0.6
@export var max_crash_speed_reduction := 0.5
## Da questa frazione del calore i veicoli perdono il controllo da soli.
@export var instability_start := 0.6
## Probabilità al secondo, per veicolo, di perdere il controllo al massimo.
@export var max_loss_of_control_per_second := 0.004

var value := 0.0
var running := true


func _process(delta: float) -> void:
	if running:
		add(per_second * delta)


func reset() -> void:
	value = 0.0
	running = true
	changed.emit(value, level())


func add(amount: float) -> void:
	value = minf(value + amount, MAX)
	changed.emit(value, level())


## Da 0 a 1.
func ratio() -> float:
	return value / MAX


## Da 0 a 5, uno ogni 20 punti di calore.
func level() -> int:
	return mini(floori(value / (MAX / LEVELS)), LEVELS)


func on_wreck(car: Node3D) -> void:
	add(per_wreck)
	wreck_created.emit(car)


func on_power_used(power: StringName) -> void:
	match power:
		&"punch":
			add(per_punch)
		&"super_jump":
			add(per_super_jump)
		&"glide":
			add(per_glide)


func traffic_speed_factor() -> float:
	return 1.0 + max_traffic_speed_bonus * ratio()


func river_speed_factor() -> float:
	return 1.0 + max_river_speed_bonus * ratio()


func gap_factor() -> float:
	return 1.0 - max_gap_reduction * ratio()


func braking_factor() -> float:
	return 1.0 - max_braking_reduction * ratio()


func crash_speed_factor() -> float:
	return 1.0 - max_crash_speed_reduction * ratio()


## Probabilità al secondo che un veicolo perda il controllo: zero sotto la
## soglia, poi cresce fino al massimo.
func loss_of_control_chance() -> float:
	var over := (ratio() - instability_start) / (1.0 - instability_start)
	return max_loss_of_control_per_second * clampf(over, 0.0, 1.0)
