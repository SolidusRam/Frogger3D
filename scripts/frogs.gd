class_name Frogs
extends RefCounted
## Le rane (docs/imprese.md): ognuna parte con un solo attrezzo (vedi
## Upgrades.equip_kit) e ha un pro e un contro. La comune c'è dall'inizio, le
## altre si sbloccano con la loro impresa (Feats, gruppo "Rane"). Valori da
## tarare giocando.
##
## "kit": gli attrezzi iniziali (Upgrades.BASE o l'id di una carta);
## "color": la voce della tavolozza per la pelle ("" la verde di sempre);
## "mods": cosa cambia rispetto alla comune (vita, salto, volo, nuoto, passo,
## ricarica della lingua).
const ALL := {
	"comune": {"name": "Comune", "kit": {"gloves": "base"}, "color": "",
		"pro": "Equilibrata: parte col pugno", "contro": "Nessuno", "mods": {}},
	"raganella": {"name": "Raganella", "kit": {"springs": "base"}, "color": "frog_tree",
		"pro": "Salto normale molto più alto", "contro": "70 di vita", "mods": {"health": 70, "jump": 1.6}},
	"paracadutista": {"name": "Paracadutista", "kit": {"wing": "base"}, "color": "frog_sky",
		"pro": "Il deltaplano dura il doppio", "contro": "Niente pugno finché una tana non le dà i guantoni", "mods": {"glide": 2.0}},
	"fiume": {"name": "Rana di fiume", "kit": {"body": "waterproof"}, "color": "",
		"pro": "Nuota veloce, e l'acqua non la ferisce", "contro": "Lenta a terra", "mods": {"swim": 1.6, "speed": 0.85}},
	"camaleonte": {"name": "Camaleonte", "kit": {"tongue": "tongue"}, "color": "frog_chameleon",
		"pro": "La lingua si ricarica in metà tempo", "contro": "70 di vita", "mods": {"health": 70, "tongue_cooldown": 0.5}},
	"rospo": {"name": "Rospo", "kit": {}, "color": "frog_toad",
		"pro": "150 di vita", "contro": "Parte senza attrezzi: il Frogger puro fino alla prima tana", "mods": {"health": 150}},
}


## Vero se la rana si può scegliere: la comune sempre, le altre con la loro
## impresa fatta.
static func unlocked(id: String) -> bool:
	if id == "comune" or Feats.all_open():
		return true
	var feat := unlock_feat(id)
	return feat != "" and Feats.done(feat)


## L'impresa che sblocca la rana ("" per la comune).
static func unlock_feat(id: String) -> String:
	for feat: String in Feats.ALL:
		if Feats.ALL[feat].kind == "frog" and Feats.ALL[feat].reward == id:
			return feat
	return ""


## La rana scelta, se si può ancora scegliere (altrimenti la comune).
static func selected() -> String:
	return Progress.frog if ALL.has(Progress.frog) and unlocked(Progress.frog) else "comune"


## Gli attrezzi iniziali scritti per esteso ("guantoni", "pelle
## impermeabile"), già tradotti.
static func kit_text(id: String) -> String:
	var kit: Dictionary = ALL[id].kit
	if kit.is_empty():
		return TranslationServer.translate("niente")
	var names: Array = []
	for slot: String in kit:
		var item: String = kit[slot]
		var name: String = Upgrades.SLOT_NAMES[slot] if item == Upgrades.BASE else Upgrades.CATALOG[item].name
		names.append(TranslationServer.translate(name).to_lower())
	return ", ".join(names)
