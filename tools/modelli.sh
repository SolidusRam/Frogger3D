#!/usr/bin/env bash
# La griglia dei modelli del README: rende dodici modelli con Blender (Cycles
# su CPU, vedi tools/modelli.py), sfuma i bordi di ogni riquadro e li monta 4x3.
# Uso: tools/modelli.sh CARTELLA_DI_USCITA      (circa due minuti)
out="$(realpath -m "${1:?serve la cartella di uscita}")"
cd "$(dirname "$0")/.." || exit 1
mkdir -p "$out/tiles"
bg="#efeadf"
# nome:vernice (la vernice conta solo per i veicoli)
modelli="frog crocodile log glider sedan:car_0 truck:car_3 van:car_4 tug locomotive airplane house tree"
magick -size 640x640 radial-gradient:white-black -level 0%,30% "$out/mask.png"
tiles=()
for m in $modelli; do
	nome="${m%%:*}"
	vernice="${m#*:}"
	[ "$vernice" = "$m" ] && vernice=car_1
	PAINT="$vernice" blender -b "assets/models/$nome.blend" -t 6 --python tools/modelli.py -- "$out/tiles/$nome.png" 2>&1 | grep -E "Error|Traceback"
	magick "$out/tiles/$nome.png" \( +clone -alpha extract "$out/mask.png" -compose multiply -composite \) \
		-alpha off -compose copy_opacity -composite -background "$bg" -compose over -flatten -resize 360x360 "$out/tiles/$nome-sfumato.png"
	tiles+=("$out/tiles/$nome-sfumato.png")
done
magick montage "${tiles[@]}" -geometry +0+0 -tile 4x "$out/modelli.png"
magick "$out/modelli.png" -quality 82 "$out/modelli.webp"
ls -la "$out"/modelli.*
