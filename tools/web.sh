#!/usr/bin/env bash
# La build per il browser, in build/web (index.html e i suoi file): è quella
# da caricare sul sito, così com'è. Senza thread, quindi va su qualsiasi
# hosting statico, senza intestazioni speciali.
# Uso:  tools/web.sh            esporta
#       tools/web.sh --apri     esporta e la serve su http://localhost:8765
# Serve una volta i template web di Godot (web_nothreads_*.zip) in
# ~/.local/share/godot/export_templates/<versione>.stable/.
cd "$(dirname "$0")/.." || exit 1
rm -rf build/web
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "ERROR|SCRIPT ERROR"
[ -f build/web/index.html ] || { echo "export fallito"; exit 1; }
du -sh build/web | sed 's/\t.*/ in build\/web/'
if [ "$1" = "--apri" ]; then
	echo "http://localhost:8765  (Ctrl+C per fermare)"
	exec python3 -m http.server 8765 --directory build/web
fi
