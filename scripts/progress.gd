class_name Progress
extends RefCounted
## I progressi fra una run e l'altra: le mosche raccolte e cosa ci si è
## comprato allo stagno. Come in Vampire Survivors le mosche comprano forza
## permanente: statistiche a livelli, col prezzo che sale a ogni livello. Le
## carte invece migliorano con la maestria: ogni miglioramento ha una prova
## legata all'uso della carta, e superata la prova si attiva con le mosche
## d'oro. Si può chiedere il rimborso di tutto. Salvati in un file a parte dal
## record; i test ne usano uno loro.

## Statistiche: nome, effetto per livello, livelli massimi, prezzo base (il
## livello n costa base × n).
const STATS := {
	"health": {"name": "Vita", "text": "+10 di vita massima", "max": 5, "cost": 15},
	"armor": {"name": "Corazza", "text": "-5% di danno subito", "max": 4, "cost": 25},
	"regen": {"name": "Riposo", "text": "In tana recuperi il 15% della vita", "max": 3, "cost": 20},
	"invuln": {"name": "Riflessi", "text": "+0,25 s di invulnerabilità dopo un colpo", "max": 2, "cost": 20},
	"speed": {"name": "Zampe veloci", "text": "+4% di velocità a terra", "max": 4, "cost": 20},
	"jump": {"name": "Zampe forti", "text": "+8% di altezza del salto", "max": 3, "cost": 20},
	"swim": {"name": "Nuotatrice", "text": "+15% di velocità in acqua, -15% di danno dall'acqua", "max": 3, "cost": 15},
	"super_jump": {"name": "Molle tese", "text": "+0,5 m di super salto", "max": 3, "cost": 25},
	"cooldown": {"name": "Ricarica", "text": "-6% di ricarica dei poteri", "max": 4, "cost": 30},
	"punch": {"name": "Pugno", "text": "+10% di spinta del pugno", "max": 3, "cost": 20},
	"glide": {"name": "Ala", "text": "+0,3 s di volo col deltaplano", "max": 4, "cost": 20},
	"fire": {"name": "Vantaggio", "text": "L'incendio resta 5 m più lontano", "max": 4, "cost": 30},
	"calm": {"name": "Sangue freddo", "text": "-6% di calore dai poteri", "max": 4, "cost": 30},
	"magnet": {"name": "Lingua lunga", "text": "+0,7 m di raggio per prendere le mosche", "max": 3, "cost": 10},
	"greed": {"name": "Golosa", "text": "+10% di mosche raccolte", "max": 3, "cost": 30},
	"luck": {"name": "Fortuna", "text": "+50% di mosche d'oro", "max": 3, "cost": 25},
	"choice": {"name": "Più scelta", "text": "Una carta in più nelle tane", "max": 1, "cost": 150},
	"revival": {"name": "Seconda vita", "text": "Una volta per run ti rialzi con metà vita", "max": 1, "cost": 200},
}

