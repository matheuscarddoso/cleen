#!/usr/bin/env bash
# Screenshots the open notch for each tab given (default: all), for UI review.
#   ./scripts/shoot-notch.sh <out-dir> [tab ...]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$1"; shift
TABS=("${@:-home clean projects files system startup maintenance}")
for tab in ${TABS[@]}; do
  pkill -x Cleen 2>/dev/null || true
  while pgrep -x Cleen >/dev/null; do sleep 0.2; done
  open -n build/Cleen.app --args --notch "$tab" --scan
  sleep "${WAIT:-14}"
  screencapture -x -R 345,0,780,400 "$OUT/notch-$tab.png"
done
pkill -x Cleen 2>/dev/null || true
