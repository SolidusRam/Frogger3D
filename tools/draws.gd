extends SceneTree
## Da dove vengono le chiamate di disegno, non fa parte del gioco. Gioca lo
## scenario "caos" di tools/bench.gd per qualche secondo, poi conta gli oggetti
## disegnabili dentro l'inquadratura, raggruppati per lo script (o la scena)
## a cui appartengono: istanze, superfici (ogni superficie è una chiamata) e
## quante di esse fanno ombra (ridisegnate per le ombre del sole).
## Uso: godot --headless --fixed-fps 60 --path . -s tools/draws.gd
## Con la grafica (stampa anche le chiamate vere, ombre comprese): tools/draws.sh
## OMBRE: 0 spente, 1 una fascia sola, corte una fascia fino a 35 m (per confrontare).
## LUCI: 0 spegne le luci puntiformi (incendio, portale).
## Y: altezza della rana (30, come tools/bench.gd; 1 = a terra).
## SECONDS: secondi simulati prima del conteggio (10).

const Lib := preload("res://tests/lib.gd")

var seconds := float(OS.get_environment("SECONDS")) if OS.get_environment("SECONDS") != "" else 10.0
var main: Node
var frog: Node3D
var frame := 0


func _initialize() -> void:
	main = Lib.load_main(self)
	frog = main.get_node("Frog")
	frog.invincible = true


func _process(_delta: float) -> bool:
	if paused:
		main.get_node("Upgrades").choose(0)
	if frame == 2:
		# OMBRE: 0 spente, 1 una fascia sola, altrimenti come in gioco.
		var sun: DirectionalLight3D = main.get_node("Sun")
		match OS.get_environment("OMBRE"):
			"0": sun.shadow_enabled = false
			"1": sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			"corte":
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 35.0
		root.get_node("Heat").running = false
		root.get_node("Heat").set_value(100.0)
	frog.global_position = Vector3(0, float(OS.get_environment("Y")) if OS.get_environment("Y") != "" else 30.0, -8.0 / 60.0 * frame)
	frog.velocity = Vector3.ZERO
	frame += 1
	# LUCI=0: le luci puntiformi spente (per confrontare), qualche fotogramma
	# prima del conteggio.
	if OS.get_environment("LUCI") == "0" and frame == int(seconds * 60.0) - 5:
		for light in root.find_children("*", "OmniLight3D", true, false):
			light.visible = false
	if frame >= int(seconds * 60.0):
		_report()
		quit()
	return false


func _report() -> void:
	var camera := root.get_viewport().get_camera_3d()
	var groups := {}
	var total := {"istanze": 0, "superfici": 0, "ombre": 0}
	var beyond := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		var surfaces := _surfaces(geo)
		if surfaces == 0:
			continue
		var box := geo.global_transform * geo.get_aabb()
		if not _in_view(camera, box):
			continue
		# La distanza di disegno (Style.FAR_DRAW), come la conta Godot.
		if camera and geo.visibility_range_end > 0.0 and camera.global_position.distance_to(box.get_center()) > geo.visibility_range_end:
			continue
		var key := _owner_name(geo)
		var far := camera.global_position.distance_to(box.get_center()) if camera else 0.0
		for limit in [60.0, 100.0, 150.0]:
			if far > limit:
				beyond[limit] = beyond.get(limit, 0) + surfaces
		var g: Dictionary = groups.get_or_add(key, {"istanze": 0, "superfici": 0, "ombre": 0})
		var shadow := surfaces if geo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
		for d in [g, total]:
			d.istanze += 1
			d.superfici += surfaces
			d.ombre += shadow
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a].superfici + groups[a].ombre > groups[b].superfici + groups[b].ombre)
	if Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) > 0:
		print("CHIAMATE DI DISEGNO (renderer vero, ombre comprese): %d, oggetti %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("IN VISTA: %d istanze, %d superfici, %d superfici che fanno ombra" % [total.istanze, total.superfici, total.ombre])
	for limit in beyond:
		print("  superfici a più di %d m dalla telecamera: %d" % [limit, beyond[limit]])
	if camera:
		print("  telecamera: far %.0f m" % camera.far)
	print("%-28s %8s %9s %7s" % ["da", "istanze", "superfici", "ombre"])
	for key in keys:
		var g: Dictionary = groups[key]
		print("%-28s %8d %9d %7d" % [key, g.istanze, g.superfici, g.ombre])


func _surfaces(geo: GeometryInstance3D) -> int:
	if geo is MeshInstance3D:
		return geo.mesh.get_surface_count() if geo.mesh else 0
	if geo is MultiMeshInstance3D:
		return geo.multimesh.mesh.get_surface_count() if geo.multimesh and geo.multimesh.mesh else 0
	if geo is CPUParticles3D:
		return 1 if geo.emitting or geo.mesh else 0
	return 1


func _in_view(camera: Camera3D, box: AABB) -> bool:
	if camera == null:
		return true
	for plane in camera.get_frustum():
		# Fuori se tutti gli angoli stanno dal lato esterno di un piano.
		var outside := true
		for i in 8:
			if not plane.is_point_over(box.get_endpoint(i)):
				outside = false
				break
		if outside:
			return false
	return true


## Lo script più vicino risalendo l'albero (o la scena da cui viene il nodo).
func _owner_name(node: Node) -> String:
	var n := node
	while n != null and n != root:
		if n.get_script() != null:
			return (n.get_script() as Script).resource_path.get_file()
		if n.scene_file_path != "":
			return n.scene_file_path.get_file()
		n = n.get_parent()
	return "?"