## La maestria delle carte: due miglioramenti speciali per ogni carta con
## slot, che cambiano come si usa la carta. Ognuno ha la sua prova, legata
## all'uso della carta; superata la prova, il miglioramento si attiva allo
## stagno con le mosche d'oro. Prove "total": si sommano fra le run; "best":
## il migliore risultato in un colpo solo (o di fila).
const CARD_UPGRADES := {
	"explosive_gloves": [
		{"name": "Reazione a catena", "text": "Le auto distrutte da un'esplosione esplodono a loro volta.", "trial": "Fai esplodere 30 auto", "goal": 30, "kind": "total", "cost": 2},
		{"name": "Razzo", "text": "Un'esplosione vicina non ti ferisce: ti lancia in alto.", "trial": "Distruggi 4 auto con una sola esplosione", "goal": 4, "kind": "best", "cost": 4},
	],
	"uppercut": [
		{"name": "Meteora", "text": "L'auto lanciata ricade con un'onda che ribalta le auto intorno.", "trial": "Lancia 30 auto col montante", "goal": 30, "kind": "total", "cost": 2},
		{"name": "Doppio montante", "text": "Il pugno arriva anche in alto: un'auto ancora in aria la rilanci.", "trial": "Un'auto lanciata col montante ne ribalta un'altra ricadendo", "goal": 1, "kind": "total", "cost": 4},
	],
	"long_glove": [
		{"name": "Perforante", "text": "Il pugno colpisce tutte le auto sulla sua linea.", "trial": "Colpisci 25 auto da più di 3 m", "goal": 25, "kind": "total", "cost": 2},
		{"name": "Tira e molla", "text": "Il guantone afferra l'auto, la tira a sé e la scaglia via più forte.", "trial": "Colpisci 2 auto con un solo pugno", "goal": 2, "kind": "best", "cost": 4},
	],
	"trampoline": [
		{"name": "Crescendo", "text": "Ogni rimbalzo di fila è più alto del precedente.", "trial": "Rimbalza 50 volte sui tetti", "goal": 50, "kind": "total", "cost": 2},
		{"name": "Bombardiera", "text": "Ogni rimbalzo ribalta l'auto sotto di te.", "trial": "Rimbalza 6 volte di fila", "goal": 6, "kind": "best", "cost": 4},
	],
	"slam": [
		{"name": "Doppia onda", "text": "Mezzo secondo dopo, una seconda onda più larga.", "trial": "Ribalta 40 auto con lo schianto", "goal": 40, "kind": "total", "cost": 2},
		{"name": "Dal cielo", "text": "Anche col deltaplano aperto; più cadi dall'alto, più l'onda è grande.", "trial": "Ribalta 5 auto con un solo schianto", "goal": 5, "kind": "best", "cost": 4},
	],
	"thermals": [
		{"name": "Fenice", "text": "Nella colonna di fumo recuperi vita.", "trial": "Sali per 100 m nel fumo", "goal": 100, "kind": "total", "cost": 2},
		{"name": "Camino", "text": "Anche il fumo dell'incendio ti solleva come una corrente calda.", "trial": "Resta 6 s di fila in una colonna di fumo", "goal": 6, "kind": "best", "cost": 4},
	],
	"jet_wing": [
		{"name": "Postbruciatore", "text": "Dietro l'ala una scia di fuoco ribalta le auto sotto di te.", "trial": "Vola 800 m con l'ala a reazione", "goal": 800, "kind": "total", "cost": 2},
		{"name": "Raffreddata", "text": "In volo il calore non sale più.", "trial": "Vola 60 m in un solo volo", "goal": 60, "kind": "best", "cost": 4},
	],
	"waterproof": [
		{"name": "Tuffo", "text": "In acqua, Ctrl: ti immergi e passi sotto tronchi e coccodrilli.", "trial": "Nuota per 300 m", "goal": 300, "kind": "total", "cost": 2},
		{"name": "Ondata", "text": "Saltando fuori dall'acqua sollevi un'onda che spinge via auto e rottami.", "trial": "Resta 15 s di fila in acqua", "goal": 15, "kind": "best", "cost": 4},
	],
	"tongue": [
		{"name": "Fionda", "text": "Lasciando dopo un traino parti a velocità doppia.", "trial": "Fatti trascinare 20 volte", "goal": 20, "kind": "total", "cost": 2},
		{"name": "Lingua doppia", "text": "Mentre una lingua ti trascina, l'altra mangia le mosche vicine.", "trial": "Fatti trascinare per 50 m in un solo traino", "goal": 50, "kind": "best", "cost": 4},
	],
}

static var path := "user://progressi.cfg"
static var flies := 0
## Le mosche d'oro: servono solo ad attivare i miglioramenti delle carte.
static var golden := 0
static var stat_levels := {}
## Miglioramenti attivati ("carta:indice") e avanzamento delle prove.
static var card_active := {}
static var trials := {}
## Le prove di questa run: si aggiungono a trials a fine run (una run di
## prova no).
static var run_trials := {}


