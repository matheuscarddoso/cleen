#!/usr/bin/env bash
# Builds build/Cleen.dmg: the app and a link to Aplicativos in a window laid out like
# the installers of Aside and Helium (see scripts/make-dmg-background.swift).
#   ./scripts/dmg.sh
# The Finder lays the window out, so the first run asks to let Terminal control it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VOLUME="Cleen"
STAGE="$ROOT/build/dmg"
RW="$ROOT/build/Cleen-rw.dmg"
OUT="$ROOT/build/Cleen.dmg"
# Window content size and icon centres; they match the background's layout.
WIDTH=480
HEIGHT=560
# The Finder's bounds include the title bar.
TITLEBAR=32

./scripts/bundle.sh

rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background"
cp -R "$ROOT/build/Cleen.app" "$STAGE/"
ln -s /Applications "$STAGE/Aplicativos"

# A 1x and a 2x background in one TIFF, so the Finder picks the sharp one on Retina.
swift scripts/make-dmg-background.swift "$ROOT/build/dmg-background.png" 1
swift scripts/make-dmg-background.swift "$ROOT/build/dmg-background@2x.png" 2
tiffutil -cathidpicheck "$ROOT/build/dmg-background.png" "$ROOT/build/dmg-background@2x.png" -out "$STAGE/.background/background.tiff" >/dev/null

# A volume already mounted under the same name would take the Finder's attention.
if [[ -d "/Volumes/$VOLUME" ]]; then hdiutil detach "/Volumes/$VOLUME" -quiet || true; fi

hdiutil create -srcfolder "$STAGE" -volname "$VOLUME" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -E '^/dev/' | head -1 | awk '{print $1}')"
MOUNT="/Volumes/$VOLUME"

# The disk's own icon in the Finder sidebar and on the desktop.
cp "$ROOT/build/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT/.VolumeIcon.icns"
SetFile -a C "$MOUNT"
# "Cleen", not "Cleen.app".
SetFile -a E "$MOUNT/Cleen.app"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 140, 240 + $WIDTH, 140 + $HEIGHT + $TITLEBAR}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Cleen.app" of container window to {240, 168}
    set position of item "Aplicativos" of container window to {240, 408}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach "$DEVICE" -quiet
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -f "$RW"
echo "Built $OUT"
