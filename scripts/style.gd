extends Node
## Lo stile grafico (autoload "Style"). Tiene una tavolozza per stile e dà a
## tutto il gioco materiali condivisi: cambiare stile ricolora il mondo intero.
## Il calore sposta l'ora del giorno (giorno, tramonto, notte) come nel
## dinosauro di Google, con un lampo invertito a ogni nuovo livello.
## F2 passa allo stile successivo.

signal style_changed(style_name: String)

enum Post { NONE, PS1, ARCADE }

const CAR_COLORS := 6
## Ora del giorno per livello di calore: 0 giorno, 1 tramonto, 2 notte.
const PHASE_BY_LEVEL: Array[float] = [0.0, 0.0, 0.5, 1.0, 1.5, 2.0]
const PHASE_SPEED := 0.6
const POST_SHADER := preload("res://shaders/post.gdshader")

## Ogni stile: tavolozza dei materiali, tre fasi di luce e post-processing.
var styles: Array[Dictionary] = [
	{
		"name": "Base",
		"post": Post.NONE,
		"glow": false,
		"colors": {
			"grass": Color(0.35, 0.55, 0.3), "den_grass": Color(0.25, 0.45, 0.25),
			"sidewalk": Color(0.55, 0.55, 0.55), "asphalt": Color(0.18, 0.18, 0.2),
			"lane_line": Color(0.9, 0.9, 0.85), "water": Color(0.15, 0.4, 0.7, 0.75),
			"log": Color(0.45, 0.3, 0.15), "croc": Color(0.2, 0.4, 0.2),
			"croc_dark": Color(0.16, 0.32, 0.16), "croc_eye": Color(0.95, 0.85, 0.2),
			"frog": Color(0.3, 0.75, 0.25), "eye": Color(0.95, 0.95, 0.95),
			"pupil": Color(0.05, 0.05, 0.05), "gold": Color(0.95, 0.75, 0.2),
			"pad": Color(0.3, 0.7, 0.3), "glass": Color(0.1, 0.12, 0.15),
			"wing": Color(0.95, 0.5, 0.1), "glove": Color(0.85, 0.1, 0.1),
			"metal": Color(0.6, 0.6, 0.65), "smoke": Color(0.35, 0.35, 0.35),
			"spark": Color(1.0, 0.7, 0.2),
			"car_0": Color(0.85, 0.2, 0.2), "car_1": Color(0.95, 0.75, 0.15),
			"car_2": Color(0.2, 0.45, 0.85), "car_3": Color(0.9, 0.5, 0.15),
			"car_4": Color(0.6, 0.3, 0.75), "car_5": Color(0.9, 0.9, 0.9),
		},
		"phases": [
			{"sky_top": Color(0.35, 0.55, 0.85), "sky_horizon": Color(0.75, 0.82, 0.9), "ground": Color(0.4, 0.45, 0.35),
				"sun": Color(1.0, 0.97, 0.9), "sun_energy": 1.0, "sun_elevation": 60.0, "ambient": 1.0,
				"fog": Color(0.75, 0.82, 0.9), "fog_density": 0.0},
			{"sky_top": Color(0.3, 0.3, 0.55), "sky_horizon": Color(0.95, 0.5, 0.3), "ground": Color(0.35, 0.25, 0.2),
				"sun": Color(1.0, 0.6, 0.35), "sun_energy": 0.9, "sun_elevation": 12.0, "ambient": 0.7,
				"fog": Color(0.9, 0.5, 0.35), "fog_density": 0.004},
			{"sky_top": Color(0.02, 0.03, 0.1), "sky_horizon": Color(0.35, 0.08, 0.1), "ground": Color(0.05, 0.05, 0.08),
				"sun": Color(0.55, 0.65, 1.0), "sun_energy": 0.45, "sun_elevation": 40.0, "ambient": 0.35,
				"fog": Color(0.1, 0.04, 0.08), "fog_density": 0.008},
		],
	},
	{
		"name": "PS1",
		"post": Post.PS1,
		"glow": false,
		"colors": {
			"grass": Color(0.32, 0.42, 0.22), "den_grass": Color(0.24, 0.35, 0.2),
			"sidewalk": Color(0.42, 0.4, 0.38), "asphalt": Color(0.16, 0.15, 0.17),
			"lane_line": Color(0.8, 0.75, 0.55), "water": Color(0.12, 0.26, 0.36, 0.85),
			"log": Color(0.36, 0.24, 0.14), "croc": Color(0.22, 0.32, 0.16),
			"croc_dark": Color(0.17, 0.25, 0.12), "croc_eye": Color(0.85, 0.75, 0.2),
			"frog": Color(0.36, 0.62, 0.2), "eye": Color(0.85, 0.85, 0.8),
			"pupil": Color(0.05, 0.05, 0.05), "gold": Color(0.8, 0.6, 0.2),
			"pad": Color(0.28, 0.5, 0.22), "glass": Color(0.08, 0.1, 0.12),
			"wing": Color(0.8, 0.42, 0.12), "glove": Color(0.7, 0.12, 0.1),
			"metal": Color(0.5, 0.5, 0.52), "smoke": Color(0.3, 0.3, 0.3),
			"spark": Color(0.95, 0.65, 0.2),
			"car_0": Color(0.62, 0.16, 0.14), "car_1": Color(0.75, 0.6, 0.2),
			"car_2": Color(0.18, 0.3, 0.55), "car_3": Color(0.7, 0.4, 0.15),
			"car_4": Color(0.4, 0.25, 0.45), "car_5": Color(0.7, 0.7, 0.65),
		},
		"phases": [
			{"sky_top": Color(0.45, 0.55, 0.7), "sky_horizon": Color(0.7, 0.72, 0.72), "ground": Color(0.35, 0.35, 0.3),
				"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.0, "sun_elevation": 55.0, "ambient": 0.6,
				"fog": Color(0.66, 0.68, 0.7), "fog_density": 0.006},
			{"sky_top": Color(0.35, 0.25, 0.4), "sky_horizon": Color(0.8, 0.45, 0.3), "ground": Color(0.3, 0.2, 0.18),
				"sun": Color(1.0, 0.55, 0.3), "sun_energy": 0.85, "sun_elevation": 10.0, "ambient": 0.65,
				"fog": Color(0.6, 0.38, 0.3), "fog_density": 0.008},
			{"sky_top": Color(0.02, 0.02, 0.05), "sky_horizon": Color(0.15, 0.05, 0.06), "ground": Color(0.03, 0.03, 0.04),
				"sun": Color(0.5, 0.6, 0.9), "sun_energy": 0.4, "sun_elevation": 35.0, "ambient": 0.3,
				"fog": Color(0.05, 0.03, 0.05), "fog_density": 0.012},
		],
	},
	{
		"name": "Arcade",
		"post": Post.ARCADE,
		"glow": true,
		"emissive": ["frog", "glove", "lane_line", "gold", "croc_eye", "spark",
			"car_0", "car_1", "car_2", "car_3", "car_4", "car_5"],
		"emission_day": 0.15,
		"emission_night": 0.8,
		"colors": {
			"grass": Color(0.45, 0.12, 0.55), "den_grass": Color(0.1, 0.55, 0.2),
			"sidewalk": Color(0.45, 0.12, 0.55), "asphalt": Color(0.04, 0.03, 0.08),
			"lane_line": Color(1.0, 1.0, 0.3), "water": Color(0.0, 0.06, 0.4, 0.92),
			"log": Color(0.65, 0.35, 0.12), "croc": Color(0.1, 0.75, 0.2),
			"croc_dark": Color(0.05, 0.5, 0.12), "croc_eye": Color(1.0, 0.2, 0.2),
			"frog": Color(0.2, 1.0, 0.2), "eye": Color(1.0, 1.0, 0.3),
			"pupil": Color(0.0, 0.0, 0.0), "gold": Color(1.0, 0.85, 0.1),
			"pad": Color(0.1, 0.8, 0.3), "glass": Color(0.0, 0.0, 0.0),
			"wing": Color(1.0, 0.3, 0.6), "glove": Color(1.0, 0.1, 0.2),
			"metal": Color(0.8, 0.8, 0.9), "smoke": Color(0.4, 0.3, 0.5),
			"spark": Color(1.0, 0.9, 0.2),
			"car_0": Color(1.0, 0.2, 0.6), "car_1": Color(1.0, 0.95, 0.2),
			"car_2": Color(0.2, 0.9, 1.0), "car_3": Color(1.0, 1.0, 1.0),
			"car_4": Color(0.7, 0.3, 1.0), "car_5": Color(1.0, 0.5, 0.1),
		},
		"phases": [
			{"sky_top": Color(0.0, 0.0, 0.02), "sky_horizon": Color(0.05, 0.05, 0.2), "ground": Color(0.0, 0.0, 0.0),
				"sun": Color(1.0, 1.0, 1.0), "sun_energy": 0.9, "sun_elevation": 70.0, "ambient": 1.3,
				"fog": Color(0.0, 0.0, 0.05), "fog_density": 0.006},
			{"sky_top": Color(0.05, 0.0, 0.1), "sky_horizon": Color(0.4, 0.0, 0.4), "ground": Color(0.0, 0.0, 0.0),
				"sun": Color(1.0, 0.85, 1.0), "sun_energy": 0.9, "sun_elevation": 50.0, "ambient": 1.1,
				"fog": Color(0.12, 0.0, 0.15), "fog_density": 0.008},
			{"sky_top": Color(0.1, 0.0, 0.0), "sky_horizon": Color(0.7, 0.05, 0.05), "ground": Color(0.0, 0.0, 0.0),
				"sun": Color(1.0, 0.85, 0.85), "sun_energy": 0.8, "sun_elevation": 40.0, "ambient": 0.9,
				"fog": Color(0.25, 0.0, 0.02), "fog_density": 0.006},
		],
	},
]

