#!/usr/bin/env bash
# Kopiér topniveau PNG/JPG fra Alfamon Trace til assets/alfamons_bundles/trace/
# (valgfrit — til oversigt; spillet bruger stadig packages/alfamon_trace/Assets).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/packages/alfamon_trace/Assets"
DST="$ROOT/assets/alfamons_bundles/trace"

if [[ ! -d "$SRC" ]]; then
  echo "Mangler: $SRC" >&2
  exit 1
fi

mkdir -p "$DST"
count=0
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  cp -f "$f" "$DST/$base"
  count=$((count + 1))
done < <(find "$SRC" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) -print0)

echo "Kopieret $count fil(er) til $DST"
