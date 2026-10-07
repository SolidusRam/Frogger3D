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
## La rarità su una carta con la maestria già completa: vita e mosche.
signal rarity_bonus(rarity: String)

## La rarità delle carte (R3, decisa il 7 ottobre 2026): una modifica può
## uscire rara (con uno dei suoi miglioramenti di maestria non ancora attivi,
## per questa run) o epica (con tutti quelli che mancano); le fusioni sono
## leggendarie. Su una carta con la maestria già completa la rarità dà vita e
## mosche (vedi rarity_bonus). La fortuna la alzano la Siccità e la statistica
## dello stagno "Occhio fino" (update_luck).
const RARE_CHANCE := 0.2
const EPIC_CHANCE := 0.05
## In più per ogni livello di Siccità e di Occhio fino.
const DROUGHT_LUCK := Vector2(0.03, 0.01)
const EYE_LUCK := Vector2(0.04, 0.015)

## I gettoni della tana (docs/imprese.md): Rilancia (carte nuove), Salta (niente
## carta, qualche mosca), Esilia (una carta esce dal mazzo per la run). Ognuno
## si sblocca con la sua impresa e si usa TOKEN_USES volte per run.
const TOKENS := {"reroll": "consegna", "skip": "pelo", "banish": "maratona"}
const TOKEN_USES := 2

## Il valore di uno slot con l'attrezzo semplice.
const BASE := "base"
## L'attrezzo semplice di ogni slot (il corpo non ne ha).
const BASE_SLOTS := ["gloves", "springs", "wing", "tongue"]
## I potenziamenti numerici che servono a un attrezzo: senza, non si offrono.
const NEEDS := {"punch_power": "gloves", "quick_springs": "springs", "big_wing": "wing"}

const SLOT_NAMES := {
	"gloves": "Guantoni", "springs": "Molle", "wing": "Ala", "body": "Corpo", "tongue": "Lingua",
}

