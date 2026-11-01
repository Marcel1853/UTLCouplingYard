#!/usr/bin/env bash
# Prüft die Tipps-&-Tricks-Szenen headless: je Szene eine Welt, Szenen-Code ausführen, kurz laufen lassen und die
# Züge ins Log schreiben (eigener Datenordner, berührt Marcels Spiel nicht).
# Aufruf: tools/tipstest.sh   oder   SCENES="attach" TICKS=2900 tools/tipstest.sh
set -uo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODS="$(cd "$MOD_DIR/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
for scene in ${SCENES:-drop pickup shunt attach}; do
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/mods" "$WORK/data"
  ln -s "$MOD_DIR" "$WORK/mods/UTLCouplingYard"
  ln -s "$MODS/UTLogistics" "$WORK/mods/UTLogistics"
  for dep in "$MODS"/flib_*.zip; do ln -s "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
  cp -r "$MOD_DIR/tools/tipstest/ucy-tipstest_0.0.1" "$WORK/mods/"
  echo "return \"$scene\"" > "$WORK/mods/ucy-tipstest_0.0.1/scene.lua"
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"
  "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/t.zip" > /dev/null
  "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/t.zip" --benchmark-ticks "${TICKS:-1450}" > /dev/null || true
  grep -o "\[TIPS\].*" "$WORK/data/factorio-current.log"
  grep -A6 "Error while\|Error" "$WORK/data/factorio-current.log" | head -8
  [ -n "${KEEP:-}" ] || rm -rf "$WORK"
done
