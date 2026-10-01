class_name Upgrades
extends Node
## I power-up della rana e il suo equipaggiamento. Si scelgono nelle tane, uno
## tra tre. Gli slot sono gli attrezzi della rana (guantoni, molle, ala, corpo):
## ogni slot porta un solo modificatore, e sceglierne un altro per lo stesso
## slot sostituisce il primo. I potenziamenti numerici non hanno slot e si
## sommano, fino a un massimo ciascuno.

signal offered(options: Array[String])
signal equipped(id: String)

const SLOT_NAMES := {"gloves": "Guantoni", "springs": "Molle", "wing": "Ala", "body": "Corpo"}

const CATALOG := {
	"explosive_gloves": {
		"name": "Guantoni esplosivi", "slot": "gloves",
		"text": "L'auto colpita esplode quando urta un altro veicolo: le auto intorno diventano rottami. Attento a non starle vicino.",
	},
	"thermals": {
		"name": "Correnti calde", "slot": "wing",
		"text": "Col deltaplano aperto, il fumo dei rottami ti solleva e la carica non si consuma.",
	},
	"punch_power": {"name": "Pugno più forte", "slot": "", "max": 3, "text": "+30% di spinta del pugno."},
	"quick_springs": {"name": "Molle rapide", "slot": "", "max": 3, "text": "Il super salto si ricarica il 25% più in fretta."},
	"big_wing": {"name": "Ala più grande", "slot": "", "max": 3, "text": "+1 secondo di volo col deltaplano."},
	"tough_skin": {"name": "Pelle dura", "slot": "", "max": 3, "text": "+25 di vita massima, e vita piena subito."},
}

@export var frog: Frog

var slots := {"gloves": "", "springs": "", "wing": "", "body": ""}
## Quante volte è stato preso ogni potenziamento numerico.
var stacks := {}
var current_offer: Array[String] = []


## Prepara un'offerta: tre power-up diversi, senza quelli già equipaggiati e
## senza i numerici già al massimo.
func make_offer(count := 3) -> Array[String]:
	var pool: Array[String] = []
	for id: String in CATALOG:
		var item: Dictionary = CATALOG[id]
		if item.slot != "" and slots[item.slot] == id:
			continue
		if item.slot == "" and stacks.get(id, 0) >= item.max:
			continue
		pool.append(id)
	pool.shuffle()
	current_offer.assign(pool.slice(0, count))
	offered.emit(current_offer)
	return current_offer


func choose(index: int) -> void:
	if index < 0 or index >= current_offer.size():
		return
	var id := current_offer[index]
	current_offer.clear()
	apply(id)


## Il power-up che occupa ora lo slot di id, se diverso ("" se lo slot è
## libero o se id non ha slot).
func replaced_by(id: String) -> String:
	var slot: String = CATALOG[id].slot
	if slot == "" or slots[slot] == "" or slots[slot] == id:
		return ""
	return slots[slot]


func apply(id: String) -> void:
	var item: Dictionary = CATALOG[id]
	if item.slot != "":
		var previous: String = slots[item.slot]
		if previous != "":
			_set_modifier(previous, false)
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


func _set_modifier(id: String, on: bool) -> void:
	match id:
		"explosive_gloves":
			frog.punch_power.set_explosive(on)
		"thermals":
			frog.glider_power.set_thermals(on)
