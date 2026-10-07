extends SceneTree
## Gli attrezzi in due passi: per uno slot vuoto esce l'attrezzo semplice,
## non le sue modifiche; avuto l'attrezzo, escono le modifiche, che lo
## sostituiscono; il corpo resta in un passo. La spinta: finché c'è uno slot
## vuoto, ogni offerta ha almeno un attrezzo nuovo.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node
var upgrades: Node
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")


func _offered(times: int) -> Dictionary:
	var offered := {}
	for i in times:
		for id in upgrades.make_offer():
			offered[id] = true
	return offered


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			# La rana comune: solo i guantoni.
			upgrades.equip_kit({"gloves": "base"})
			var offered := _offered(300)
			t.check(offered.has("tool_wing") and offered.has("tool_springs") and offered.has("tongue"), "per gli slot vuoti escono ala, molle e lingua semplici")
			t.check(not offered.has("jet_wing") and not offered.has("trampoline") and not offered.has("catapult_tongue"), "le loro modifiche no, finché non c'è l'attrezzo")
			t.check(offered.has("explosive_gloves") and not offered.has("tool_gloves"), "sopra i guantoni semplici escono le modifiche dei guantoni")
			t.check(offered.has("waterproof"), "il corpo resta in un passo")
			# La spinta: ogni offerta ha un attrezzo nuovo.
			var always := true
			for i in 200:
				var offer: Array = upgrades.make_offer()
				if not offer.any(func(id: String) -> bool: return upgrades.CATALOG[id].get("tool", false)):
					always = false
			t.check(always, "finché c'è uno slot vuoto, ogni offerta ha un attrezzo nuovo")
			# L'ala semplice, poi le sue modifiche.
			upgrades.apply("tool_wing")
			t.check(upgrades.slots.wing == "base" and frog.glider_power.enabled and not frog.glider_power.jet, "la carta Ala dà il deltaplano semplice")
			offered = _offered(300)
			t.check(offered.has("jet_wing") and not offered.has("tool_wing"), "con l'ala, escono le sue modifiche")
			upgrades.apply("jet_wing")
			t.check(upgrades.slots.wing == "jet_wing" and frog.glider_power.jet, "l'ala a reazione sostituisce quella semplice")
			t.check(not _offered(300).has("thermals"), "una modifica chiude lo slot")
			# La lingua: il rampino è l'attrezzo, la catapulta lo sostituisce.
			upgrades.apply("tongue")
			t.check(_offered(300).has("catapult_tongue"), "col rampino escono le altre lingue")
			upgrades.apply("catapult_tongue")
			t.check(upgrades.slots.tongue == "catapult_tongue" and frog.tongue_power.catapult and frog.tongue_power.enabled, "la catapulta sostituisce il rampino")
			# Tutti gli slot pieni: niente spinta, nessun attrezzo semplice.
			upgrades.apply("tool_springs")
			upgrades.apply("waterproof")
			t.check(not _offered(100).keys().any(func(id: String) -> bool: return upgrades.CATALOG[id].get("tool", false)), "con tutti gli attrezzi, niente più attrezzi semplici")
			t.finish(self)
	return false
