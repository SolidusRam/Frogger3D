#!/usr/bin/env bash
# Le build da scaricare, per Linux e Windows, in build/: un eseguibile solo
# (i dati sono dentro) e uno zip per la Release di GitHub, con le licenze.
# Uso: tools/build.sh [VERSIONE]   (es. tools/build.sh 0.1)
# Servono una volta i template di Godot (linux_release.x86_64 e
# windows_release_x86_64.exe) in ~/.local/share/godot/export_templates/<versione>.stable/.
cd "$(dirname "$0")/.." || exit 1
version="${1:-dev}"
rm -rf build
for target in linux windows; do
	preset=$([ $target = linux ] && echo Linux || echo Windows)
	file=$([ $target = linux ] && echo Frogger3D.x86_64 || echo Frogger3D.exe)
	mkdir -p "build/$target"
	godot --headless --path . --export-release "$preset" "build/$target/$file" 2>&1 | grep -E "ERROR|SCRIPT ERROR"
	[ -f "build/$target/$file" ] || { echo "export $preset fallito"; exit 1; }
	cp LICENSE LICENSE-ASSETS.md "build/$target/"
	cp assets/fonts/OFL-*.txt "build/$target/"
	(cd build && zip -qr "Frogger3D-$version-$target.zip" "$target")
done
ls -la build/*.zip
