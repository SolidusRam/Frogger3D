class_name Drought
extends RefCounted
## La Siccità: livelli di difficoltà da scegliere per ogni rana, come il Calore
## di Hades o l'Ascensione di Slay the Spire (deciso il 6 ottobre 2026; il nome
## è provvisorio). La foresta più secca brucia prima: ogni livello aggiunge un
## handicap a quelli prima e fa valere le mosche il 20% in più.
##
## Si sbloccano per ogni rana: raggiungere la tana 5 al livello n apre il
## livello n + 1. Ai livelli 1, 3 e 5 superati la rana guadagna la pelle di
## rame, d'argento e d'oro (vedi Cosmetics.TIERS).

## Gli handicap, dal livello 1 al 5 (si sommano).
const LEVELS := [
	"L'incendio parte 10 m più vicino",
	"Il traffico va il 15% più veloce",
	"Nelle tane una carta in meno",
	"I colpi fanno il 25% di danno in più",
	"Il calore sale il 30% più in fretta",
]
## La tana da raggiungere per superare un livello.
const GOAL_DEN := 5
## Mosche in più per ogni livello.
const FLY_BONUS := 0.2


## Il livello più alto superato con la rana (-1: nessuno).
static func best(frog: String) -> int:
	return Progress.drought_best.get(frog, -1)


## Il livello più alto che si può scegliere con la rana.
static func max_level(frog: String) -> int:
	if Feats.all_open():
		return LEVELS.size()
	return mini(best(frog) + 1, LEVELS.size())


## Il livello scelto per la rana (mai oltre quelli aperti).
static func selected(frog: String) -> int:
	return clampi(Progress.drought_level.get(frog, 0), 0, max_level(frog))


static func choose(frog: String, level: int) -> void:
	Progress.drought_level[frog] = clampi(level, 0, max_level(frog))
	Progress.save()


## La tana GOAL_DEN raggiunta al livello: vero se è un livello nuovo superato.
static func reached(frog: String, level: int) -> bool:
	if level <= best(frog):
		return false
	Progress.drought_best[frog] = level
	Progress.save()
	return true


## Gli handicap del livello sulla partita (all'inizio della run, dopo lo
## stagno).
static func apply(game: Node, level: int) -> void:
	for n in range(1, level + 1):
		apply_level(game, n)
	game.fly_value *= 1.0 + FLY_BONUS * level


## L'handicap di un solo livello. Serve anche al giro nuovo dei mondi, che
## aggiunge un livello per quella run (vedi Worlds).
static func apply_level(game: Node, level: int) -> void:
	match level:
		1:
			var fire: Wildfire = game.get_node("Wildfire")
			fire.max_gap -= 10.0
			fire.front_z = game.frog.global_position.z + fire.max_gap
		2:
			Heat.traffic_factor = 1.15
		3:
			game.upgrades.offer_size = maxi(game.upgrades.offer_size - 1, 2)
		4:
			game.frog.damage_factor *= 1.25
		5:
			Heat.growth_factor = 1.3
