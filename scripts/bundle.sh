#!/usr/bin/env bash
# Builds Cleen.app (release, arm64) into build/.
#   ./scripts/bundle.sh            build the bundle
#   ./scripts/bundle.sh --install  also copy to /Applications and relaunch
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/Cleen.app"
VERSION="$(git describe --tags --always 2>/dev/null || echo 0.1.0)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release --product Cleen

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Cleen" "$APP/Contents/MacOS/Cleen"

# Now Playing bridge (see Support/NowPlaying/CleenNowPlaying.m for why it's separate).
clang -dynamiclib -fobjc-arc -O2 -framework Foundation \
  "$ROOT/Support/NowPlaying/CleenNowPlaying.m" -o "$APP/Contents/Resources/libCleenNowPlaying.dylib"
cp "$ROOT/Support/NowPlaying/now-playing.pl" "$APP/Contents/Resources/now-playing.pl"

# Icon: regenerate only when the script changed.
ICONSET="$ROOT/build/AppIcon.iconset"
ICNS="$ROOT/build/AppIcon.icns"
if [[ ! -f "$ICNS" || "$ROOT/scripts/make-icon.swift" -nt "$ICNS" ]]; then
  swift "$ROOT/scripts/make-icon.swift" "$ICONSET" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICNS"
fi
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Cleen</string>
  <key>CFBundleDisplayName</key><string>Cleen</string>
  <key>CFBundleIdentifier</key><string>app.cleen.Cleen</string>
  <key>CFBundleExecutable</key><string>Cleen</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© Matheus Cardoso</string>
  <key>NSAppleEventsUsageDescription</key><string>O Cleen usa o macOS para pedir a senha de administrador quando uma limpeza precisa dela.</string>
  <key>NSCameraUsageDescription</key><string>O Espelho do Cleen mostra a câmera frontal para você se ver antes de uma chamada. Nada é gravado.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>O Cleen mostra os eventos de hoje no notch.</string>
  <key>NSRemindersFullAccessUsageDescription</key><string>O Cleen mostra seus lembretes no notch e deixa você marcá-los como feitos.</string>
</dict>
</plist>
PLIST

# Sign with a stable identity. An ad-hoc signature changes with every build, and macOS
# ties privacy permissions (Calendar, Reminders, Full Disk Access, Keychain "Always
# Allow") to the signature, so every rebuild would silently lose them.
# Override with CLEEN_SIGN_IDENTITY; falls back to ad-hoc when no certificate exists.
IDENTITY="${CLEEN_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 'Apple Development' | awk '{print $2}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP/Contents/Resources/libCleenNowPlaying.dylib" >/dev/null
codesign --force --sign "$IDENTITY" --timestamp=none "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Cleen 2>/dev/null || true
  rm -rf /Applications/Cleen.app
  cp -R "$APP" /Applications/Cleen.app
  open /Applications/Cleen.app
  echo "Installed /Applications/Cleen.app"
fi
