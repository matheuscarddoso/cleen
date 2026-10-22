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
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for the app to run and keep its permissions on this Mac.
codesign --force --sign - --timestamp=none "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Cleen 2>/dev/null || true
  rm -rf /Applications/Cleen.app
  cp -R "$APP" /Applications/Cleen.app
  open /Applications/Cleen.app
  echo "Installed /Applications/Cleen.app"
fi
