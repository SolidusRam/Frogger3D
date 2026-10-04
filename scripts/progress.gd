class_name Progress
extends RefCounted
## I progressi fra una run e l'altra: le mosche raccolte e cosa ci si è
## comprato allo stagno. Come in Vampire Survivors le mosche comprano forza
## permanente: statistiche a livelli e carte migliorate (due miglioramenti
## per ogni carta con slot). Il prezzo sale a ogni livello. Si può chiedere
## il rimborso di tutto. Salvati in un file a parte dal record; i test ne
## usano uno loro.

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

## I due miglioramenti di ogni carta con slot, in ordine.
const CARD_UPGRADES := {
	"explosive_gloves": [
		{"text": "Raggio dell'esplosione da 6 a 8 m", "cost": 40},
		{"text": "Le esplosioni non ti fanno male", "cost": 80},
	],
	"uppercut": [
		{"text": "Le auto volano ancora più in alto", "cost": 30},
		{"text": "+40% di spinta col montante", "cost": 60},
	],
	"long_glove": [
		{"text": "Il pugno arriva a 5,5 m", "cost": 30},
		{"text": "Il pugno colpisce una zona larga il doppio", "cost": 60},
	],
	"trampoline": [
		{"text": "Rimbalzi fino a 3,6 m", "cost": 30},
		{"text": "Rimbalzando ribalti l'auto sotto di te", "cost": 60},
	],
	"slam": [
		{"text": "L'onda arriva 2 m più lontano", "cost": 40},
		{"text": "Si ricarica in 1 s invece che in 2", "cost": 60},
	],
	"thermals": [
		{"text": "Nel fumo si sale più in fretta", "cost": 30},
		{"text": "I rottami fumano 9 s invece di 6", "cost": 60},
	],
	"jet_wing": [
		{"text": "Scalda la metà", "cost": 40},
		{"text": "Vola a 20 m/s", "cost": 60},
	],
	"waterproof": [
		{"text": "Nuoti molto più veloce", "cost": 30},
		{"text": "Dall'acqua salti fuori come da terra", "cost": 40},
	],
	"tongue": [
		{"text": "La lingua arriva a 16 m", "cost": 40},
		{"text": "La lingua si ricarica in metà tempo", "cost": 60},
	],
}

static var path := "user://progressi.cfg"
static var flies := 0
static var stat_levels := {}
static var card_levels := {}


static func load_from(file_path: String) -> void:
	path = file_path
	var config := ConfigFile.new()
	var ok := config.load(path) == OK
	flies = config.get_value("stagno", "mosche", 0) if ok else 0
	stat_levels = config.get_value("stagno", "statistiche", {}) if ok else {}
	card_levels = config.get_value("stagno", "carte", {}) if ok else {}


static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("stagno", "mosche", flies)
	config.set_value("stagno", "statistiche", stat_levels)
	config.set_value("stagno", "carte", card_levels)
	config.save(path)


static func level(stat: String) -> int:
	return stat_levels.get(stat, 0)


static func card_level(card: String) -> int:
	return card_levels.get(card, 0)


## Il prezzo del prossimo livello (-1 se è già al massimo).
static func stat_cost(stat: String) -> int:
	var info: Dictionary = STATS[stat]
	return -1 if level(stat) >= info.max else info.cost * (level(stat) + 1)


static func card_cost(card: String) -> int:
	var upgrades: Array = CARD_UPGRADES[card]
	return -1 if card_level(card) >= upgrades.size() else upgrades[card_level(card)].cost


static func buy_stat(stat: String) -> bool:
	var cost := stat_cost(stat)
	if cost < 0 or cost > flies:
		return false
	flies -= cost
	stat_levels[stat] = level(stat) + 1
	save()
	return true


static func buy_card(card: String) -> bool:
	var cost := card_cost(card)
	if cost < 0 or cost > flies:
		return false
	flies -= cost
	card_levels[card] = card_level(card) + 1
	save()
	return true


## Tutto ciò che è stato speso, cioè quanto torna col rimborso.
static func spent() -> int:
	var total := 0
	for stat: String in stat_levels:
		for n in stat_levels[stat]:
			total += STATS[stat].cost * (n + 1)
	for card: String in card_levels:
		for n in card_levels[card]:
			total += CARD_UPGRADES[card][n].cost
	return total


## Come in Vampire Survivors: si azzera tutto e le mosche tornano indietro.
static func refund() -> void:
	flies += spent()
	stat_levels = {}
	card_levels = {}
	save()


static func add_flies(amount: int) -> void:
	flies += amount
	save()
