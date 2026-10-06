extends SceneTree
## I gettoni della tana: Rilancia rifà le carte, Esilia toglie dal mazzo la
## carta scelta per il resto della run, Salta chiude le carte e dà mosche.
## Due usi ciascuno per run; senza la loro impresa non si vedono.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var hud: Node
var upgrades: Node
var frame := 0
var m := {}


func _initialize() -> void:
	main = Lib.load_main(self)
	hud = main.get_node("Hud")
	upgrades = main.get_node("Upgrades")


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			t.check(upgrades.tokens == {"reroll": 2, "skip": 2, "banish": 2}, "due usi per gettone (%s)" % upgrades.tokens)
			main.offer_upgrade()
			t.check(paused and hud._token_buttons.reroll.visible and hud._token_buttons.reroll.text == "Rilancia (2)", "sotto le carte i gettoni, con gli usi (%s)" % hud._token_buttons.reroll.text)
			# Rilancia.
			hud._on_token("reroll")
			t.check(upgrades.tokens.reroll == 1 and hud.is_offer_open() and paused, "Rilancia: carte nuove, un uso in meno")
			# Esilia la prima carta.
			m.banished = upgrades.current_offer[0]
			hud._on_token("banish")
			t.check(hud._banishing and hud._offer_hint.text.contains("Esilia"), "Esilia aspetta la carta")
			hud._on_card_pressed(0)
			t.check(not hud._banishing and upgrades.banished.has(m.banished) and upgrades.tokens.banish == 1, "la carta scelta è esiliata (%s)" % m.banished)
			var seen := false
			for i in 100:
				if upgrades.make_offer().has(m.banished):
					seen = true
			t.check(not seen, "una carta esiliata non esce più nella run")
			# Salta.
			main.offer_upgrade()
			var flies: int = main.run_flies
			hud._on_token("skip")
			t.check(not hud.is_offer_open() and not paused and main.run_flies == flies + main.skip_flies, "Salta: niente carta, %d mosche, si riparte" % main.skip_flies)
			# Senza le imprese i gettoni non ci sono.
			load("res://scripts/feats.gd").unlock_all = false
			upgrades.reset_tokens()
			main.offer_upgrade()
			t.check(upgrades.tokens.reroll == 0 and not hud._token_buttons.reroll.visible, "senza la sua impresa il gettone non si vede")
			t.check(upgrades.banished.is_empty(), "una run nuova riparte senza esiliate")
			t.finish(self)
	return false
