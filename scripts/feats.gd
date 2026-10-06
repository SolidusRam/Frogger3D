class_name Feats
extends RefCounted
## Le imprese (docs/imprese.md): ognuna sblocca una cosa sola, e si vede cosa.
## Le carte da sbloccare restano fuori dal mazzo delle tane finché la loro
## impresa non è fatta (il mazzo iniziale: due carte per slot).
##
## I principi (decisi il 6 ottobre 2026): l'impresa insegna il gesto che la
## carta potenzierà; il fallimento sblocca la difesa; la maestria riguarda le
## carte, le imprese il mondo; quasi tutte visibili, poche segrete; si
## scoprono durante la run, con un riquadro che non ferma il gioco.
##
## Chi le osserva è FeatTracker (un nodo della partita). I punti del gioco che
## non hanno un segnale loro avvisano con Feats.note(evento, valore).

## Le imprese, nell'ordine in cui si mostrano. "group": la sezione della
## schermata; "kind": cosa sbloccano (card, fusion, frog, token, style, color,
## hat); "reward": l'id di quello che sbloccano (per le carte, l'id in
## Upgrades.CATALOG); "reward_name": come si chiama.
const ALL := {
	"acrobata": {"group": "Carte", "name": "Pugno al volo", "text": "Colpisci un'auto mentre sei in aria", "kind": "card", "reward": "long_glove", "reward_name": "Guantone a molla"},
	"zattera": {"group": "Carte", "name": "Zattera di lamiera", "text": "Resta 3 s su un rottame che galleggia nel fiume", "kind": "card", "reward": "ice_gloves", "reward_name": "Guantoni di ghiaccio"},
	"tetto": {"group": "Carte", "name": "Atterraggio sul tetto", "text": "Atterra col super salto sul tetto di un'auto", "kind": "card", "reward": "slam", "reward_name": "Schianto sismico"},
	"slalom": {"group": "Carte", "name": "Senza fermarsi", "text": "Attraversa una strada di 4 corsie senza fermarti", "kind": "card", "reward": "kangaroo_springs", "reward_name": "Molle da canguro"},
	"treno": {"group": "Carte", "name": "Sopra il treno", "text": "Plana sopra un treno in corsa", "kind": "card", "reward": "propeller_wing", "reward_name": "Ala a elica"},
	"fiamma": {"group": "Carte", "name": "Mangiafuoco", "text": "Passa nella fiamma di un motore e sopravvivi", "kind": "card", "reward": "fire_tongue", "reward_name": "Lingua mangiafuoco"},
	"coda": {"group": "Carte", "name": "Ingorgo", "text": "Ferma una coda di 5 auto", "kind": "card", "reward": "anchor_tongue", "reward_name": "Lingua-ancora"},
	"quasi": {"group": "Carte", "name": "Quasi a casa", "text": "Muori a meno di 10 m da una tana", "kind": "card", "reward": "insurance", "reward_name": "Assicurazione"},
	"boomerang": {"group": "Carte", "name": "Boomerang", "text": "Fatti investire da un'auto che hai colpito tu", "kind": "card", "reward": "poison", "reward_name": "Rana velenosa"},
	"abbattuta": {"group": "Carte", "name": "Abbattuta in volo", "text": "Vieni colpita mentre voli", "kind": "card", "reward": "armored_wing", "reward_name": "Ala corazzata"},
	"tana5": {"group": "Rane", "name": "Cinque tane", "text": "Raggiungi la tana 5", "kind": "frog", "reward": "raganella", "reward_name": "Raganella"},
	"planata": {"group": "Rane", "name": "Planata lunga", "text": "Plana 50 m in un solo volo", "kind": "frog", "reward": "paracadutista", "reward_name": "Paracadutista"},
	"bracciate": {"group": "Rane", "name": "A bracciate", "text": "Nuota 100 m in una run", "kind": "frog", "reward": "fiume", "reward_name": "Rana di fiume"},
	"rimorchio": {"group": "Rane", "name": "Rimorchio", "text": "Fatti trascinare dalla lingua per 40 m", "kind": "frog", "reward": "camaleonte", "reward_name": "Camaleonte"},
	"pacifista": {"group": "Rane", "name": "Pacifista", "text": "Raggiungi la tana 3 senza usare il pugno", "kind": "frog", "reward": "rospo", "reward_name": "Rospo"},
	"fuochi": {"group": "Fusioni e gettoni", "name": "Fuochi d'artificio", "text": "Un'auto esplosa ne distrugge altre tre", "kind": "fusion", "reward": "napalm", "reward_name": "Napalm"},
	"scossa": {"group": "Fusioni e gettoni", "name": "Scossa", "text": "Uno schianto ribalta 5 auto", "kind": "fusion", "reward": "earthquake", "reward_name": "Terremoto"},
	"consegna": {"group": "Fusioni e gettoni", "name": "Consegna", "text": "Un container cade su un'auto", "kind": "token", "reward": "reroll", "reward_name": "Gettone Rilancia"},
	"pelo": {"group": "Fusioni e gettoni", "name": "Per un pelo", "text": "Raggiungi una tana col fuoco a meno di 5 m", "kind": "token", "reward": "skip", "reward_name": "Gettone Salta"},
	"maratona": {"group": "Fusioni e gettoni", "name": "Maratona", "text": "Sopravvivi 15 minuti", "kind": "token", "reward": "banish", "reward_name": "Gettone Esilia"},
	"duemila": {"group": "Traguardi", "name": "Duemila metri", "text": "Fai 2000 m in una run", "kind": "style", "reward": "new_style", "reward_name": "Uno stile grafico nuovo"},
	"incandescente": {"group": "Traguardi", "name": "Incandescente", "text": "Resta 2 minuti al livello 5 di calore", "kind": "color", "reward": "glowing", "reward_name": "Rana incandescente"},
	"arrosto": {"group": "Segrete", "secret": true, "name": "Arrosto", "text": "Muori bruciata dall'incendio", "kind": "color", "reward": "charred", "reward_name": "Rana carbonizzata"},
	"cantiere": {"group": "Segrete", "secret": true, "name": "Lavori in corso", "text": "Fatti schiacciare da un container", "kind": "hat", "reward": "hard_hat", "reward_name": "Elmetto da cantiere"},
	"esca": {"group": "Segrete", "secret": true, "name": "Esca", "text": "Fatti mordere da un coccodrillo mentre sei appesa alla lingua", "kind": "color", "reward": "croc", "reward_name": "Rana di coccodrillo"},
	"copilota": {"group": "Segrete", "secret": true, "name": "Copilota", "text": "Arriva al bordo seduta sull'ala di un aereo", "kind": "hat", "reward": "goggles", "reward_name": "Occhiali da pilota"},
}
## Le sezioni della schermata, in ordine.
const GROUPS := ["Carte", "Rane", "Fusioni e gettoni", "Traguardi", "Segrete"]

