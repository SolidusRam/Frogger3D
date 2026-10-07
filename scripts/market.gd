class_name Market
extends RefCounted
## Il mercatino dello stagno e le uova di rana (deciso il 7 ottobre 2026):
## dove si spendono le mosche quando le statistiche non bastano più.
##
## Il mercatino espone SLOTS cappelli o colori che il giocatore non ha, a un
## prezzo per rarità; cambiano a ogni run (refresh, alla fine della corsa).
## L'uovo, a prezzo fisso, si schiude in un oggetto a caso fra quelli che non
## si hanno: niente doppioni, e i rari e gli epici escono meno spesso.

const SLOTS := 3
const PRICES := {"common": 40, "rare": 90, "epic": 180}
const EGG_PRICE := 70
## Quanto pesa ogni rarità nell'uovo.
const EGG_WEIGHTS := {"common": 60.0, "rare": 30.0, "epic": 10.0}

## Un caso tutto suo: il mercatino non consuma quello del mondo (che con lo
## stesso seme deve generare lo stesso percorso).
static var _rng := RandomNumberGenerator.new()


## Gli oggetti esposti ora ([tipo, id], solo quelli che non si hanno). Se non
## ce ne sono (la prima volta), li sceglie.
static func stock() -> Array:
	var shown: Array = Progress.market.filter(func(item: Array) -> bool: return not Progress.owned.has(item[1]))
	if shown.is_empty() and Progress.market.is_empty():
		# Si salva col prossimo salvataggio: guardare non scrive niente.
		Progress.market = _pick()
		shown = Progress.market.duplicate()
	return shown


## Un giro nuovo: SLOTS oggetti a caso fra quelli che mancano.
static func refresh() -> void:
	Progress.market = _pick()
	Progress.save()


static func _pick() -> Array:
	var missing := Cosmetics.missing_items()
	for i in range(missing.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Array = missing[i]
		missing[i] = missing[j]
		missing[j] = swap
	return missing.slice(0, SLOTS)


static func price(id: String) -> int:
	return PRICES.get(Cosmetics.rarity_of(id), 0)


## Compra un oggetto esposto: vero se è andata.
static func buy(id: String) -> bool:
	var cost := price(id)
	if Progress.owned.has(id) or cost <= 0 or cost > Progress.flies:
		return false
	Progress.flies -= cost
	Progress.owned[id] = true
	Progress.save()
	return true


## Si può comprare un uovo: mosche abbastanza e qualcosa che manca.
static func egg_ready() -> bool:
	return Progress.flies >= EGG_PRICE and not Cosmetics.missing_items().is_empty()


## L'uovo si schiude: un oggetto che manca, pesato per rarità ([tipo, id];
## vuoto se non si può).
static func hatch() -> Array:
	if not egg_ready():
		return []
	var missing := Cosmetics.missing_items()
	var total := 0.0
	for item: Array in missing:
		total += EGG_WEIGHTS[Cosmetics.rarity_of(item[1])]
	var roll := _rng.randf() * total
	var picked: Array = missing.back()
	for item: Array in missing:
		roll -= EGG_WEIGHTS[Cosmetics.rarity_of(item[1])]
		if roll < 0.0:
			picked = item
			break
	Progress.flies -= EGG_PRICE
	Progress.owned[picked[1]] = true
	Progress.save()
	return picked
