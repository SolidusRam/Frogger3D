class_name Aerobatics
extends Node3D
## La pattuglia acrobatica, il bioma che c'è solo nel cielo (deciso l'8
## ottobre 2026): un banco di nubi su cui passano, ogni tanto, i passaggi
## della pattuglia (vedi Formation). La regola nuova: le traiettorie sono
## curve, anche verticali, e la scia del capo dice dove passeranno i gregari.
## Con la distanza crescono i gregari e arrivano gli incroci (due passaggi
## insieme, da lati opposti); col calore corrono di più e lasciano meno tempo
## per leggere la scia; dal livello 3 (il gradino) metà dei capi ha perso il
## controllo e la scia è uno scarabocchio. Resa più difficile l'8 ottobre
## 2026, su richiesta: più veloce, più fitta, più curve e giri della morte.

var difficulty := 0
## Profondità del blocco: le curve ci stanno dentro.
var depth := 24.0
var play_half_width := 37.0
## Secondi fra un passaggio e l'altro.
var min_interval := 3.5
var max_interval := 6.5
var base_speed := 19.0
var max_heat_bonus := 0.3
var scribble_chance := 0.5
## Da questa difficoltà della sezione (la distanza), a volte due passaggi
## insieme, da lati opposti, che si incrociano: più probabile più avanti.
var cross_from := 2
var cross_chance := 0.35
var max_cross_chance := 0.6

var _timer := 0.0


func _ready() -> void:
	_timer = randf_range(0.5, 3.0)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		send()
		_timer = randf_range(min_interval, max_interval)


## Un passaggio della pattuglia, da un lato a caso; a volte, con la
## distanza, un secondo dall'altro lato che lo incrocia.
func send() -> Formation:
	var direction := 1.0 if randf() < 0.5 else -1.0
	var formation := _send(direction)
	if difficulty >= cross_from and randf() < minf(cross_chance + 0.05 * (difficulty - cross_from), max_cross_chance):
		_send(-direction)
	return formation


func _send(direction: float) -> Formation:
	var formation := Formation.new()
	formation.direction = direction
	formation.speed = base_speed * (1.0 + max_heat_bonus * Heat.ratio())
	formation.wingmen = clampi(3 + floori(difficulty / 2.0), 3, 6)
	formation.first_delay = lerpf(1.3, 0.9, Heat.ratio())
	formation.half_depth = depth / 2.0
	formation.half_length = play_half_width + 30.0
	formation.scribble = Heat.level() >= Heat.STEP_LEVEL and randf() < scribble_chance
	add_child(formation)
	return formation
