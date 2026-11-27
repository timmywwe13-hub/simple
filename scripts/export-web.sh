#!/usr/bin/env bash
# Rebuild the playable browser build in build/web/.
#
# The committed build/web folder is what every host serves:
#   * GitHub Pages -> https://timmywwe13-hub.github.io/simple/build/web/
#   * Surge        -> https://cottage-creek-fishing-v110.surge.sh/ (and 3 mirrors)
#   * Netlify      -> publish directory "build/web" (see netlify.toml)
#
# Usage:
#   ./scripts/export-web.sh
#   GODOT=/path/to/godot ./scripts/export-web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "error: '$GODOT' was not found." >&2
	echo "Install Godot 4.7.x with the Web export templates, or run:" >&2
	echo "  GODOT=/path/to/godot ./scripts/export-web.sh" >&2
	exit 1
fi

if [ ! -f fishing.svg ]; then
	echo "error: fishing.svg is missing (it is the favicon copied into the build)." >&2
	exit 1
fi

mkdir -p build/web
"$GODOT" --headless --path . --export-release Web build/web/index.html

# Force a newly deployed worker to take over from an older cached build.
# This needs Python, but a missing interpreter is only a warning: the game
# build itself is already complete.
PYTHON=""
if command -v python3 >/dev/null 2>&1; then
	PYTHON=python3
elif command -v python >/dev/null 2>&1; then
	PYTHON=python
fi
if [ -n "$PYTHON" ]; then
	"$PYTHON" scripts/patch_web_build.py
else
	echo "warning: python not found; skipping the stale-PWA cache patch." >&2
fi

# export_presets.cfg references fishing.svg in the HTML head, but the exporter
# does not place the SVG next to the exported page, so copy it in.
cp fishing.svg build/web/fishing.svg

# Netlify reads build/web/_headers (cache + nosniff rules). Keep it if the
# exporter ever cleans the folder.
if [ ! -f build/web/_headers ]; then
	cat >build/web/_headers <<'HEADERS'
/*
  X-Content-Type-Options: nosniff

/*.wasm
  Cache-Control: no-cache

/*.pck
  Cache-Control: no-cache

/*.js
  Cache-Control: no-cache

/index.html
  Cache-Control: no-cache
HEADERS
fi

echo
echo "web build ready: build/web/ ($(du -sh build/web | cut -f1))"
echo "GitHub Pages: https://timmywwe13-hub.github.io/simple/build/web/"
echo "Surge:        https://cottage-creek-fishing-v110.surge.sh/"
echo "              https://cottage-creek-v110.surge.sh/"
echo "              https://cottagecreek-v110.surge.sh/"
echo "              https://creekfishing-v110.surge.sh/"
echo "Netlify:      npx netlify-cli deploy --dir=build/web --prod"
