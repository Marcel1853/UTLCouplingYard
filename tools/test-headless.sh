#!/usr/bin/env bash
# Headless-Probe ohne Fenster (eigener Datenordner, berührt Marcels Spiel nicht): UTL aus dem Mod-Ordner,
# flib, dieser Mod. Lädt ein Szenario als Server und läuft $2 Sekunden.
# Aufruf: tools/test-headless.sh [SZENARIO] [SEKUNDEN]   Standard: UTLogistics/UTL-Beispiele, 120
# Ausgabe: Zeilen mit [UCY], [UTL] und Fehler aus dem Log.
set -uo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODS="$(cd "$MOD_DIR/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
SCENARIO="${1:-UTLogistics/UTL-Beispiele}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT
mkdir -p "$WORK/mods" "$WORK/data"
ln -s "$MOD_DIR" "$WORK/mods/UTLCouplingYard"
ln -s "$MODS/UTLogistics" "$WORK/mods/UTLogistics"
for dep in "$MODS"/flib_*.zip; do ln -s "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
# SELFTEST=1: Selbsttest-Mod dazu (baut eigene Strecken und prüft An-/Abkuppeln), z. B.
#   SELFTEST=1 tools/test-headless.sh base/freeplay 200
[ -n "${SELFTEST:-}" ] && ln -s "$MOD_DIR/tools/selftest/ucy-selftest_0.0.1" "$WORK/mods/ucy-selftest"
# MAPDUMP=1: Kartenauszug alle 30 s bis Minute 6 in $WORK/data/script-output/ (Bilder: tools/render-map.py)
[ -n "${MAPDUMP:-}" ] && ln -s "$MOD_DIR/tools/mapdump/ucy-mapdump_0.0.1" "$WORK/mods/ucy-mapdump"
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"
cat > "$WORK/server.json" <<'JSON'
{ "name": "ucy", "description": "", "tags": [], "max_players": 2, "visibility": { "public": false, "lan": false },
  "username": "", "password": "", "token": "", "game_password": "", "require_user_verification": false,
  "auto_pause": false, "autosave_interval": 0, "autosave_slots": 1 }
JSON
timeout "${2:-120}" "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" \
  --start-server-load-scenario "$SCENARIO" --server-settings "$WORK/server.json" > "$WORK/run.log" 2>&1
grep -E "\[UCY\]|\[UTL\]|Error|error while" "$WORK/data/factorio-current.log" | sed 's/^ *[0-9.]* //' | head -80
