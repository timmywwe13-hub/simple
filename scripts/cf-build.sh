#!/usr/bin/env bash
# Assemble the Cloudflare Workers static-assets folder (`dist/`) from the Godot
# web export in `build/web/`.
#
# Why this exists: Cloudflare Workers static assets cap every file at 25 MiB and
# the Godot release template's `index.wasm` is ~38 MiB (already stripped - it is
# 33 MiB of code + 4.5 MiB of data, so there is nothing to trim). `dist/` holds
# the wasm split into ~16 MiB pieces plus a small manifest, and worker/index.js
# streams the pieces back in order as a single application/wasm response.
#
# Run manually with: bash ./scripts/cf-build.sh
# (wrangler also runs it automatically via `build.command` in wrangler.jsonc.)
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="build/web"
OUT="dist"
CHUNK="${CHUNK:-16M}"

if [ ! -f "$SRC/index.wasm" ] || [ ! -f "$SRC/index.pck" ]; then
	echo "error: $SRC is missing the Godot web export." >&2
	echo "Rebuild it first: godot --headless --path . --export-release Web $SRC/index.html" >&2
	exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$SRC"/. "$OUT"/

# Split the wasm into pieces the asset server will accept.
split -b "$CHUNK" -d -a 1 "$OUT/index.wasm" "$OUT/index.wasm.part"
rm -f "$OUT/index.wasm"

PART_COUNT=$(find "$OUT" -maxdepth 1 -name 'index.wasm.part[0-9]*' | wc -l | tr -d ' ')
SIZE=$(wc -c <"$SRC/index.wasm" | tr -d ' ')
ETAG="\"$(md5sum "$SRC/index.wasm" | cut -d' ' -f1)\""
printf '{"count":%s,"size":%s,"etag":%s}\n' "$PART_COUNT" "$SIZE" "$ETAG" \
	>"$OUT/index.wasm.parts.json"

printf 'dist ready (%s), wasm split into %s parts\n' "$(du -sh "$OUT" | cut -f1)" "$PART_COUNT"
printf 'largest files (Cloudflare cap: 25 MiB each):\n'
find "$OUT" -maxdepth 1 -type f -printf '%s\t%p\n' |
	sort -rn | head -4 |
	while IFS=$'\t' read -r size path; do
		printf '  %6.1f MiB  %s\n' "$(echo "$size" | awk '{print $1/1048576}')" "$path"
	done
