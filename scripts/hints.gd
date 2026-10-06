class_name Hints
extends Node
## I suggerimenti del primo minuto, nell'HUD. Ognuno compare quando la
## situazione lo chiede (una strada davanti: il pugno; un fiume: il
## deltaplano; l'incendio vicino: la tana) e sparisce quando lo si esegue.
## Eseguito in due run, non compare più ("Rivedi i suggerimenti" nelle opzioni
## li rimette). Chi fa la cosa da solo, prima del suggerimento, non lo vede.
##
## Il più importante è il calore: compare subito dopo il primo potere usato,
## quando la regola si sta infrangendo ("ogni potere scalda il mondo, e il
## calore non scende mai").
##
## Nelle prime run l'incendio aspetta che la rana si muova: i primi
## suggerimenti si leggono senza il fuoco alle spalle.
##
## Deciso il 5 ottobre 2026: niente cartelli nel mondo, i suggerimenti stanno
## nell'HUD.

## In quante run va eseguito un suggerimento perché non compaia più.
const RETIRE_AFTER := 2
## L'ordine conta solo a parità di momento; l'incendio passa davanti a tutti.
const ORDER := ["move", "punch", "heat", "glide", "super_jump", "fire", "fly"]
## Suggerimenti che si eseguono leggendoli (non c'è un gesto da fare).
const INFO := ["heat"]
## Quanto resta, al massimo, un suggerimento: d'azione e da leggere.
const ACTION_SECONDS := 10.0
const INFO_SECONDS := 7.0
## Pausa fra un suggerimento e il successivo.
const GAP_SECONDS := 1.2
## Metri da fare perché "muoviti" sia eseguito (e l'incendio parta).
const MOVE_METERS := 10.0
## Una mosca più vicina di così fa comparire il suo suggerimento.
const FLY_METERS := 10.0
## L'incendio più vicino di così fa comparire il suo.
const FIRE_METERS := 30.0
## Il super salto si suggerisce davanti alla ferrovia, o dopo questi secondi.
const SUPER_JUMP_SECONDS := 25.0

var game: Node
var frog: Frog
var course: Course
var hud: Hud
var fire: Wildfire

## Eseguiti o mostrati in questa run: non ricompaiono fino alla prossima.
var _done := {}
var _shown := {}
var _queue: Array[String] = []
var _current := ""
var _current_left := 0.0
var _gap := 0.6
var _start_z := 0.0
var _caught := 0
var _over := false


## Collega i suggerimenti alla partita. Si aggiunge come figlio di game.
func setup(the_game: Node) -> void:
	game = the_game
	frog = game.frog
	course = game.course
	hud = game.hud
	fire = game.get_node("Wildfire")
	_start_z = frog.global_position.z
	frog.punched.connect(func(cars: Array[Car]) -> void:
		if not cars.is_empty():
			_mark("punch"))
	frog.power_used.connect(_on_power_used)
	frog.died.connect(_on_died)
	course.den_reached.connect(func(_count: int, _distance: float) -> void: _mark("fire"))
	hud.pond_opened.connect(func() -> void:
		_mark("pond")
		hud.highlight_pond(""))
	Settings.changed.connect(_rerender)
	if _wanted("move"):
		fire.waiting = true
		_queue.append("move")


## Vero se il suggerimento serve ancora: non ritirato e non già visto in
## questa run.
func _wanted(id: String) -> bool:
	return Progress.hint_count(id) < RETIRE_AFTER and not _done.has(id) and not _shown.has(id)


func _physics_process(delta: float) -> void:
	if _over:
		return
	_watch()
	if _current != "":
		_current_left -= delta
		if _current_left <= 0.0:
			if _current in INFO:
				_mark(_current)
			_finish(false)
		return
	_gap -= delta
	if _gap <= 0.0 and not _queue.is_empty():
		_show(_queue.pop_front())


