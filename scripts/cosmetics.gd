class_name Cosmetics
extends RefCounted
## Il guardaroba: cappelli e colori della rana, solo da vedere. Si sbloccano
## con le imprese (Feats, reward) e si scelgono per ogni rana nella schermata
## delle rane; la scelta si salva (Progress.wardrobe).
##
## Da dove arrivano (deciso il 7 ottobre 2026): quelli con "rarity" si
## comprano al mercatino o escono dalle uova (vedi Market); quelli senza si
## guadagnano con le imprese; le pelli a gradi con la Siccità.
##
## I cappelli sono modelli (assets/models/hat_<id>.glb, da build_models.py)
## appesi alla testa; quelli della rana che stanno dove va il cappello (la
## cuffia della paracadutista) si tolgono. I colori sono voci della tavolozza
## per la pelle.

const HATS := {
	"hard_hat": {"name": "Elmetto da cantiere"},
	"goggles": {"name": "Occhiali da pilota"},
	"beanie": {"name": "Berretta col pompon", "rarity": "common"},
	"cap": {"name": "Berretto da baseball", "rarity": "common"},
	"straw": {"name": "Cappello di paglia", "rarity": "common"},
	"chef": {"name": "Cappello da cuoco", "rarity": "rare"},
	"cowboy": {"name": "Cappello da cowboy", "rarity": "rare"},
	"fez": {"name": "Fez", "rarity": "rare"},
	"pirate": {"name": "Tricorno", "rarity": "rare"},
	"top_hat": {"name": "Cilindro", "rarity": "epic"},
	"crown": {"name": "Corona", "rarity": "epic"},
	"propeller": {"name": "Berretto con l'elica", "rarity": "epic"},
}
const COLORS := {
	"glowing": {"name": "Rana incandescente", "palette": "frog_glowing"},
	"charred": {"name": "Rana carbonizzata", "palette": "frog_charred"},
	"croc": {"name": "Rana di coccodrillo", "palette": "frog_croc"},
	"mint": {"name": "Menta", "palette": "frog_mint", "rarity": "common"},
	"lemon": {"name": "Limone", "palette": "frog_lemon", "rarity": "common"},
	"chocolate": {"name": "Cioccolato", "palette": "frog_chocolate", "rarity": "common"},
	"pumpkin": {"name": "Zucca", "palette": "frog_pumpkin", "rarity": "common"},
	"strawberry": {"name": "Fragola", "palette": "frog_strawberry", "rarity": "rare"},
	"lavender": {"name": "Lavanda", "palette": "frog_lavender", "rarity": "rare"},
	"night": {"name": "Notte", "palette": "frog_night", "rarity": "rare"},
	"emerald": {"name": "Smeraldo", "palette": "frog_emerald", "rarity": "rare"},
	"albino": {"name": "Albina", "palette": "frog_albino", "rarity": "epic"},
	"dart": {"name": "Blu dendrobate", "palette": "frog_dart", "rarity": "epic"},
}
## Le pelli a gradi della Siccità (vedi Drought): ogni rana la guadagna da
## sé, superando quel livello di Siccità con lei. Brillano come metallo.
const TIERS := {
	"copper": {"name": "Rame", "palette": "frog_copper", "level": 1},
	"silver": {"name": "Argento", "palette": "frog_silver", "level": 3},
	"gold": {"name": "Oro", "palette": "frog_gold", "level": 5},
}
## Gli accessori di una rana che un cappello copre.
const HAT_HIDES := ["Head__cap", "Head__goggles"]


## Vero se il cappello o il colore id è sbloccato: la sua impresa è fatta (le
## pelli a gradi: il livello di Siccità superato con quella rana).
static func unlocked(id: String, frog := "") -> bool:
	if Feats.all_open():
		return true
	if TIERS.has(id):
		return Drought.best(frog) >= TIERS[id].level
	if rarity_of(id) != "":
		return Progress.owned.has(id)
	for feat: String in Feats.ALL:
		if Feats.ALL[feat].reward == id and Feats.ALL[feat].kind in ["hat", "color"]:
			return Feats.done(feat)
	return false


## La scelta della rana: {"hat": id o "", "color": id o ""}, solo cose
## sbloccate.
static func chosen(frog: String) -> Dictionary:
	var pick: Dictionary = Progress.wardrobe.get(frog, {})
	var hat: String = pick.get("hat", "")
	var color: String = pick.get("color", "")
	return {
		"hat": hat if HATS.has(hat) and unlocked(hat) else "",
		"color": color if _colors().has(color) and unlocked(color, frog) else "",
	}


## I colori e le pelli a gradi insieme.
static func _colors() -> Dictionary:
	var all := COLORS.duplicate()
	all.merge(TIERS)
	return all


## La voce della tavolozza di un colore o di una pelle a gradi.
static func palette_of(id: String) -> String:
	return _colors()[id].palette


## La pelle a gradi che si guadagna superando quel livello ("" nessuna).
static func tier_for(level: int) -> String:
	for id: String in TIERS:
		if TIERS[id].level == level:
			return id
	return ""


## Sceglie per la rana; "" toglie.
static func choose(frog: String, kind: String, id: String) -> void:
	var pick: Dictionary = Progress.wardrobe.get(frog, {}).duplicate()
	pick[kind] = id
	Progress.wardrobe[frog] = pick
	Progress.save()


## Il prossimo sbloccato dopo id nella lista ("" = niente), per i pulsanti
## che girano.
static func next(kind: String, id: String, frog := "") -> String:
	var all: Array = [""] + (HATS.keys() if kind == "hat" else _colors().keys())
	var open: Array = all.filter(func(item: String) -> bool: return item == "" or unlocked(item, frog))
	return open[(open.find(id) + 1) % open.size()]


## Il nome da mostrare (già tradotto).
static func name_of(kind: String, id: String) -> String:
	if id == "":
		return TranslationServer.translate("Nessuno" if kind == "hat" else "Quello della rana")
	return TranslationServer.translate((HATS if kind == "hat" else _colors())[id].name)


## Quanti ne restano da sbloccare (per dire che ce ne sono altri).
static func locked_count(kind: String, frog := "") -> int:
	var all: Array = HATS.keys() if kind == "hat" else _colors().keys()
	return all.filter(func(item: String) -> bool: return not unlocked(item, frog)).size()



# --- Il mercatino e le uova (vedi Market) -------------------------------------

## La rarità di un oggetto del mercatino ("" per quelli delle imprese e della
## Siccità).
static func rarity_of(id: String) -> String:
	var item: Dictionary = HATS.get(id, COLORS.get(id, {}))
	return item.get("rarity", "")


## Gli oggetti che si comprano o escono dalle uova: [tipo, id].
static func shop_items() -> Array:
	var items: Array = []
	for id: String in HATS:
		if rarity_of(id) != "":
			items.append(["hat", id])
	for id: String in COLORS:
		if rarity_of(id) != "":
			items.append(["color", id])
	return items


## Quelli che il giocatore non ha ancora.
static func missing_items() -> Array:
	return shop_items().filter(func(item: Array) -> bool: return not Progress.owned.has(item[1]))
