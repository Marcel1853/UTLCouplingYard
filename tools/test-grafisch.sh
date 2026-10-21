#!/usr/bin/env bash
# Grafischer Test (öffnet ein Factorio-Fenster; Steam fragt nach einer Freigabe). Eigener Datenordner
# ~/.cache/ucy-test, Marcels Spiel- und Mod-Einstellungen, Creative Mod, UTL aus dem Mod-Ordner, dieser Mod.
# VORHER fragen, ob Marcel gerade Factorio spielt – nie parallel zu seinem Spiel starten.
# Aufruf: tools/test-grafisch.sh [SZENARIO]   Standard: UTLogistics/UTL-Beispiele
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODS="$(cd "$MOD_DIR/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="$HOME/.cache/ucy-test"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLCouplingYard"
ln -sfn "$MODS/UTLogistics" "$WORK/mods/UTLogistics"
for dep in "$MODS"/flib_*.zip "$MODS"/creative-mod_*.zip; do ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
sed -e "s|^read-data=.*|read-data=__PATH__executable__/../../data|" -e "s|^write-data=.*|write-data=$WORK/data|" \
  "$HOME/.factorio/config/config.ini" > "$WORK/config.ini"
cp "$MODS/mod-settings.dat" "$WORK/mods/mod-settings.dat"
rm -f "$WORK/data/factorio-current.log"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "${1:-UTLogistics/UTL-Beispiele}" \
  > "$WORK/run.log" 2>&1 || true
