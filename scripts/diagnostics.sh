#!/usr/bin/env bash
# Reads the error reports Cleen sends (site/app/api/diagnostics, lib/diagnostics.ts).
#   ./scripts/diagnostics.sh                          every problem, most recent first
#   ./scripts/diagnostics.sh <signature>              one problem and the reports kept for it
#   ./scripts/diagnostics.sh <signature> <report>     one report, whole, as JSON
#   ./scripts/diagnostics.sh <signature> <report> --ips > crash.ips
#                                                     a crash back as the .ips macOS wrote, for
#                                                     Console or symbolicating against the dSYM
# Needs DIAGNOSTICS_TOKEN (the server's); DIAGNOSTICS_URL points it at another server
# (default https://cleen.ocardoso.com, e.g. http://127.0.0.1:3000 for `next dev`).
set -euo pipefail
cd "$(dirname "$0")"

: "${DIAGNOSTICS_TOKEN:?Set DIAGNOSTICS_TOKEN to the token configured on the server.}"
BASE="${DIAGNOSTICS_URL:-https://cleen.ocardoso.com}/api/diagnostics"

# The token goes through stdin, so it never shows in the process list.
get() {
  printf 'Authorization: Bearer %s\n' "$DIAGNOSTICS_TOKEN" | curl -fsS -H @- "$1"
}

view() {
  python3 -I diagnostics-view.py "$1"
}

# Fetched first, formatted after: a refused token stops at curl's own message.
if [[ $# -eq 0 ]]; then
  body="$(get "$BASE")"
  view list <<<"$body"
elif [[ $# -eq 1 ]]; then
  body="$(get "$BASE?signature=$1")"
  view group <<<"$body"
else
  body="$(get "$BASE?signature=$1&report=$2")"
  if [[ "${3:-}" == "--ips" ]]; then
    view ips <<<"$body"
  else
    python3 -I -m json.tool <<<"$body"
  fi
fi
