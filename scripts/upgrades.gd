class_name Upgrades
extends Node
## I power-up della rana e il suo equipaggiamento. Si scelgono nelle tane, uno
## tra tre. Gli slot sono gli attrezzi della rana (guantoni, molle, ala, corpo,
## lingua): ogni slot porta un solo modificatore, e una volta scelto resta
## per tutta la run: la tana non offre più carte per uno slot occupato. I
## potenziamenti numerici non hanno slot e si sommano, fino a un massimo
## ciascuno.
## Le fusioni: quando sono equipaggiati entrambi i modificatori di una fusione,
## la tana successiva la offre di sicuro. La fusione non sostituisce niente:
## occupa i due slot e tiene gli effetti di tutti e due, più il suo.
## apply() sa anche sostituire un modificatore (e togliere una fusione): lo usa
## la modalità prova, non la tana.

signal offered(options: Array[String])
signal equipped(id: String)

const SLOT_NAMES := {
	"gloves": "Guantoni", "springs": "Molle", "wing": "Ala", "body": "Corpo", "tongue": "Lingua",
}

const CATALOG := {
	"explosive_gloves": {
		"name": "Guantoni esplosivi", "slot": "gloves",
		"text": "L'auto colpita esplode quando urta un altro veicolo: le auto intorno diventano rottami. Attento a non starle vicino.",
	},
	"uppercut": {
		"name": "Montante", "slot": "gloves",
		"text": "Il pugno solleva le auto: volano in alto e ricadono su altre auto.",
	},
	"long_glove": {
		"name": "Guantone a molla", "slot": "gloves",
		"text": "Il pugno arriva a 4 m invece che a 1,3.",
	},
	"trampoline": {
		"name": "Molle-trampolino", "slot": "springs",
		"text": "Sui tetti delle auto rimbalzi da sola: il traffico diventa una strada.",
	},
	"slam": {
		"name": "Schianto sismico", "slot": "springs",
		"text": "In aria, Ctrl: piombi giù e all'atterraggio un'onda ribalta le auto intorno.",
	},
	"thermals": {
		"name": "Correnti calde", "slot": "wing",
		"text": "Col deltaplano aperto, il fumo dei rottami ti solleva e la carica non si consuma.",
	},
	"jet_wing": {
		"name": "Ala a reazione", "slot": "wing",
		"text": "Il deltaplano va molto più veloce, ma finché voli il calore sale.",
	},
	"waterproof": {
		"name": "Pelle impermeabile", "slot": "body",
		"text": "L'acqua non toglie più vita.",
	},
	"tongue": {
		"name": "Lingua-rampino", "slot": "tongue",
		"text": "E: la lingua aggancia da sola la cosa più vicina dove guardi. Ti tira su auto, tronchi e navi; un rottame lo tira verso di te.",
	},
	"punch_power": {"name": "Pugno più forte", "slot": "", "max": 3, "text": "+30% di spinta del pugno."},
	"quick_springs": {"name": "Molle rapide", "slot": "", "max": 3, "text": "Il super salto si ricarica il 25% più in fretta."},
	"big_wing": {"name": "Ala più grande", "slot": "", "max": 3, "text": "+1 secondo di volo col deltaplano."},
	"tough_skin": {"name": "Pelle dura", "slot": "", "max": 3, "text": "+25 di vita massima, e vita piena subito."},
	# Le fusioni: "parts" sono i due modificatori da avere equipaggiati.
	"napalm": {
		"name": "Napalm", "slot": "fusion", "parts": ["explosive_gloves", "thermals"],
		"text": "Guantoni esplosivi + Correnti calde. I rottami fumano 15 s invece di 6, e le colonne di fumo sono più larghe.",
	},
	"earthquake": {
		"name": "Terremoto", "slot": "fusion", "parts": ["uppercut", "slam"],
		"text": "Montante + Schianto sismico. L'onda arriva a 10 m e scaglia le auto molto più in alto.",
	},
}

@export var frog: Frog

var slots := {"gloves": "", "springs": "", "wing": "", "body": "", "tongue": ""}
## Quante volte è stato preso ogni potenziamento numerico.
var stacks := {}
var current_offer: Array[String] = []
## Carte offerte da ogni tana (la statistica "Più scelta" ne aggiunge una).
var offer_size := 3


func _ready() -> void:
	# Valori condivisi che una carta o una fusione può aver cambiato nella run
	# precedente.
	Car.smoke_seconds = Car.SMOKE_SECONDS
	Car.explosion_radius = Car.EXPLOSION_RADIUS
	Car.explosion_hurts_frog = true


## Gli slot di una carta: due per una fusione, uno per un modificatore,
## nessuno per un potenziamento numerico.
static func slots_of(id: String) -> Array:
	var item: Dictionary = CATALOG[id]
	if item.slot == "fusion":
		return item.parts.map(func(part): return CATALOG[part].slot)
	return [] if item.slot == "" else [item.slot]


## Vero se la fusione si può offrire: entrambe le parti equipaggiate.
func fusion_ready(id: String) -> bool:
	var item: Dictionary = CATALOG[id]
	return item.slot == "fusion" and item.parts.all(func(part): return slots[CATALOG[part].slot] == part)


