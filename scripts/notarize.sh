#!/usr/bin/env bash
# Sends a Developer ID signed Cleen.app or DMG to Apple's notary service and staples the
# ticket to it, so Gatekeeper opens it with no warning, even offline.
#   ./scripts/notarize.sh build/Cleen.app
#   ./scripts/notarize.sh build/Cleen-1.4.0.dmg
# Uses the "cleen-notary" keychain profile: an App Store Connect API key of the
# distribution team, saved once with
#   xcrun notarytool store-credentials cleen-notary --key AuthKey_<id>.p8 --key-id <id> --issuer <uuid>
# notarytool keeps that profile in a keychain macOS closes while the screen is locked,
# so a Mac that locks halfway through a release loses it. CLEEN_NOTARY_KEY_ID and
# CLEEN_NOTARY_ISSUER use the key itself instead, read from CLEEN_NOTARY_KEY or
# ~/.appstoreconnect/private_keys/AuthKey_<id>.p8, with no keychain involved.
set -euo pipefail

TARGET="${1:?o .app ou o .dmg}"
if [[ -n "${CLEEN_NOTARY_KEY_ID:-}" ]]; then
  AUTH=(--key "${CLEEN_NOTARY_KEY:-$HOME/.appstoreconnect/private_keys/AuthKey_$CLEEN_NOTARY_KEY_ID.p8}"
        --key-id "$CLEEN_NOTARY_KEY_ID" --issuer "${CLEEN_NOTARY_ISSUER:?o issuer da chave da API}")
else
  AUTH=(--keychain-profile "${CLEEN_NOTARY_PROFILE:-cleen-notary}")
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The service takes a zip, a DMG or a package; an app goes zipped, with its parent
# folder so the bundle is whole on the other side.
case "$TARGET" in
  *.app) SUBMIT="$WORK/$(basename "$TARGET" .app).zip"; ditto -c -k --keepParent "$TARGET" "$SUBMIT" ;;
  *) SUBMIT="$TARGET" ;;
esac

RESULT="$WORK/result.json"
xcrun notarytool submit "$SUBMIT" "${AUTH[@]}" --wait --output-format json > "$RESULT"
STATUS="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("status", ""))' "$RESULT")"
if [[ "$STATUS" != "Accepted" ]]; then
  ID="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("id", ""))' "$RESULT")"
  echo "A Apple recusou a notarização de $TARGET ($STATUS). O motivo:"
  [[ -n "$ID" ]] && xcrun notarytool log "$ID" "${AUTH[@]}"
  exit 1
fi

xcrun stapler staple -q "$TARGET"
xcrun stapler validate -q "$TARGET"
echo "Notarized $TARGET"
