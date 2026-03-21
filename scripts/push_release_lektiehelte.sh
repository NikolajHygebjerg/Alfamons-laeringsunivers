#!/usr/bin/env bash
# Push main og opdatér remote branch 'release' (Lektiehelte / team-release).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Pusher main til origin..."
git push origin main

echo "==> Opdaterer origin/release til samme commit som main..."
git push origin main:release

echo "Færdig. Tjek GitHub: branch 'release' skulle matche 'main'."