## Prepara un'offerta: tre power-up diversi, solo per slot ancora liberi e
## senza i numerici già al massimo. Una fusione pronta c'è sempre.
func make_offer(count := -1) -> Array[String]:
	if count < 0:
		count = offer_size
	var fusions: Array[String] = []
	var pool: Array[String] = []
	for id: String in CATALOG:
		var item: Dictionary = CATALOG[id]
		if item.slot == "fusion":
			if fusion_ready(id):
				fusions.append(id)
			continue
		# Lo slot è occupato per tutta la run.
		if item.slot != "" and slots[item.slot] != "":
			continue
		if item.slot == "" and stacks.get(id, 0) >= item.max:
			continue
		pool.append(id)
	pool.shuffle()
	var offer: Array[String] = fusions.slice(0, count)
	offer.append_array(pool.slice(0, count - offer.size()))
	current_offer.assign(offer)
	offered.emit(current_offer)
	return current_offer


func choose(index: int) -> void:
	if index < 0 or index >= current_offer.size():
		return
	var id := current_offer[index]
	current_offer.clear()
	apply(id)


func apply(id: String) -> void:
	var item: Dictionary = CATALOG[id]
	if item.slot == "fusion":
		for slot: String in slots_of(id):
			slots[slot] = id
		_set_modifier(id, true)
	elif item.slot != "":
		var previous: String = slots[item.slot]
		if previous != "":
			_remove(previous)
		slots[item.slot] = id
		_set_modifier(id, true)
	else:
		stacks[id] = stacks.get(id, 0) + 1
		match id:
			"punch_power":
				frog.punch_power.impulse *= 1.3
			"quick_springs":
				frog.super_jump_power.cooldown *= 0.75
			"big_wing":
				frog.glider_power.duration += 1.0
				frog.glider_power.charge = frog.glider_power.duration
			"tough_skin":
				frog.max_health += 25
				frog.heal_full()
	equipped.emit(id)


## Toglie un modificatore; una fusione si porta via anche le sue parti.
func _remove(id: String) -> void:
	var item: Dictionary = CATALOG[id]
	_set_modifier(id, false)
	if item.slot == "fusion":
		for part: String in item.parts:
			_set_modifier(part, false)
	for slot: String in slots_of(id):
		slots[slot] = ""


## Accende o spegne un modificatore, coi miglioramenti comprati allo stagno
## (Progress.card_level: 0, 1 o 2).
func _set_modifier(id: String, on: bool) -> void:
	var level := Progress.card_level(id) if on else 0
	match id:
		"explosive_gloves":
			frog.punch_power.set_explosive(on)
			Car.explosion_radius = 8.0 if level >= 1 else Car.EXPLOSION_RADIUS
			Car.explosion_hurts_frog = level < 2
		"uppercut":
			frog.punch_power.set_uppercut(on)
			frog.punch_power.uppercut_lift = 1.8 if level >= 1 else 1.2
			frog.punch_power.uppercut_push = 1.4 if level >= 2 else 1.0
		"long_glove":
			frog.punch_power.set_long_reach(on)
			frog.punch_power.long_reach_distance = 5.5 if level >= 1 else 4.0
			frog.punch_power.long_reach_radius = 2.5 if level >= 2 else 1.25
		"trampoline":
			frog.trampoline = on
			frog.trampoline_height = 3.6 if level >= 1 else 2.6
			frog.trampoline_wrecks = level >= 2
			frog.super_jump_power.set_spring_color("spring_bounce" if on else "")
		"slam":
			frog.slam_power.enabled = on
			frog.slam_power.radius = 6.0 + (2.0 if level >= 1 else 0.0)
			frog.slam_power.cooldown = (1.0 if level >= 2 else 2.0) * frog.cooldown_factor
			frog.super_jump_power.set_spring_color("spring_heavy" if on else "")
		"thermals":
			frog.glider_power.set_thermals(on)
			frog.glider_power.thermal_rise_speed = 6.0 if level >= 1 else 4.0
			Car.smoke_seconds = 9.0 if level >= 2 else Car.SMOKE_SECONDS
		"jet_wing":
			frog.glider_power.set_jet(on)
			frog.glider_power.jet_heat_per_second = 0.75 if level >= 1 else 1.5
			frog.glider_power.jet_speed = 20.0 if level >= 2 else 16.0
		"waterproof":
			frog.set_waterproof(on)
			frog.swim_speed = frog.base_swim_speed * (1.6 if level >= 1 else 1.0)
			frog.water_jump_factor = 1.15 if level >= 2 else 0.85
		"tongue":
			frog.tongue_power.enabled = on
			frog.tongue_power.reach = 16.0 if level >= 1 else 12.0
			frog.tongue_power.cooldown = (0.5 if level >= 2 else 1.0) * frog.cooldown_factor
		"napalm":
			Car.smoke_seconds = 15.0 if on else Car.SMOKE_SECONDS
			frog.glider_power.wide_thermals = on
		"earthquake":
			var bonus := 2.0 if Progress.card_level("slam") >= 1 else 0.0
			frog.slam_power.radius = (10.0 if on else 6.0) + bonus
			frog.slam_power.launch_speed = 13.0 if on else 9.0
