class_name Aerobatics
extends Node3D
## La pattuglia acrobatica, il bioma che c'è solo nel cielo (deciso l'8
## ottobre 2026): un banco di nubi su cui passano, ogni tanto, i passaggi
## della pattuglia (vedi Formation). La regola nuova: le traiettorie sono
## curve, anche verticali, e la scia del capo dice dove passeranno i gregari.
## Con la distanza crescono i gregari; col calore corrono di più e lasciano
## meno tempo per leggere la scia; dal livello 3 (il gradino) metà dei capi
## ha perso il controllo e la scia è uno scarabocchio.

var difficulty := 0
## Profondità del blocco: le curve ci stanno dentro.
var depth := 24.0
var play_half_width := 37.0
## Secondi fra un passaggio e l'altro.
var min_interval := 5.0
var max_interval := 9.0
var base_speed := 16.0
var max_heat_bonus := 0.3
var scribble_chance := 0.5

var _timer := 0.0


func _ready() -> void:
	_timer = randf_range(0.5, 3.0)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		send()
		_timer = randf_range(min_interval, max_interval)


## Un passaggio della pattuglia, da un lato a caso.
func send() -> Formation:
	var formation := Formation.new()
	formation.direction = 1.0 if randf() < 0.5 else -1.0
	formation.speed = base_speed * (1.0 + max_heat_bonus * Heat.ratio())
	formation.wingmen = clampi(2 + floori(difficulty / 2.0), 2, 5)
	formation.first_delay = lerpf(1.6, 1.15, Heat.ratio())
	formation.half_depth = depth / 2.0
	formation.half_length = play_half_width + 30.0
	formation.scribble = Heat.level() >= Heat.STEP_LEVEL and randf() < scribble_chance
	add_child(formation)
	return formation
