class_name UiTheme
extends RefCounted
## Il tema unico dell'interfaccia: font, colori, pulsanti, pannelli e una
## scala di grandezze. Ogni schermata lo dà al suo nodo radice (theme =
## UiTheme.get_theme()) e poi sceglie le varianti per nome
## (theme_type_variation), senza ritoccare i nodi uno per uno.
##
## Direzione decisa il 4 ottobre 2026: gli attrezzi della rana sono il codice
## di colori (guantoni rossi, molle verdi, ala arancione, corpo verde acqua,
## lingua rosa); la segnaletica (giallo e nero) solo per avvisi e pericoli.
##
## Varianti:
##   Label:  Logo, Title, Header, Strong, Note, Money, HudLabel, HudBig
##   Button: PrimaryButton, DangerButton, FlatButton
##   PanelContainer: Backdrop (a tutto schermo, opaco)

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")

# --- Colori ------------------------------------------------------------------

## Fondo dei pannelli: un nero caldo, come la terra bruciata.
const INK := Color(0.075, 0.065, 0.055)
const INK_SOFT := Color(0.14, 0.12, 0.1)
const INK_LIGHT := Color(0.21, 0.18, 0.15)
const LINE := Color(0.32, 0.27, 0.21)
## Testo: crema, non bianco puro.
const TEXT := Color(0.97, 0.93, 0.84)
const TEXT_MUTED := Color(0.97, 0.93, 0.84, 0.62)
## L'oro delle mosche: valuta, selezione, cose da notare.
const GOLD := Color(1.0, 0.8, 0.24)
## Il verde della rana: l'azione principale.
const FROG := Color(0.33, 0.62, 0.22)
const FROG_DARK := Color(0.19, 0.4, 0.12)
## Il rosso del fuoco: pericolo e azioni che non si annullano.
const DANGER := Color(0.78, 0.22, 0.12)
const DANGER_DARK := Color(0.48, 0.12, 0.06)
## Riuscito (una prova superata).
const DONE := Color(0.55, 0.9, 0.45)

## Il codice di colori degli attrezzi, per slot (vedi Upgrades.SLOT_NAMES);
## "" per i potenziamenti numerici, "fusion" per le fusioni.
const SLOT_COLORS := {
	"gloves": Color(0.9, 0.26, 0.2),
	"springs": Color(0.36, 0.8, 0.38),
	"wing": Color(0.98, 0.56, 0.16),
	"body": Color(0.24, 0.72, 0.66),
	"tongue": Color(0.95, 0.5, 0.62),
	"fusion": GOLD,
	"": Color(0.56, 0.66, 0.82),
}

# --- Grandezze ---------------------------------------------------------------

const SIZE_NOTE := 15
const SIZE_BODY := 19
const SIZE_BUTTON := 24
const SIZE_HEADER := 30
const SIZE_TITLE := 44
const SIZE_LOGO := 88

static var _theme: Theme


## Il tema, costruito una volta sola e condiviso.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Il testo normale in grassetto (per numeri e nomi nell'HUD).
static func bold_font() -> Font:
	var font := FontVariation.new()
	font.base_font = BODY_FONT
	font.variation_opentype = {_weight_tag(): 800}
	return font


## Il Nunito è un font variabile: il peso si sceglie con l'asse "wght", che
## Godot vuole come codice numerico.
static func _weight_tag() -> int:
	return TextServerManager.get_primary_interface().name_to_tag("wght")