var current := 0
## Ora del giorno, da 0 (giorno) a 2 (notte); segue il calore.
var phase := 0.0

var _materials := {}
var _environment: Environment
var _sun: DirectionalLight3D
var _post: ColorRect
var _post_material := ShaderMaterial.new()
var _last_level := 0


func _ready() -> void:
	_post_material.shader = POST_SHADER
	_post_material.set_shader_parameter("flash", 0.0)
	Heat.changed.connect(_on_heat_changed)
	_apply_colors()


func _process(delta: float) -> void:
	var target := PHASE_BY_LEVEL[Heat.level()]
	if phase != target:
		phase = move_toward(phase, target, PHASE_SPEED * delta)
		_apply_light()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("style_next"):
		set_style((current + 1) % styles.size())


## Collega la scena: ambiente, sole e rettangolo del post-processing.
func bind(environment: Environment, sun: DirectionalLight3D, post: ColorRect) -> void:
	_environment = environment
	_sun = sun
	_post = post
	_post.material = _post_material
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase = PHASE_BY_LEVEL[Heat.level()]
	_last_level = Heat.level()
	set_style(current)


func set_style(index: int) -> void:
	current = index
	_apply_colors()
	_apply_light()
	_apply_post()
	style_changed.emit(style_name())


func style_name() -> String:
	return styles[current].name


