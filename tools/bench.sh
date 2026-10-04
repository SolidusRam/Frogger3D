#!/usr/bin/env bash
# Misura delle prestazioni, senza finestre (vedi tools/bench.gd).
# Uso: tools/bench.sh [SECONDI]   (60 di default)
# Per ogni scenario (corsa a calore 0, caos a calore 100, ingorgo di rottami)
# stampa quanto costa alla CPU un fotogramma (script e fisica, senza grafica);
# poi, su un display virtuale, le chiamate di disegno nel caos.
cd "$(dirname "$0")/.." || exit 1
seconds="${1:-60}"
for scenario in corsa caos ingorgo; do
	SCENARIO=$scenario SECONDS=$seconds timeout 900 godot --headless --fixed-fps 60 --path . -s tools/bench.gd 2>&1 | grep -E "^SCENARIO|^  |ERROR"
done
env -u WAYLAND_DISPLAY SCENARIO=caos SECONDS=20 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --display-driver x11 --rendering-driver opengl3 --path . --resolution 1280x720 \
	-s tools/bench.gd 2>&1 | grep -E "grafica|ERROR"
