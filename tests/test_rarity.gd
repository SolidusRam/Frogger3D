extends SceneTree
## La rarità delle carte: le modifiche possono uscire rare (un miglioramento
## di maestria per la run) o epiche (tutti quelli che mancano); attrezzi
## semplici e numerici sempre comuni, le fusioni leggendarie. Scelta una rara,
## il miglioramento vale subito. Con la maestria completa la rarità dà vita e
## mosche. Siccità e Occhio fino alzano la fortuna.

const Lib := preload("res://tests/lib.gd")

var t := Lib.new()
var main: Node
var frog: Node
var upgrades: Node
var progress: GDScript
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	upgrades = main.get_node("Upgrades")
	progress = load("res://scripts/progress.gd")


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			# Quante rare ed epiche escono: circa il 20% e il 5%.
			var counts := {"common": 0, "rare": 0, "epic": 0}
			var tools_common := true
			for i in 400:
				upgrades.make_offer()
				for index in upgrades.current_offer.size():
					var id: String = upgrades.current_offer[index]
					var level: String = upgrades.current_rarity[index].rarity
					if upgrades.CATALOG[id].get("tool", false) or upgrades.CATALOG[id].slot == "":
						tools_common = tools_common and level == "common"
					elif counts.has(level):
						counts[level] += 1
			var total: int = counts.common + counts.rare + counts.epic
			t.check(tools_common, "attrezzi semplici e numerici sono sempre comuni")
			t.check(absf(float(counts.rare) / total - 0.2) < 0.05 and absf(float(counts.epic) / total - 0.05) < 0.03, "rare circa 20%%, epiche circa 5%% (%d, %d su %d)" % [counts.rare, counts.epic, total])
			# Una rara scelta: il suo miglioramento vale subito.
			upgrades.equip_kit({"gloves": "base", "springs": "base", "wing": "base"})
			upgrades.current_offer.assign(["explosive_gloves", "uppercut", "tool_wing"])
			upgrades.current_rarity.assign([{"rarity": "rare", "upgrades": [0], "bonus": false}, {"rarity": "common", "upgrades": [], "bonus": false}, {"rarity": "common", "upgrades": [], "bonus": false}])
			upgrades.choose(0)
			var car: GDScript = load("res://scripts/car.gd")
			t.check(frog.punch_power.explosive and car.chain_explosions and not car.explosion_rocket, "guantoni esplosivi rari: la reazione a catena c'è subito, il razzo no")
			t.check(not progress.upgrade_active("explosive_gloves", 0), "solo per questa run: allo stagno non è attiva")
			# Un'epica: tutti e due.
			upgrades.current_offer.assign(["trampoline"])
			upgrades.current_rarity.assign([{"rarity": "epic", "upgrades": [0, 1], "bonus": false}])
			upgrades.choose(0)
			t.check(frog.trampoline_crescendo and frog.trampoline_wrecks, "le molle-trampolino epiche hanno tutti e due i miglioramenti")
			# Maestria completa: la rarità dà vita e mosche.
			progress.card_active["thermals:0"] = true
			progress.card_active["thermals:1"] = true
			var rarity: Dictionary = {}
			for i in 2000:
				rarity = upgrades._roll_rarity("thermals")
				if rarity.rarity != "common":
					break
			t.check(rarity.bonus and rarity.upgrades.is_empty(), "con la maestria completa, la rarità dà vita e mosche")
			frog.health = 10
			var flies: int = main.run_flies
			upgrades.current_offer.assign(["thermals"])
			upgrades.current_rarity.assign([rarity])
			upgrades.choose(0)
			main.get_node("Hud").hide_offer()
			paused = false
			t.check(frog.health > 10 and main.run_flies > flies, "vita e mosche arrivano (vita %d, mosche +%d)" % [frog.health, main.run_flies - flies])
			# Le fusioni sono leggendarie.
			t.check(upgrades._roll_rarity("napalm").rarity == "legendary", "le fusioni sono leggendarie")
			# La fortuna: Siccità e Occhio fino.
			upgrades.update_luck(3, 5)
			t.check(is_equal_approx(upgrades.rare_chance, 0.2 + 0.12 + 0.15) and is_equal_approx(upgrades.epic_chance, 0.05 + 0.045 + 0.05), "Occhio fino 3 e Siccità 5 alzano le probabilità (%.2f, %.3f)" % [upgrades.rare_chance, upgrades.epic_chance])
			t.check(progress.STATS.has("eye"), "Occhio fino si compra allo stagno")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progressi_test.cfg"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
