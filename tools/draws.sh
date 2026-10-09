#!/usr/bin/env bash
# Le chiamate di disegno nel caos e da dove vengono (vedi tools/draws.gd), col
# renderer vero su un display virtuale. Uso: tools/draws.sh [ALTEZZA_RANA]
# (1 = a terra, come in gioco; 30 = dall'alto, si vede tutto il percorso).
cd "$(dirname "$0")/.." || exit 1
env -u WAYLAND_DISPLAY Y="${1:-1}" SECONDS="${SECONDS_SIM:-10}" timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --display-driver x11 --rendering-driver opengl3 --path . --resolution 1280x720 \
	-s tools/draws.gd 2>&1 | grep -vE "^Godot|^OpenGL|^$|WARNING|at:"
