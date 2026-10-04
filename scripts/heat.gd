extends Node
## Il calore (autoload "Heat"): una barra unica da 0 a 100 per strada e fiume.
## Sale di continuo col tempo, più in fretta con i poteri e con gli incidenti,
## e non scende mai. Il mondo lo legge quando crea veicoli e correnti.

signal changed(value: float, level: int)
## Un veicolo è appena diventato rottame (anche nelle catene).
signal wreck_created(car: Node3D)

const MAX := 100.0
const LEVELS := 5
## I gradini di calore: a questo livello il mondo cambia comportamento, in
## ogni bioma (vedi "Difficoltà nei biomi" in docs/regole-design.md).
const STEP_LEVEL := 3

@export_group("Crescita")
## Calore al secondo anche senza fare niente.
@export var per_second := 0.15
@export var per_punch := 1.0
@export var per_super_jump := 3.0
@export var per_glide := 2.0
@export var per_tongue := 1.0
@export var per_slam := 2.0
## Ogni veicolo trasformato in rottame, anche nelle catene, ma solo vicino
## alla rana: conta il caos che si vede, non quello di un aeroporto lontano.
## I rottami fatti dall'incendio non contano.
@export var per_wreck := 0.6
@export var wreck_radius := 50.0

@export_group("Effetti al massimo del calore")
## Velocità dei veicoli e delle correnti: +80% e +40% al massimo.
@export var max_traffic_speed_bonus := 0.8
@export var max_river_speed_bonus := 0.4
## Spazio tra i veicoli: +25% al massimo. Al calore alto le auto sono un po'
## meno, ma molto più veloci: il traffico minaccia invece di ingorgarsi.
@export var max_gap_increase := 0.25
## Frenata dei veicoli e soglia di schianto: -60% e -50% al massimo.
@export var max_braking_reduction := 0.6
@export var max_crash_speed_reduction := 0.5
## Da questa frazione del calore i veicoli perdono il controllo da soli.
@export var instability_start := 0.6
## Probabilità al secondo, per veicolo, di perdere il controllo al massimo.
@export var max_loss_of_control_per_second := 0.004

var value := 0.0
var running := true
## Statistica dello stagno "Sangue freddo": frazione del calore dai poteri.
var power_heat_factor := 1.0


func _process(delta: float) -> void:
	if running:
		add(per_second * delta)


func reset() -> void:
	value = 0.0
	running = true
	changed.emit(value, level())


## Solo per la modalità prova: nel gioco il calore non scende mai.
func set_value(new_value: float) -> void:
	value = clampf(new_value, 0.0, MAX)
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
	var frog := get_tree().get_first_node_in_group("frog") as Node3D
	# I rottami dell'incendio non scaldano: altrimenti il fuoco vicino alla
	# rana accelererebbe se stesso.
	var near := frog == null or frog.global_position.distance_to(car.global_position) <= wreck_radius
	if near and not car.has_meta("burnt"):
		add(per_wreck)
	wreck_created.emit(car)


func on_power_used(power: StringName) -> void:
	var costs := {&"punch": per_punch, &"super_jump": per_super_jump, &"glide": per_glide, &"tongue": per_tongue, &"slam": per_slam}
	if costs.has(power):
		add(costs[power] * power_heat_factor)


func traffic_speed_factor() -> float:
	return 1.0 + max_traffic_speed_bonus * ratio()


func river_speed_factor() -> float:
	return 1.0 + max_river_speed_bonus * ratio()


func gap_factor() -> float:
	return 1.0 + max_gap_increase * ratio()


func braking_factor() -> float:
	return 1.0 - max_braking_reduction * ratio()


func crash_speed_factor() -> float:
	return 1.0 - max_crash_speed_reduction * ratio()


## Probabilità al secondo che un veicolo perda il controllo: zero sotto la
## soglia, poi cresce fino al massimo.
func loss_of_control_chance() -> float:
	var over := (ratio() - instability_start) / (1.0 - instability_start)
	return max_loss_of_control_per_second * clampf(over, 0.0, 1.0)
