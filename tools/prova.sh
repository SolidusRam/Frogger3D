#!/usr/bin/env bash
# Avvia il gioco in modalità prova, già nel bioma e al calore voluti.
# Uso:  tools/prova.sh [opzioni]
#   tools/prova.sh --bioma=aeroporto --calore=3 --invincibile
#   tools/prova.sh --bioma=fiume --calore=3 --blocca-calore --poteri
#   tools/prova.sh --bioma=strada --power=tongue,earthquake
# Opzioni: --bioma=strada|fiume|ferrovia|aeroporto|porto|tana
#          --calore=0..5  --blocca-calore  --invincibile  --poteri  --senza-fuoco
#          --power=tongue,slam,napalm   (id in scripts/upgrades.gd, CATALOG)
#          --attrezzi   (la rana parte coi soli guantoni: dà anche molle e ala)
#          --mondo=cielo   (teletrasporto fino a quel mondo)
# In gioco F1 apre lo stesso pannello. Una run di prova non salva il record.
cd "$(dirname "$0")/.." || exit 1
exec godot --path . -- "$@"
