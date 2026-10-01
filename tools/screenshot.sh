#!/usr/bin/env bash
# Screenshot del gioco senza aprire finestre: Godot disegna in un display
# virtuale (Xvfb) col renderer di compatibilità, più slavato del gioco vero.
# Uso:  tools/screenshot.sh SCRIPT SCENA CALORE FILE.png
#   tools/screenshot.sh shot_biome aereo 0 /tmp/aereo.png
#   tools/screenshot.sh shot_biome porto 100 /tmp/porto_notte.png
#   tools/screenshot.sh shot_rail passaggio 0 /tmp/treno.png
# Scene: shot_biome = aereo | getto | gru | caduta | porto;
#        shot_rail  = arrivo | passaggio | tetto.
# WAYLAND_DISPLAY va tolto: se il display virtuale fallisse, Godot aprirebbe
# la finestra sul vero schermo.
cd "$(dirname "$0")/.." || exit 1
env -u WAYLAND_DISPLAY SCENE="$2" HEAT="$3" SHOT="$4" timeout 150 \
	xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --display-driver x11 --rendering-driver opengl3 --path . --resolution 1280x720 \
	-s "tools/$1.gd" 2>&1 | grep -E "salvato|SCRIPT ERROR|niente"
