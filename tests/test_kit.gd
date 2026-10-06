extends SceneTree
## Gli attrezzi iniziali: la rana comune parte coi soli guantoni (niente
## super salto, deltaplano né lingua, e niente molle sul modello). Le tane non
## offrono i numerici degli attrezzi che non ha; una carta di uno slot vuoto
## dà l'attrezzo (e la carta lo dice); una carta sopra l'attrezzo semplice lo
## sostituisce; senza attrezzi, nessun potere.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var hud: Node
var frog: Node
var upgrades: Node
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		2:
			var fresh: Node = load("res://scenes/main.tscn").instantiate()
			t.check(fresh.starting_kit == {"gloves": "base"}, "la rana comune parte coi soli guantoni")
			fresh.free()
			upgrades.equip_kit({"gloves": "base"})
			t.check(frog.punch_power.is_ready(), "coi guantoni il pugno c'è")
			t.check(not frog.super_jump_power.is_ready() and not frog.glider_power.enabled and not frog.tongue_power.enabled, "senza molle, ala e lingua: niente super salto, deltaplano né lingua")
			var spring: Node3D = frog.model.get_node("Torso/LegL/SpringL")
			t.check(not spring.visible and frog.model.get_node("GloveL").visible, "si vedono i guantoni, non le molle")
			# Le offerte: niente numerici per molle e ala.
			var offered := {}
			for i in 200:
				for id in upgrades.make_offer():
					offered[id] = true
			t.check(not offered.has("quick_springs") and not offered.has("big_wing"), "senza molle e ala non si offrono molle rapide né ala più grande")
			t.check(offered.has("punch_power") and offered.has("explosive_gloves"), "i guantoni semplici lasciano offrire le carte dei guantoni")
		4:
			t.check(hud._chips.punch.visible and not hud._chips.super_jump.visible and not hud._chips.glide.visible, "l'HUD mostra solo il pugno")
			# Una carta delle molle in uno slot vuoto: lo dice, e dà il super salto.
			var options: Array[String] = ["trampoline", "explosive_gloves"]
			hud.show_offer(options, upgrades)
			t.check(hud._card_parts[0].tag.text.contains("super salto"), "la carta di uno slot vuoto dice che dà un attrezzo nuovo (%s)" % hud._card_parts[0].tag.text)
			t.check(not hud._card_parts[1].tag.text.contains("Nuovo"), "sopra i guantoni semplici no")
			hud.hide_offer()
			upgrades.apply("trampoline")
			t.check(frog.super_jump_power.is_ready() and frog.model.get_node("Torso/LegL/SpringL").visible and frog.trampoline, "le molle-trampolino danno il super salto e le molle")
			upgrades.apply("explosive_gloves")
			t.check(upgrades.slots.gloves == "explosive_gloves" and frog.punch_power.explosive and frog.punch_power.enabled, "i guantoni esplosivi sostituiscono quelli semplici")
			var offered := {}
			for i in 100:
				for id in upgrades.make_offer():
					offered[id] = true
			t.check(not offered.has("uppercut") and offered.has("quick_springs"), "lo slot dei guantoni ora è chiuso; le molle rapide si offrono")
			# Nessun attrezzo.
			upgrades.equip_kit({})
			t.check(not frog.punch_power.is_ready() and not frog.super_jump_power.is_ready() and not frog.trampoline and not frog.punch_power.explosive, "senza attrezzi nessun potere")
			# Un attrezzo da carta all'inizio (la rana di fiume, il camaleonte).
			upgrades.equip_kit({"tongue": "tongue", "body": "waterproof"})
			t.check(frog.tongue_power.enabled and upgrades.slots.body == "waterproof" and not frog.punch_power.enabled, "si può partire con una carta come attrezzo")
		6:
			t.check(hud._chips.tongue.visible and not hud._chips.punch.visible, "l'HUD segue gli attrezzi")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
