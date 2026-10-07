extends SceneTree
## Il mercatino e le uova: venti oggetti da comprare (dieci cappelli e dieci
## colori), tre esposti che cambiano a ogni run, a prezzo per rarità; l'uovo
## dà un oggetto che manca, mai un doppione, finché ce ne sono. Quelli delle
## imprese non si comprano. Nella vetrina la rana prova l'oggetto.

const Lib := preload("res://tests/lib.gd")
const PROGRESS := "user://progressi_test.cfg"

var t := Lib.new()
var main: Node
var frog: Node
var cosmetics: GDScript
var market: GDScript
var progress: GDScript
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	cosmetics = load("res://scripts/cosmetics.gd")
	market = load("res://scripts/market.gd")
	progress = load("res://scripts/progress.gd")
	load("res://scripts/feats.gd").unlock_all = false


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			progress.flies = 3000
			var items: Array = cosmetics.shop_items()
			t.check(items.size() == 20, "venti oggetti fra cappelli e colori (%d)" % items.size())
			t.check(not items.any(func(item: Array) -> bool: return item[1] == "hard_hat"), "quelli delle imprese non si comprano")
			var stock: Array = market.stock()
			t.check(stock.size() == 3, "tre esposti")
			var first: String = stock[0][1]
			var flies: int = progress.flies
			t.check(market.buy(first) and progress.flies == flies - market.price(first), "comprato, al prezzo della sua rarità (%d)" % market.price(first))
			t.check(cosmetics.unlocked(first) and not market.buy(first), "ora è tuo, e non si ricompra")
			t.check(market.stock().size() == 2, "sul banco ne restano due")
			market.refresh()
			t.check(market.stock().size() == 3 and not market.stock().any(func(item: Array) -> bool: return progress.owned.has(item[1])), "a ogni run il banco cambia, solo cose che non hai")
			# Le uova: mai doppioni, finché ce ne sono.
			var seen := {}
			var doubles := false
			while market.egg_ready():
				var item: Array = market.hatch()
				doubles = doubles or seen.has(item[1])
				seen[item[1]] = true
			t.check(not doubles and cosmetics.missing_items().is_empty(), "l'uovo non dà doppioni, e alla fine c'è tutto (%d)" % seen.size())
			t.check(not market.egg_ready(), "senza niente da trovare l'uovo non si compra")
			# La vetrina: la rana prova il cappello.
			var pond: Node = load("res://scripts/pond.gd").new()
			root.add_child(pond)
			pond.showcase.target = frog
			pond._wear_preview("hat", "crown", "Corona", "Epico")
			t.check(frog.model.find_child("Head__hat", true, false) != null, "nella vetrina la rana prova la corona")
			t.check(pond._market_box.get_child_count() == 1, "con tutto trovato resta solo l'uovo (%d)" % pond._market_box.get_child_count())
			pond.queue_free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://record_test.cfg"))
			t.finish(self)
	return false
