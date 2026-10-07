class_name Showcase
extends PanelContainer
## La vetrina: una finestrella nei menu a tutto schermo (lo stagno, le rane,
## le imprese) che riprende la rana vera del mondo con una seconda
## telecamera, davanti a lei. Così si vede tutto quello che la rana ha già:
## aspetto, cappello, colore, silhouette, e le dimostrazioni degli attrezzi
## (Frog.demo). Sotto, il nome e un dettaglio. Senza una rana (la fine della
## corsa) la vetrina non si vede.

## Dove sta la telecamera rispetto alla rana: davanti (verso -Z, dove la
## rana guarda quando la vetrina la gira), un po' in alto.
const EYE := Vector3(0.5, 1.05, -2.3)
const LOOK_AT := Vector3(0.0, 0.5, 0.0)
const VIEW_SIZE := Vector2i(300, 150)

## La rana da riprendere (null: niente vetrina).
var target: Node3D:
	set(value):
		target = value
		visible = value != null
		if value and _viewport:
			_viewport.world_3d = value.get_world_3d()

var _viewport: SubViewport
var _camera: Camera3D
var _title: Label
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.box(Color(0, 0, 0, 0.35), UiTheme.GOLD, 2, 12)
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(VIEW_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	_viewport.add_child(_camera)
	_title = Label.new()
	_title.theme_type_variation = "Header"
	_title.add_theme_font_size_override("font_size", 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_detail = Label.new()
	_detail.theme_type_variation = "Note"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = VIEW_SIZE.x
	column.add_child(_detail)
	visible = target != null
	if target:
		_viewport.world_3d = target.get_world_3d()


## Il nome e il dettaglio sotto la rana.
func caption(title: String, detail := "") -> void:
	_title.text = title
	_detail.text = detail


## La rana guarda la vetrina (prima di una dimostrazione).
func face_target() -> void:
	if target and target.has_method("demo"):
		target.visual.rotation.y = 0.0


func _process(_delta: float) -> void:
	if not visible or target == null or not is_instance_valid(target):
		return
	var center := target.global_position
	_camera.global_position = center + EYE
	_camera.look_at(center + LOOK_AT, Vector3.UP)
