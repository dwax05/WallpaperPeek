#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="WallpaperPeek"
APP_NAME="WallpaperPeek.app"
APP_PATH="/Applications/$APP_NAME"
SIGN_IDENTITY="-"

echo "==> Building $BINARY_NAME..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BUILT_BINARY="$SCRIPT_DIR/.build/release/$BINARY_NAME"
if [ ! -f "$BUILT_BINARY" ]; then
    echo "ERROR: Build failed"
    exit 1
fi

echo "==> Assembling .app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
cp "$BUILT_BINARY" "$APP_PATH/Contents/MacOS/$BINARY_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$BINARY_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"

echo "==> Signing .app bundle..."
codesign --force --deep \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$SCRIPT_DIR/WallpaperPeek.entitlements" \
    --options runtime \
    "$APP_PATH"

echo "==> Seeding tunable config..."
CFG_DIR="$HOME/.config/wallpaperpeek"
mkdir -p "$CFG_DIR"
if [ ! -f "$CFG_DIR/config.json" ]; then
cat > "$CFG_DIR/config.json" << 'JSON'
{
  "columns": 6,
  "thumbW": 210,
  "thumbH": 130,
  "pad": 10,
  "labelH": 28,
  "cornerRadius": 8,
  "titleText": "˚ ₊‧꒰ა  ✦ ˚  · ˚  wallpapers  ˚ ·  ˚ ✦  ໒꒱ ‧₊˚",
  "titleFontSize": 16,
  "titleYOffset": 0,
  "showTitle": true,
  "labelFontSize": 11,
  "labelYOffset": 0,
  "activeBadgeFontSize": 11,
  "activeBadgeYOffset": 0,
  "activeBadgeTextYOffset": 0,
  "activeBadgeWidth": 74,
  "activeBadgeHeight": 22,
  "footerFontSize": 11,
  "selBorderWidth": 2.5,
  "selGlowRadius": 12,
  "selGlowOpacity": 0.9,
  "panelYOffset": 0
}
JSON
else
  echo "    (config.json exists - leaving your values untouched)"
fi

echo "==> Launching..."
pkill -x WallpaperPeek 2>/dev/null || true
sleep 0.5
open "$APP_PATH"

echo ""
echo "✓ WallpaperPeek.app installed to /Applications!"
echo ""
echo "  Trigger:  Option + Q"
echo "  Navigate: arrow keys or hjkl"
echo "  Set:      Enter (or click selected)"
echo "  Quit:     ESC or q"
echo ""
echo "  Wallpapers read from: ~/Downloads/wallpapers"
echo "  Tune layout in: ~/.config/wallpaperpeek/config.json"
echo ""
echo "  On first launch grant Accessibility (for hotkey) and"
echo "  Screen Recording is NOT needed. Tune in System Settings."
