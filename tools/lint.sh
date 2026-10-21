#!/usr/bin/env bash
# Lua-Lint wie in VS Code (Skript aus dem Skill): tools/lint.sh [UNTERORDNER]
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$MOD_DIR/docs/factorio-modding-skill/scripts/lint.sh" "$MOD_DIR" "${1:-}" 2>&1 | tr '\r' '\n' \
  | grep -E "\[Warning\]|\[Error\]|problems found|no problems"