## Materiale condiviso per una voce della tavolozza ("grass", "car_3"...).
## Le varianti "wreck_N" sono le auto annerite dei rottami.
func material(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		_materials[key] = mat
		_color_material(key, mat)
	return _materials[key]


func _color_material(key: String, mat: StandardMaterial3D) -> void:
	var colors: Dictionary = styles[current].colors
	var color: Color
	if key.begins_with("wreck_"):
		color = (colors["car_" + key.trim_prefix("wreck_")] as Color).darkened(0.5)
	else:
		color = colors.get(key, Color.MAGENTA)
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.emission_enabled = _is_emissive(key)
	mat.emission = Color(color, 1.0)


## Nelle tavolozze che lo prevedono, minacce e rana brillano di luce propria,
## sempre di più man mano che scende la notte.
func _is_emissive(key: String) -> bool:
	return key in styles[current].get("emissive", [])


func _apply_colors() -> void:
	for key in _materials:
		_color_material(key, _materials[key])


func _apply_light() -> void:
	if _environment == null:
		return
	var phases: Array = styles[current].phases
	var low := mini(floori(phase), phases.size() - 2)
	var t := phase - low
	var a: Dictionary = phases[low]
	var b: Dictionary = phases[low + 1]

	var sky := _environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = (a.sky_top as Color).lerp(b.sky_top, t)
	sky.sky_horizon_color = (a.sky_horizon as Color).lerp(b.sky_horizon, t)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = (a.ground as Color).lerp(b.ground, t)
	_environment.ambient_light_energy = lerpf(a.ambient, b.ambient, t)
	_environment.fog_light_color = (a.fog as Color).lerp(b.fog, t)
	_environment.fog_density = lerpf(a.fog_density, b.fog_density, t)
	_environment.fog_enabled = _environment.fog_density > 0.0

	var night := phase / 2.0
	var emission := lerpf(styles[current].get("emission_day", 0.0), styles[current].get("emission_night", 0.0), night)
	for key in _materials:
		if _is_emissive(key):
			(_materials[key] as StandardMaterial3D).emission_energy_multiplier = emission

	_sun.light_color = (a.sun as Color).lerp(b.sun, t)
	_sun.light_energy = lerpf(a.sun_energy, b.sun_energy, t)
	_sun.rotation = Vector3(-deg_to_rad(lerpf(a.sun_elevation, b.sun_elevation, t)), deg_to_rad(30.0), 0.0)


func _apply_post() -> void:
	if _post == null:
		return
	var post: Post = styles[current].post
	_post_material.set_shader_parameter("mode", post)
	_post.visible = post != Post.NONE or float(_post_material.get_shader_parameter("flash")) > 0.0
	_environment.glow_enabled = styles[current].glow


## A ogni nuovo livello di calore lo schermo si inverte per un istante, come
## il dinosauro di Google quando passa dal giorno alla notte.
func _on_heat_changed(_value: float, level: int) -> void:
	if level > _last_level and _post != null:
		_post.visible = true
		var tween := create_tween()
		tween.tween_method(_set_flash, 1.0, 0.0, 0.35)
		tween.tween_callback(_apply_post)
	_last_level = level


func _set_flash(value: float) -> void:
	_post_material.set_shader_parameter("flash", value)
