class_name Worlds
extends RefCounted
## I mondi della run (deciso il 7-8 ottobre 2026, vedi "Dopo la fase 1: i
## mondi" in docs/regole-design.md). La run passa da un mondo all'altro col
## teletrasporto, che compare quando il calore arriva al livello 5 e porta in
## un mondo nuovo col calore a 0. Finito l'ultimo mondo si ricomincia dal
## primo, come in Risk of Rain 2: è un giro nuovo, con un livello di Siccità
## in più per quella run.
##
## Gli stessi biomi in ogni mondo: cambiano soprattutto le skin dei pericoli.
## I colori di un mondo stanno nella tavolozza di Style, come voci
## "<mondo>/<voce>" (per esempio "cielo/grass") che sostituiscono la voce
## normale finché si è in quel mondo.

const ALL: Array[Dictionary] = [
	{"id": "terra", "name": "La terra"},
	{"id": "cielo", "name": "Il cielo"},
]

## Ogni mondo passato rende l'inseguitore più veloce di questa frazione
## (velocità e accelerazione), anche al giro dopo.
const CHASER_STEP := 0.15
## Ogni mondo passato alza il tetto delle sezioni di questi ostacoli: la
## quantità continua a crescere.
const GROWTH_STEP := 1


static func id_of(index: int) -> String:
	return ALL[index].id


static func name_of(index: int) -> String:
	return ALL[index].name


## Quanto corre l'inseguitore dopo passed mondi passati.
static func chaser_factor(passed: int) -> float:
	return 1.0 + CHASER_STEP * passed
