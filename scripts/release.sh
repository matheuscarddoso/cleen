#!/usr/bin/env bash
# Cuts a release: tags it, builds the DMG, writes appcast.json and publishes both as a
# GitHub release of this repo, where the updater reads them (UpdateModel.feedURL).
#   ./scripts/release.sh 1.2.0 "O que mudou, numa linha"
# Needs a clean tree and `gh` signed in to the personal account.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?versão, ex.: 1.2.0}"
NOTES="${2:-}"
RELEASES_REPO="matheuscarddoso/cleen"
TAG="v$VERSION"

[[ -z "$(git status --porcelain)" ]] || { echo "Há mudanças sem commit."; exit 1; }
git tag -a "$TAG" -m "Cleen $VERSION"
git push -q origin main "$TAG"

./scripts/dmg.sh
DMG="build/Cleen-$VERSION.dmg"
mv build/Cleen.dmg "$DMG"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
BUILD="$(git rev-list --count HEAD)"
URL="https://github.com/$RELEASES_REPO/releases/download/$TAG/Cleen-$VERSION.dmg"

python3 - "$VERSION" "$BUILD" "$URL" "$SHA" "$NOTES" > build/appcast.json <<'PY'
import json, sys
version, build, url, sha, notes = sys.argv[1:6]
print(json.dumps({"version": version, "build": int(build), "url": url, "sha256": sha,
                  "notes": notes or None, "minimumSystemVersion": "26.0"}, ensure_ascii=False, indent=2))
PY

# The same DMG under a fixed name too, so the site's download link never changes.
cp "$DMG" build/Cleen.dmg
gh release create "$TAG" "$DMG" build/Cleen.dmg build/appcast.json --repo "$RELEASES_REPO" --title "Cleen $VERSION" --notes "${NOTES:-Cleen $VERSION}"
echo "Publicado: $URL"
