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
##
## Gli attrezzi (deciso il 6 ottobre 2026): la rana parte con un solo
## attrezzo (equip_kit), e tutto il resto arriva dalle carte. Uno slot vuoto
## vuol dire nessun potere; "base" è l'attrezzo semplice, senza modificatore,
## e una carta di quello slot lo sostituisce. Una carta dà l'attrezzo nella sua
## versione: coi guantoni esplosivi la rana ha i guantoni, e sono esplosivi.

signal offered(options: Array[String])
signal equipped(id: String)

## Il valore di uno slot con l'attrezzo semplice.
const BASE := "base"
## L'attrezzo semplice di ogni slot (il corpo non ne ha).
const BASE_SLOTS := ["gloves", "springs", "wing", "tongue"]
## I potenziamenti numerici che servono a un attrezzo: senza, non si offrono.
const NEEDS := {"punch_power": "gloves", "quick_springs": "springs", "big_wing": "wing"}

const SLOT_NAMES := {
	"gloves": "Guantoni", "springs": "Molle", "wing": "Ala", "body": "Corpo", "tongue": "Lingua",
}

## Nei testi i tasti si scrivono col nome dell'azione fra graffe ("{slam}"):
## le carte li mostrano come sono assegnati nelle opzioni (Settings.with_keys).
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
		"text": "In aria, {slam}: piombi giù e all'atterraggio un'onda ribalta le auto intorno.",
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
		"text": "{tongue}: la lingua aggancia da sola la cosa più vicina dove guardi. Ti tira su auto, tronchi e navi; un rottame lo tira verso di te.",
	},
	"rocket_springs": {
		"name": "Molle a razzo", "slot": "springs",
		"text": "In aria, {super_jump} di nuovo: un secondo super salto.",
	},
	"shell": {
		"name": "Guscio", "slot": "body",
		"text": "Un guscio di tartaruga assorbe un colpo, poi si riforma in 25 s.",
	},
	"catapult_tongue": {
		"name": "Lingua-catapulta", "slot": "tongue",
		"text": "{tongue}: la lingua afferra un rottame e lo tiene sopra la testa; lasciando, lo scagli dove guardi.",
	},
	"insurance": {
		"name": "Assicurazione", "slot": "body",
		"text": "Un colpo mortale ti lascia con 1 di vita, una volta per sezione; ma il calore sale subito di un livello.",
	},
	"poison": {
		"name": "Rana velenosa", "slot": "body",
		"text": "L'auto che ti investe diventa rottame. Il colpo lo prendi lo stesso, e ogni rottame scalda.",
	},
	"armored_wing": {
		"name": "Ala corazzata", "slot": "wing",
		"text": "In volo l'ala para un colpo: niente danno, e resti in aria.",
	},
	"propeller_wing": {
		"name": "Ala a elica", "slot": "wing",
		"text": "Aperta, l'ala ti tiene sospesa sul posto per 2 s, come un seme d'acero; poi plani.",
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
	Car.chain_explosions = false
	Car.explosion_rocket = false


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


## Vero se la rana ha l'attrezzo dello slot (semplice o da carta).
func has_tool(slot: String) -> bool:
	return slots[slot] != ""


## Il modificatore dello slot ("" se lo slot è vuoto o ha l'attrezzo semplice).
func modifier(slot: String) -> String:
	return "" if slots[slot] == BASE else slots[slot]


## Gli attrezzi con cui parte la rana: per slot, BASE o l'id di una carta.
## Tutti gli altri restano spenti finché non arriva una carta.
func equip_kit(kit: Dictionary) -> void:
	for slot: String in slots:
		if slots[slot] != "" and slots[slot] != BASE:
			_remove(slots[slot])
		slots[slot] = ""
		_set_tool(slot, false)
	for slot: String in kit:
		if kit[slot] == BASE:
			slots[slot] = BASE
			_set_tool(slot, true)
		else:
			apply(kit[slot])


## Dà l'attrezzo semplice di uno slot vuoto (la modalità prova).
func give_base(slot: String) -> void:
	if slots[slot] == "":
		slots[slot] = BASE
		_set_tool(slot, true)


## Prepara un'offerta: tre power-up diversi, solo per slot ancora liberi (o
## con l'attrezzo semplice) e senza i numerici già al massimo o senza il loro
## attrezzo. Una fusione pronta c'è sempre.
func make_offer(count := -1) -> Array[String]:
	if count < 0:
		count = offer_size
	var fusions: Array[String] = []
	var pool: Array[String] = []
	for id: String in CATALOG:
		var item: Dictionary = CATALOG[id]
		if item.slot == "fusion":
			if fusion_ready(id) and Feats.card_available(id):
				fusions.append(id)
			continue
		# Lo slot è occupato per tutta la run (l'attrezzo semplice no: una
		# carta lo sostituisce).
		if item.slot != "" and slots[item.slot] != "" and slots[item.slot] != BASE:
			continue
		if item.slot == "" and stacks.get(id, 0) >= item.max:
			continue
		if NEEDS.has(id) and not has_tool(NEEDS[id]):
			continue
		# Le carte da sbloccare restano fuori finché la loro impresa non è fatta.
		if not Feats.card_available(id):
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
			_set_tool(slot, true)
		_set_modifier(id, true)
	elif item.slot != "":
		var previous: String = slots[item.slot]
		if previous != "" and previous != BASE:
			_remove(previous)
		slots[item.slot] = id
		_set_tool(item.slot, true)
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
		_set_tool(slot, false)


## Accende o spegne l'attrezzo di uno slot: il potere e il suo pezzo sul
## modello. La lingua semplice è il rampino (la carta "tongue").
func _set_tool(slot: String, on: bool) -> void:
	match slot:
		"gloves":
			frog.punch_power.enabled = on
		"springs":
			frog.super_jump_power.enabled = on
		"wing":
			frog.glider_power.enabled = on
		"tongue":
			frog.tongue_power.enabled = on


## Accende o spegne un modificatore. I miglioramenti speciali della carta
## (Progress.upgrade_active, attivati allo stagno) valgono solo da accesa.
func _set_modifier(id: String, on: bool) -> void:
	var first := on and Progress.CARD_UPGRADES.has(id) and Progress.upgrade_active(id, 0)
	var second := on and Progress.CARD_UPGRADES.has(id) and Progress.upgrade_active(id, 1)
	match id:
		"explosive_gloves":
			frog.punch_power.set_explosive(on)
		"uppercut":
			frog.punch_power.set_uppercut(on)
		"long_glove":
			frog.punch_power.set_long_reach(on)
		"trampoline":
			frog.trampoline = on
			frog.super_jump_power.set_spring_color("spring_bounce" if on else "")
		"slam":
			frog.slam_power.enabled = on
			frog.super_jump_power.set_spring_color("spring_heavy" if on else "")
		"thermals":
			frog.glider_power.set_thermals(on)
		"jet_wing":
			frog.glider_power.set_jet(on)
		"waterproof":
			frog.set_waterproof(on)
		"tongue":
			frog.tongue_power.enabled = on
		"rocket_springs":
			frog.super_jump_power.rocket = on
			frog.super_jump_power.set_spring_color("spring_rocket" if on else "")
		"shell":
			frog.shell = on
		"catapult_tongue":
			frog.tongue_power.catapult = on
		"insurance":
			frog.insurance = on
		"poison":
			frog.set_poisonous(on)
		"armored_wing":
			frog.glider_power.set_armored(on)
		"propeller_wing":
			frog.glider_power.set_propeller(on)
		"napalm":
			Car.smoke_seconds = 15.0 if on else Car.SMOKE_SECONDS
			frog.glider_power.wide_thermals = on
		"earthquake":
			frog.slam_power.radius = 10.0 if on else 6.0
			frog.slam_power.launch_speed = 13.0 if on else 9.0
	_set_special(id, first, second)


## I miglioramenti speciali della carta id (Progress.CARD_UPGRADES).
func _set_special(id: String, first: bool, second: bool) -> void:
	match id:
		"explosive_gloves":
			Car.chain_explosions = first
			Car.explosion_rocket = second
		"uppercut":
			frog.punch_power.meteor = first
			frog.punch_power.double_uppercut = second
		"long_glove":
			frog.punch_power.piercing = first
			frog.punch_power.yank = second
		"trampoline":
			frog.trampoline_crescendo = first
			frog.trampoline_wrecks = second
		"slam":
			frog.slam_power.double_wave = first
			frog.slam_power.from_the_sky = second
		"thermals":
			frog.glider_power.phoenix = first
			frog.glider_power.chimney = second
		"jet_wing":
			frog.glider_power.afterburner = first
			frog.glider_power.cooled = second
		"waterproof":
			frog.can_dive = first
			frog.splash_wave = second
		"tongue":
			frog.tongue_power.slingshot = first
			frog.tongue_power.double_tongue = second
		"rocket_springs":
			frog.super_jump_power.air_jumps = 2 if first else 1
			frog.super_jump_power.fire_trail = second
		"shell":
			frog.shell_spines = first
			frog.shell_quick = second
		"catapult_tongue":
			frog.tongue_power.long_throw = first
			frog.tongue_power.strike = second
		"insurance":
			frog.insurance_deductible = first
			frog.insurance_bonus = second
		"poison":
			frog.poison_spreads = first
			frog.antidote = second
		"armored_wing":
			frog.glider_power.ram = first
			frog.glider_power.armor_hits = 2 if second else 1
		"propeller_wing":
			frog.glider_power.turbine = first
			frog.glider_power.long_hover = second
