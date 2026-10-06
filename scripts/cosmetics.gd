class_name Cosmetics
extends RefCounted
## Il guardaroba: cappelli e colori della rana, solo da vedere. Si sbloccano
## con le imprese (Feats, reward) e si scelgono per ogni rana nella schermata
## delle rane; la scelta si salva (Progress.wardrobe).
##
## I cappelli sono modelli (assets/models/hat_<id>.glb, da build_models.py)
## appesi alla testa; quelli della rana che stanno dove va il cappello (la
## cuffia della paracadutista) si tolgono. I colori sono voci della tavolozza
## per la pelle.

const HATS := {
	"hard_hat": {"name": "Elmetto da cantiere"},
	"goggles": {"name": "Occhiali da pilota"},
}
const COLORS := {
	"glowing": {"name": "Rana incandescente", "palette": "frog_glowing"},
	"charred": {"name": "Rana carbonizzata", "palette": "frog_charred"},
	"croc": {"name": "Rana di coccodrillo", "palette": "frog_croc"},
}
## Gli accessori di una rana che un cappello copre.
const HAT_HIDES := ["Head__cap", "Head__goggles"]


## Vero se il cappello o il colore id è sbloccato: la sua impresa è fatta.
static func unlocked(id: String) -> bool:
	if Feats.all_open():
		return true
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
		"color": color if COLORS.has(color) and unlocked(color) else "",
	}


## Sceglie per la rana; "" toglie.
static func choose(frog: String, kind: String, id: String) -> void:
	var pick: Dictionary = Progress.wardrobe.get(frog, {}).duplicate()
	pick[kind] = id
	Progress.wardrobe[frog] = pick
	Progress.save()


## Il prossimo sbloccato dopo id nella lista ("" = niente), per i pulsanti
## che girano.
static func next(kind: String, id: String) -> String:
	var all: Array = [""] + (HATS.keys() if kind == "hat" else COLORS.keys())
	var open: Array = all.filter(func(item: String) -> bool: return item == "" or unlocked(item))
	return open[(open.find(id) + 1) % open.size()]


## Il nome da mostrare (già tradotto).
static func name_of(kind: String, id: String) -> String:
	if id == "":
		return TranslationServer.translate("Nessuno" if kind == "hat" else "Quello della rana")
	return TranslationServer.translate((HATS if kind == "hat" else COLORS)[id].name)


## Quanti ne restano da sbloccare (per dire che ce ne sono altri).
static func locked_count(kind: String) -> int:
	var all: Array = HATS.keys() if kind == "hat" else COLORS.keys()
	return all.filter(func(item: String) -> bool: return not unlocked(item)).size()