static func _build() -> Theme:
	var theme := Theme.new()
	var body := FontVariation.new()
	body.base_font = BODY_FONT
	body.variation_opentype = {_weight_tag(): 600}
	var bold := bold_font()
	theme.default_font = body
	theme.default_font_size = SIZE_BODY

	# Label e le sue varianti.
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", INK)
	_label_variation(theme, "Logo", DISPLAY_FONT, SIZE_LOGO, TEXT, 14)
	_label_variation(theme, "Title", DISPLAY_FONT, SIZE_TITLE, TEXT)
	_label_variation(theme, "Header", DISPLAY_FONT, SIZE_HEADER, TEXT)
	_label_variation(theme, "Note", body, SIZE_NOTE, TEXT_MUTED)
	_label_variation(theme, "Strong", bold, 20, TEXT)
	_label_variation(theme, "Money", DISPLAY_FONT, 26, GOLD)
	# Nell'HUD le scritte stanno sopra il mondo: bordo scuro per leggerle.
	_label_variation(theme, "HudLabel", bold, 18, TEXT, 6)
	_label_variation(theme, "HudBig", DISPLAY_FONT, 42, TEXT, 8)

	# Pulsanti: un tasto spesso, col bordo sotto più alto, che si abbassa
	# quando lo premi.
	theme.set_font("font", "Button", DISPLAY_FONT)
	theme.set_font_size("font_size", "Button", SIZE_BUTTON)
	_button_colors(theme, "Button", INK_SOFT, LINE)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	theme.set_color("font_outline_color", "Button", INK)
	theme.set_constant("outline_size", "Button", 0)
	theme.set_constant("h_separation", "Button", 10)
	# La selezione da tastiera: un contorno d'oro.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = GOLD
	focus.set_corner_radius_all(12)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	theme.set_stylebox("focus", "Button", focus)

	theme.set_type_variation("PrimaryButton", "Button")
	_button_colors(theme, "PrimaryButton", FROG, FROG_DARK)
	theme.set_color("font_hover_color", "PrimaryButton", TEXT)
	theme.set_color("font_pressed_color", "PrimaryButton", TEXT)
	theme.set_color("font_hover_pressed_color", "PrimaryButton", TEXT)
	theme.set_constant("outline_size", "PrimaryButton", 5)

	theme.set_type_variation("DangerButton", "Button")
	_button_colors(theme, "DangerButton", DANGER_DARK, Color(0.3, 0.07, 0.04))
	theme.set_color("font_hover_color", "DangerButton", TEXT)

	# Un pulsante senza fondo, per le azioni secondarie.
	theme.set_type_variation("FlatButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var flat := StyleBoxEmpty.new()
		flat.content_margin_left = 12
		flat.content_margin_right = 12
		flat.content_margin_top = 6
		flat.content_margin_bottom = 6
		theme.set_stylebox(state, "FlatButton", flat)
	theme.set_font_size("font_size", "FlatButton", 20)
	theme.set_color("font_color", "FlatButton", TEXT_MUTED)

	# Pannelli.
	var panel := _box(Color(INK, 0.95), LINE, 2, 14)
	panel.set_content_margin_all(24)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 14
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_type_variation("Backdrop", "PanelContainer")
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = INK
	backdrop.set_content_margin_all(32)
	theme.set_stylebox("panel", "Backdrop", backdrop)

	# Le schede (lo stagno).
	theme.set_font("font", "TabContainer", DISPLAY_FONT)
	theme.set_font_size("font_size", "TabContainer", 22)
	theme.set_color("font_selected_color", "TabContainer", GOLD)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_MUTED)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)
	var tab_selected := _box(INK_SOFT, GOLD, 0, 10)
	tab_selected.border_width_top = 3
	tab_selected.corner_radius_bottom_left = 0
	tab_selected.corner_radius_bottom_right = 0
	_margins(tab_selected, 20, 8)
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	var tab_other := StyleBoxFlat.new()
	tab_other.bg_color = Color(0, 0, 0, 0)
	_margins(tab_other, 20, 8)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_other)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_other)
	var tab_panel := _box(INK_SOFT, LINE, 0, 10)
	tab_panel.corner_radius_top_left = 0
	tab_panel.set_content_margin_all(16)
	theme.set_stylebox("panel", "TabContainer", tab_panel)
	theme.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())

	# Barre e barre di scorrimento.
	var bar_bg := _box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 6)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", _box(TEXT, Color(0, 0, 0, 0), 0, 6))
	theme.set_font("font", "ProgressBar", bold)
	var scroll := _box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 4)
	scroll.content_margin_left = 6
	theme.set_stylebox("scroll", "VScrollBar", scroll)
	theme.set_stylebox("grabber", "VScrollBar", _box(LINE, Color(0, 0, 0, 0), 0, 4))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(GOLD, Color(0, 0, 0, 0), 0, 4))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(GOLD, Color(0, 0, 0, 0), 0, 4))
	return theme


static func _label_variation(theme: Theme, name: String, font: Font, size: int, color: Color, outline := 0) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	theme.set_color("font_outline_color", name, Color(INK, 0.9))
	theme.set_constant("outline_size", name, outline)


## I quattro stati di un pulsante col colore dato: fondo e bordo sotto.
static func _button_colors(theme: Theme, type: String, color: Color, edge: Color) -> void:
	var normal := _key(color, edge, 5)
	var hover := _key(color.lightened(0.12), edge, 5)
	var pressed := _key(color.darkened(0.1), edge, 2)
	# Premuto, il tasto si abbassa: il testo scende quanto il bordo.
	pressed.content_margin_top += 3
	var disabled := _key(Color(color, 0.45), Color(edge, 0.45), 5)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)


static func _key(color: Color, edge: Color, depth: int) -> StyleBoxFlat:
	var box := _box(color, edge, 2, 10)
	box.border_width_bottom = depth
	_margins(box, 22, 10)
	box.content_margin_bottom = 10 + depth - 2
	return box


static func _box(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


static func _margins(box: StyleBox, horizontal: float, vertical: float) -> void:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
