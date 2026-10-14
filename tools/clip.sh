#!/usr/bin/env bash
# La clip del gioco (vedi tools/clip.gd): registra la scena fotogramma per
# fotogramma su un display virtuale, poi ne fa un MP4 e una GIF.
# Uso: tools/clip.sh CARTELLA_DI_USCITA [PRIMO_FOTOGRAMMA] [FOTOGRAMMI]
#   tools/clip.sh /tmp/clip            (la clip del README: seme 42, 7 secondi)
# Variabili (vedi tools/clip.gd): SEED (42), CALORE, YAW, PITCH, SECONDI, HUD.
# Per scegliere il pezzo migliore: guardare i fotogrammi in CARTELLA/frames.
cd "$(dirname "$0")/.." || exit 1
out="${1:?serve la cartella di uscita}"
first="${2:-126}"
count="${3:-210}"
mkdir -p "$out/frames"
rm -f "$out"/frames/*.png
SEED="${SEED:-42}" env -u WAYLAND_DISPLAY timeout 900 xvfb-run -a -s "-screen 0 960x540x24" \
	godot --display-driver x11 --rendering-driver opengl3 --path . --resolution 960x540 \
	--fixed-fps 30 --write-movie "$out/frames/f.png" -s tools/clip.gd 2>&1 | grep -E "CLIP|SCRIPT ERROR"
ffmpeg -loglevel error -y -framerate 30 -start_number "$first" -i "$out/frames/f%08d.png" -frames:v "$count" \
	-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$out/frogger-punch.mp4"
ffmpeg -loglevel error -y -framerate 30 -start_number "$first" -i "$out/frames/f%08d.png" -frames:v "$count" \
	-vf "fps=15,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
	"$out/frogger-punch.gif"
ls -la "$out"/frogger-punch.*
