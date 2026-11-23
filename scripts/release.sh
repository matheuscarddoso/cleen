#!/usr/bin/env bash
# Cuts a release: builds and notarizes the app, builds the DMG, writes the update feeds
# and publishes them as a GitHub release of this repo, where the updater reads them
# (UpdateModel.feedURL).
#   ./scripts/release.sh 1.4.0 "O que mudou, numa linha"
# Needs a clean main, `gh` signed in to the personal account, the Developer ID
# certificate in the keychain and the "cleen-notary" profile (see scripts/notarize.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?versão, ex.: 1.4.0}"
NOTES="${2:-}"
RELEASES_REPO="matheuscarddoso/cleen"
TAG="v$VERSION"
# 1.3.0 and earlier read appcast.json and only take a build signed by their own team
# (9QGGX38JS2). The bridge is that team's last build: it reads update.json and accepts
# the Developer ID team (UpdateSigner). Every release after it publishes the bridge's
# appcast.json again, so an old copy always steps through the bridge.
BRIDGE_TAG="v1.3.1"
BRIDGE_TEAM="9QGGX38JS2"

[[ -z "$(git status --porcelain)" ]] || { echo "Há mudanças sem commit."; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo "Releases saem da main."; exit 1; }

# A notarization can take hours; keep the display awake meanwhile, so the screen
# doesn't lock and close the keychain the notary profile lives in (scripts/notarize.sh).
caffeinate -di -w $$ &

# The bundle takes its version from the latest tag, so the tag comes first; it only
# leaves this Mac once everything below has worked.
git tag -a "$TAG" -m "Cleen $VERSION"
PUSHED=0
trap '[[ $PUSHED == 1 ]] || git tag -d "$TAG" >/dev/null' EXIT

APP="build/Cleen.app"
if [[ "$TAG" == "$BRIDGE_TAG" ]]; then
  CLEEN_TEAM_ID="$BRIDGE_TEAM" ./scripts/bundle.sh
else
  ./scripts/bundle.sh
fi
SIGNATURE="$(codesign -dvv "$APP" 2>&1)"
TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2}' <<<"$SIGNATURE")"
AUTHORITY="$(awk -F= '/^Authority=/ {print $2; exit}' <<<"$SIGNATURE")"
if [[ "$TAG" == "$BRIDGE_TAG" ]]; then
  [[ "$TEAM" == "$BRIDGE_TEAM" ]] || { echo "A ponte precisa sair assinada por $BRIDGE_TEAM, não por ${TEAM:-ninguém}."; exit 1; }
else
  [[ "$AUTHORITY" == "Developer ID Application:"* ]] || { echo "Depois da $BRIDGE_TAG só sai versão com Developer ID; esta foi assinada por ${AUTHORITY:-ninguém}."; exit 1; }
  ./scripts/notarize.sh "$APP"
fi

./scripts/dmg.sh --prebuilt
DMG="build/Cleen-$VERSION.dmg"
mv build/Cleen.dmg "$DMG"
if [[ "$TAG" != "$BRIDGE_TAG" ]]; then
  codesign --force --sign "$AUTHORITY" --timestamp "$DMG"
  ./scripts/notarize.sh "$DMG"
fi
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
BUILD="$(git rev-list --count HEAD)"
URL="https://github.com/$RELEASES_REPO/releases/download/$TAG/Cleen-$VERSION.dmg"

python3 - "$VERSION" "$BUILD" "$URL" "$SHA" "$NOTES" > build/update.json <<'PY'
import json, sys
version, build, url, sha, notes = sys.argv[1:6]
print(json.dumps({"version": version, "build": int(build), "url": url, "sha256": sha,
                  "notes": notes or None, "minimumSystemVersion": "26.0"}, ensure_ascii=False, indent=2))
PY
rm -f build/appcast.json
if [[ "$TAG" == "$BRIDGE_TAG" ]]; then
  cp build/update.json build/appcast.json
else
  gh release download "$BRIDGE_TAG" --repo "$RELEASES_REPO" --pattern appcast.json --dir build
fi

git push -q origin main "$TAG"
PUSHED=1

# The same DMG under a fixed name too, so the site's download link never changes.
cp "$DMG" build/Cleen.dmg
gh release create "$TAG" "$DMG" build/Cleen.dmg build/update.json build/appcast.json --repo "$RELEASES_REPO" --title "Cleen $VERSION" --notes "${NOTES:-Cleen $VERSION}"
echo "Publicado: $URL"