## Gli attrezzi in due passi (deciso il 7 ottobre 2026): le carte "tool"
## danno l'attrezzo semplice e escono solo per gli slot vuoti; le modifiche
## escono solo per gli attrezzi che si hanno e sostituiscono la versione
## semplice. La lingua semplice è il rampino (la carta "tongue"). Il corpo
## resta in un passo.
##
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
	"tool_gloves": {
		"name": "Guantoni", "slot": "gloves", "tool": true,
		"text": "{punch}: il pugno. L'auto colpita vola e si schianta contro le altre.",
	},
	"tool_springs": {
		"name": "Molle", "slot": "springs", "tool": true,
		"text": "{super_jump}: il super salto, per scavalcare quello che non puoi attraversare.",
	},
	"tool_wing": {
		"name": "Ala", "slot": "wing", "tool": true,
		"text": "In aria, tieni premuto {jump}: il deltaplano, per planare sopra l'acqua.",
	},
	"tongue": {
		"name": "Lingua-rampino", "slot": "tongue", "tool": true,
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
	"ice_gloves": {
		"name": "Guantoni di ghiaccio", "slot": "gloves",
		"text": "L'auto colpita diventa un blocco di ghiaccio fermo: ci sali sopra. Colpito di nuovo, scivola come al curling e travolge le auto.",
	},
	"kangaroo_springs": {
		"name": "Molle da canguro", "slot": "springs",
		"text": "Ogni salto fatto appena atterrata è più lungo e veloce del precedente. Fermarsi azzera il ritmo.",
	},
	"fire_tongue": {
		"name": "Lingua mangiafuoco", "slot": "tongue",
		"text": "{tongue} vicino al fuoco (un rottame che fuma, l'incendio): lo ingoi. {tongue} di nuovo: lo sputi, e la prima auto che colpisce diventa rottame.",
	},
	"anchor_tongue": {
		"name": "Lingua-ancora", "slot": "tongue",
		"text": "{tongue}: la lingua aggancia un'auto, un tronco o una nave e la ferma per 4 s. Un'auto ferma è un muro, un tronco fermo è un ponte.",
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
## La rarità di ogni carta dell'offerta: {"rarity", "upgrades": [indici dei
## miglioramenti per la run], "bonus": vero se dà vita e mosche}.
var current_rarity: Array[Dictionary] = []
## I miglioramenti di maestria avuti dalla rarità in questa run, per carta.
var run_specials := {}
var rare_chance := RARE_CHANCE
var epic_chance := EPIC_CHANCE
## Gettoni rimasti in questa run, e le carte esiliate.
var tokens := {"reroll": 0, "skip": 0, "banish": 0}
var banished: Array[String] = []
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
			apply(kit[slot], false)


## I gettoni all'inizio della run: quelli sbloccati, TOKEN_USES ciascuno.
func reset_tokens() -> void:
	for kind: String in TOKENS:
		tokens[kind] = TOKEN_USES if Feats.all_open() or Feats.done(TOKENS[kind]) else 0
	banished.clear()


## Rilancia: un'offerta nuova al posto di questa.
func reroll() -> Array[String]:
	tokens.reroll -= 1
	return make_offer()


## Esilia: la carta index esce dal mazzo per il resto della run, e l'offerta
## si rifà senza.
func banish(index: int) -> Array[String]:
	tokens.banish -= 1
	banished.append(current_offer[index])
	return make_offer()


## Dà l'attrezzo semplice di uno slot vuoto (la modalità prova).
func give_base(slot: String) -> void:
	if slots[slot] == "":
		slots[slot] = BASE
		_set_tool(slot, true)


## Vero se la carta può uscire per lo stato dello slot: un attrezzo per uno
## slot vuoto, una modifica sopra un attrezzo semplice, il corpo se è libero.
func _fits_slot(id: String) -> bool:
	var item: Dictionary = CATALOG[id]
	var held: String = slots[item.slot]
	if item.get("tool", false) or item.slot == "body":
		return held == ""
	return held == BASE or (held != "" and CATALOG.has(held) and CATALOG[held].get("tool", false))


## Prepara un'offerta: tre power-up diversi, che stanno negli slot (vedi
## _fits_slot), senza i numerici già al massimo o senza il loro attrezzo. Una
## fusione pronta c'è sempre. La spinta: finché c'è uno slot vuoto, almeno un
## attrezzo nuovo è fra le carte.
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
		if item.slot != "" and not _fits_slot(id):
			continue
		if item.slot == "" and stacks.get(id, 0) >= item.max:
			continue
		if NEEDS.has(id) and not has_tool(NEEDS[id]):
			continue
		# Le carte da sbloccare restano fuori finché la loro impresa non è fatta.
		if not Feats.card_available(id) or id in banished:
			continue
		pool.append(id)
	pool.shuffle()
	var offer: Array[String] = fusions.slice(0, count)
	offer.append_array(pool.slice(0, count - offer.size()))
	var tools := pool.filter(func(id: String) -> bool: return CATALOG[id].get("tool", false))
	if not tools.is_empty() and not offer.any(func(id: String) -> bool: return id in tools) and offer.size() > fusions.size():
		offer[offer.size() - 1] = tools[0]
	current_rarity.clear()
	for id: String in offer:
		current_rarity.append(_roll_rarity(id))
	current_offer.assign(offer)
	offered.emit(current_offer)
	return current_offer


func choose(index: int) -> void:
	if index < 0 or index >= current_offer.size():
		return
	var id := current_offer[index]
	var rarity: Dictionary = current_rarity[index] if index < current_rarity.size() else {}
	current_offer.clear()
	current_rarity.clear()
	# I miglioramenti della rarità valgono da subito, per questa run.
	for upgrade: int in rarity.get("upgrades", []):
		var specials: Array = run_specials.get(id, [false, false])
		specials[upgrade] = true
		run_specials[id] = specials
	apply(id)
	if rarity.get("bonus", false):
		rarity_bonus.emit(rarity.rarity)


## La fortuna: base, più Siccità e Occhio fino.
func update_luck(eye_level: int, drought_level: int) -> void:
	rare_chance = RARE_CHANCE + DROUGHT_LUCK.x * drought_level + EYE_LUCK.x * eye_level
	epic_chance = EPIC_CHANCE + DROUGHT_LUCK.y * drought_level + EYE_LUCK.y * eye_level


## La rarità di una carta dell'offerta. Attrezzi semplici e numerici sono
## sempre comuni, le fusioni leggendarie.
func _roll_rarity(id: String) -> Dictionary:
	var item: Dictionary = CATALOG[id]
	if item.slot == "fusion":
		return {"rarity": "legendary", "upgrades": [], "bonus": false}
	if item.get("tool", false) or item.slot == "" or not Progress.CARD_UPGRADES.has(id):
		return {"rarity": "common", "upgrades": [], "bonus": false}
	var roll := randf()
	var rarity := "epic" if roll < epic_chance else ("rare" if roll < epic_chance + rare_chance else "common")
	if rarity == "common":
		return {"rarity": rarity, "upgrades": [], "bonus": false}
	var missing: Array = [0, 1].filter(func(index: int) -> bool: return not Progress.upgrade_active(id, index))
	if missing.is_empty():
		return {"rarity": rarity, "upgrades": [], "bonus": true}
	missing.shuffle()
	return {"rarity": rarity, "upgrades": missing if rarity == "epic" else [missing[0]], "bonus": false}


func apply(id: String, announce := true) -> void:
	var item: Dictionary = CATALOG[id]
	if item.slot == "fusion":
		for slot: String in slots_of(id):
			slots[slot] = id
			_set_tool(slot, true)
		_set_modifier(id, true)
	elif item.get("tool", false) and id != "tongue":
		# L'attrezzo semplice: lo slot lo tiene come quelli di partenza.
		if slots[item.slot] != "" and slots[item.slot] != BASE:
			_remove(slots[item.slot])
		slots[item.slot] = BASE
		_set_tool(item.slot, true)
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
	# equipped vuol dire "scelta una carta": la partita chiude le carte e
	# ricattura il mouse. Gli attrezzi iniziali si montano in silenzio.
	if announce:
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
	# I miglioramenti attivi: quelli dello stagno, più quelli della rarità.
	var specials: Array = run_specials.get(id, [false, false])
	var first: bool = on and Progress.CARD_UPGRADES.has(id) and (Progress.upgrade_active(id, 0) or specials[0])
	var second: bool = on and Progress.CARD_UPGRADES.has(id) and (Progress.upgrade_active(id, 1) or specials[1])
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
		"ice_gloves":
			frog.punch_power.ice = on
		"kangaroo_springs":
			frog.kangaroo = on
			frog.kangaroo_streak = 0
			frog.super_jump_power.set_spring_color("spring_kangaroo" if on else "")
		"fire_tongue":
			frog.tongue_power.fire_eater = on
			frog.tongue_power.loaded = false
		"anchor_tongue":
			frog.tongue_power.anchor = on
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
		"ice_gloves":
			frog.punch_power.rink = first
			frog.punch_power.iceberg = second
		"kangaroo_springs":
			frog.kangaroo_pouch = first
			frog.kangaroo_long = second
		"fire_tongue":
			frog.tongue_power.volley = first
			frog.tongue_power.dragon = second
		"anchor_tongue":
			frog.tongue_power.heavy_anchor = first
			frog.tongue_power.double_anchor = second
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
