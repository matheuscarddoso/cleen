#!/usr/bin/env bash
# Checks the English translation against the text the code actually shows.
#   ./scripts/strings.sh           list keys missing from en.lproj and keys no longer used
#   ./scripts/strings.sh --json    also write build/strings-missing.json (key → "") to fill in
# The keys are the Portuguese strings themselves: the compiler extracts every one used
# through Text("…"), String(localized: "…") and friends.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/strings"
rm -rf "$OUT" && mkdir -p "$OUT"
# A build of its own: the strings are only written when a file compiles, so a cached
# build would report nothing.
SCRATCH="$ROOT/build/strings-build"
rm -rf "$SCRATCH"
swift build -c release --product Cleen --scratch-path "$SCRATCH" \
  -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT" >/dev/null
rm -rf "$SCRATCH"
swift "$ROOT/scripts/strings-check.swift" "$OUT" "$ROOT/Support/Localization/en.lproj/Localizable.strings" "${1:-}" "$ROOT/build/strings-missing.json"