## Le situazioni che fanno comparire i suggerimenti, e i gesti che li
## eseguono senza un segnale apposta.
func _watch() -> void:
	var moved := _start_z - frog.global_position.z
	if moved > MOVE_METERS:
		_mark("move")
	if frog.is_gliding():
		_mark("glide")
	var caught: int = game.run_flies + game.run_golden
	if caught > _caught:
		_mark("fly")
	_caught = caught
	var ahead := course.kind_at(frog.global_position.z - 5.0)
	var here := course.kind_at(frog.global_position.z)
	# Si suggeriscono solo i poteri degli attrezzi che la rana ha: quelli
	# arrivati da una carta compaiono alla prima occasione dopo la tana.
	if (ahead == Course.Kind.ROAD or here == Course.Kind.ROAD) and frog.punch_power.enabled:
		_want("punch")
	var water := course.kind_at(frog.global_position.z - 8.0)
	if (water == Course.Kind.RIVER or water == Course.Kind.PORT) and frog.glider_power.enabled:
		_want("glide")
	if (ahead == Course.Kind.RAIL or game.run_time > SUPER_JUMP_SECONDS) and frog.super_jump_power.enabled:
		_want("super_jump")
	if not fire.waiting and fire.distance() < FIRE_METERS:
		_want("fire", true)
	for fly: Node3D in get_tree().get_nodes_in_group("flies"):
		if fly.global_position.distance_to(frog.global_position) < FLY_METERS:
			_want("fly")
			break


## Mette in coda un suggerimento (urgent: davanti a tutti).
func _want(id: String, urgent := false) -> void:
	if not _wanted(id) or id in _queue or id == _current:
		return
	if urgent:
		_queue.push_front(id)
	else:
		_queue.append(id)


func _on_power_used(power: StringName) -> void:
	if power == &"super_jump":
		_mark("super_jump")
	# La regola del calore, appena la si infrange: davanti agli altri.
	_want("heat", true)


## Eseguito: conta per questa run (una volta) e, se è quello in vista, lo
## chiude con un lampo verde.
func _mark(id: String) -> void:
	if _done.has(id):
		return
	_done[id] = true
	_queue.erase(id)
	if Progress.hint_count(id) < RETIRE_AFTER:
		Progress.hint_done(id)
	if id == "move":
		fire.waiting = false
	if id == _current and not id in INFO:
		_finish(true)


func _show(id: String) -> void:
	_current = id
	_shown[id] = true
	_current_left = INFO_SECONDS if id in INFO else ACTION_SECONDS
	hud.show_hint(_render(id))


func _finish(done: bool) -> void:
	_current = ""
	_gap = GAP_SECONDS
	hud.clear_hint(done)


## Passati dalla tastiera al controller (o cambiata la lingua): il testo si
## riscrive coi comandi nuovi.
func _rerender() -> void:
	if _current != "":
		hud.update_hint(_render(_current))


## Alla fine della corsa, con le mosche in tasca: lo stagno in evidenza.
func _on_died() -> void:
	_over = true
	_queue.clear()
	if _current != "":
		_finish(false)
	if game.run_flies + game.run_golden > 0 and _wanted("pond"):
		_shown["pond"] = true
		hud.highlight_pond(tr("Spendi le mosche allo stagno: diventi più forte per la prossima corsa"))


## Il testo di un suggerimento, coi comandi in oro.
func _render(id: String) -> String:
	var text := ""
	match id:
		"move":
			text = tr("{moves}: muoviti   ·   {jump}: salta   ·   {look}: guarda intorno")
		"punch":
			text = tr("{punch}: pugno! L'auto colpita vola e si schianta contro le altre")
		"heat":
			text = tr("Ogni potere scalda il mondo, e il calore non scende mai: traffico più veloce, incendio più rapido")
		"glide":
			text = tr("In aria, tieni premuto {jump}: deltaplano, per planare sopra l'acqua")
		"super_jump":
			text = tr("{super_jump}: super salto, per scavalcare quello che non puoi attraversare")
		"fire":
			text = tr("L'incendio ti insegue! Raggiungi la tana: lo respinge")
		"fly":
			text = tr("Prendi le mosche: dopo la corsa si spendono allo stagno")
	var gold := UiTheme.GOLD.to_html(false)
	var keys := {"moves": _moves(), "look": tr("Levetta destra") if Settings.using_pad else tr("Mouse")}
	for action: String in Settings.ACTIONS:
		keys[action] = Settings.key_name(action)
	for key: String in keys:
		text = text.replace("{%s}" % key, "[color=#%s]%s[/color]" % [gold, keys[key]])
	return text


## I quattro tasti per muoversi, scritti insieme ("WASD"), o la levetta.
func _moves() -> String:
	if Settings.using_pad:
		return tr("Levetta sinistra")
	var names: Array = ["move_forward", "move_left", "move_back", "move_right"].map(func(action: String) -> String: return Settings.key_name(action))
	var short := names.all(func(name: String) -> bool: return name.length() == 1)
	return "".join(names) if short else " ".join(names)
