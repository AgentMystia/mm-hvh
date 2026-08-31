#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT:-/home/ubuntu/godot/Godot_v4.7.2-stable_linux.x86_64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/export/web"
"$GODOT" --headless --path "$ROOT" --export-release Web "$ROOT/export/web/index.html"
python3 "$ROOT/tools/patch_web_html.py"
echo "web export ready: $ROOT/export/web"
