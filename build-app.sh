#!/usr/bin/env bash
# Builds Focus.app into ./build. Pass --install to also copy it to /Applications and open it.
set -euo pipefail

APP_NAME="Focus"
BUNDLE_ID="com.armanomidian.focus"
VERSION="1.0.0"

cd "$(dirname "$0")"

echo "→ Building…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/chime.wav "$APP/Contents/Resources/"
cp Resources/Fonts/* "$APP/Contents/Resources/Fonts/"

echo "→ Icon…"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# LSUIElement = menu bar app, no Dock icon.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "✓ Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$APP" /Applications/
  echo "✓ Installed to /Applications/${APP_NAME}.app"
  open "/Applications/${APP_NAME}.app"
fi
