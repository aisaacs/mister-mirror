#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Mister Mirror"
BUNDLE_NAME="Mister Mirror.app"
OUTPUT_DIR="build/release"
SWIFT_BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"
ICON_FILE="Resources/AppIcon.icns"

echo "==> Building release binary..."
swift build -c release

echo "==> Assembling app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$STAGING_DIR/$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$STAGING_DIR/$BUNDLE_NAME/Contents/Resources"

# Copy binary
cp "$SWIFT_BUILD_DIR/MisterMirror" "$STAGING_DIR/$BUNDLE_NAME/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$STAGING_DIR/$BUNDLE_NAME/Contents/Resources/"
cp Info.plist "$STAGING_DIR/$BUNDLE_NAME/Contents/"

# Copy icon
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$STAGING_DIR/$BUNDLE_NAME/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "$STAGING_DIR/$BUNDLE_NAME/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" \
        "$STAGING_DIR/$BUNDLE_NAME/Contents/Info.plist"
    echo "==> App icon included."
else
    echo "==> Warning: No icon found at $ICON_FILE"
    echo "    Run ./scripts/generate-icon.sh first to generate it."
fi

echo "==> Signing app bundle..."
codesign --force --deep --sign - "$STAGING_DIR/$BUNDLE_NAME"
echo "==> App signed (ad-hoc)."

echo "==> Creating DMG..."
DMG_PATH="$OUTPUT_DIR/MisterMirror.dmg"
rm -f "$DMG_PATH"

# Copy .app to output dir
rm -rf "$OUTPUT_DIR/$BUNDLE_NAME"
cp -R "$STAGING_DIR/$BUNDLE_NAME" "$OUTPUT_DIR/"

# Create DMG with Applications symlink for drag-to-install
mkdir -p "$STAGING_DIR/dmg-contents"
cp -R "$STAGING_DIR/$BUNDLE_NAME" "$STAGING_DIR/dmg-contents/"
ln -sf /Applications "$STAGING_DIR/dmg-contents/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR/dmg-contents" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "==> Done! Output in $OUTPUT_DIR/"
echo "    $OUTPUT_DIR/$BUNDLE_NAME  (the app)"
echo "    $DMG_PATH                 (distributable DMG)"
echo ""
echo "    Open the DMG and drag '$APP_NAME' to Applications."