static func load_from(file_path: String) -> void:
	path = file_path
	var config := ConfigFile.new()
	var ok := config.load(path) == OK
	flies = config.get_value("stagno", "mosche", 0) if ok else 0
	golden = config.get_value("stagno", "mosche_oro", 0) if ok else 0
	stat_levels = config.get_value("stagno", "statistiche", {}) if ok else {}
	card_active = config.get_value("stagno", "carte_attive", {}) if ok else {}
	trials = config.get_value("stagno", "prove", {}) if ok else {}
	run_trials = {}


static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("stagno", "mosche", flies)
	config.set_value("stagno", "mosche_oro", golden)
	config.set_value("stagno", "statistiche", stat_levels)
	config.set_value("stagno", "carte_attive", card_active)
	config.set_value("stagno", "prove", trials)
	config.save(path)


static func level(stat: String) -> int:
	return stat_levels.get(stat, 0)


static func stat_cost(stat: String) -> int:
	var info: Dictionary = STATS[stat]
	return -1 if level(stat) >= info.max else info.cost * (level(stat) + 1)


static func buy_stat(stat: String) -> bool:
	var cost := stat_cost(stat)
	if cost < 0 or cost > flies:
		return false
	flies -= cost
	stat_levels[stat] = level(stat) + 1
	save()
	return true


# --- La maestria delle carte ------------------------------------------------

static func _key(card: String, index: int) -> String:
	return "%s:%d" % [card, index]


## Vero se il miglioramento index della carta è stato attivato.
static func upgrade_active(card: String, index: int) -> bool:
	return card_active.get(_key(card, index), false)


## A che punto è la prova: le run passate più questa.
static func trial_value(card: String, index: int) -> float:
	var key := _key(card, index)
	var saved: float = trials.get(key, 0.0)
	var now: float = run_trials.get(key, 0.0)
	return saved + now if CARD_UPGRADES[card][index].kind == "total" else maxf(saved, now)


static func trial_done(card: String, index: int) -> bool:
	return trial_value(card, index) >= CARD_UPGRADES[card][index].goal


## Una prova "total" avanza di amount.
static func trial_add(card: String, index: int, amount: float) -> void:
	var key := _key(card, index)
	run_trials[key] = run_trials.get(key, 0.0) + amount


## Una prova "best": vale il risultato migliore.
static func trial_best(card: String, index: int, value: float) -> void:
	var key := _key(card, index)
	run_trials[key] = maxf(run_trials.get(key, 0.0), value)


## Fine run: le prove di questa run si aggiungono a quelle salvate.
static func commit_run() -> void:
	for key: String in run_trials:
		var card := key.get_slice(":", 0)
		var index := int(key.get_slice(":", 1))
		if CARD_UPGRADES[card][index].kind == "total":
			trials[key] = trials.get(key, 0.0) + run_trials[key]
		else:
			trials[key] = maxf(trials.get(key, 0.0), run_trials[key])
	run_trials = {}
	save()


## Attiva un miglioramento: prova superata e mosche d'oro abbastanza.
static func activate(card: String, index: int) -> bool:
	var cost: int = CARD_UPGRADES[card][index].cost
	if upgrade_active(card, index) or not trial_done(card, index) or cost > golden:
		return false
	golden -= cost
	card_active[_key(card, index)] = true
	save()
	return true


## Le mosche spese nelle statistiche, cioè quante tornano col rimborso.
static func spent() -> int:
	var total := 0
	for stat: String in stat_levels:
		for n in stat_levels[stat]:
			total += STATS[stat].cost * (n + 1)
	return total


## Le mosche d'oro spese nei miglioramenti delle carte.
static func spent_golden() -> int:
	var total := 0
	for key: String in card_active:
		total += CARD_UPGRADES[key.get_slice(":", 0)][int(key.get_slice(":", 1))].cost
	return total


## Come in Vampire Survivors: si azzera tutto e le mosche (anche quelle
## d'oro) tornano indietro. Le prove superate restano superate.
static func refund() -> void:
	flies += spent()
	golden += spent_golden()
	stat_levels = {}
	card_active = {}
	save()


static func add_flies(amount: int, golden_amount := 0) -> void:
	flies += amount
	golden += golden_amount
	save()