## Chi osserva la run in corso (null nel menu): Feats.note() gli passa gli
## eventi.
static var tracker: Node
## Nei test che non riguardano le imprese il mazzo è completo (tests/lib.gd).
static var unlock_all := false


## Tutto aperto: nei test (unlock_all) o per provare (l'opzione "Tutto
## sbloccato").
static func all_open() -> bool:
	return unlock_all or Settings.unlock_everything


## Un evento dal gioco ("explosion", "car_hit"...), con un valore.
static func note(event: StringName, value := 1.0) -> void:
	if tracker != null and is_instance_valid(tracker):
		tracker.on_event(event, value)


static func done(id: String) -> bool:
	return Progress.feats.get(id, false)


## Vero se la carta (o la fusione) può uscire nelle tane: nessuna impresa la
## tiene chiusa, o la sua è fatta.
static func card_available(card: String) -> bool:
	if all_open():
		return true
	for id: String in ALL:
		var feat: Dictionary = ALL[id]
		if feat.kind in ["card", "fusion"] and feat.reward == card:
			return done(id)
	return true


## Vero se quello che l'impresa sblocca c'è già nel gioco (le carte nuove, le
## rane, i gettoni e le cose da vedere arrivano a lotti).
static func reward_ready(id: String) -> bool:
	var feat: Dictionary = ALL[id]
	if feat.kind in ["card", "fusion"]:
		return Upgrades.CATALOG.has(feat.reward)
	if feat.kind == "frog":
		return Frogs.ALL.has(feat.reward)
	return false


## Quante imprese sono fatte.
static func count_done() -> int:
	return ALL.keys().filter(func(id: String) -> bool: return done(id)).size()
