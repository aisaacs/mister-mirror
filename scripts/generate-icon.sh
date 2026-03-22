#!/bin/bash
# Converts Resources/AppIcon.jpg (or .png) into Resources/AppIcon.icns
# Run once on macOS after adding your source image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

mkdir -p Resources

# Find source image
if [ -f "Resources/AppIcon.jpg" ]; then
    SOURCE="Resources/AppIcon.jpg"
elif [ -f "Resources/AppIcon.png" ]; then
    SOURCE="Resources/AppIcon.png"
else
    echo "Error: No source image found."
    echo "Place your icon at Resources/AppIcon.jpg or Resources/AppIcon.png"
    exit 1
fi

echo "==> Source: $SOURCE"

ICONSET_DIR=".build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "==> Generating icon sizes..."
for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "$SOURCE" --out "$ICONSET_DIR/tmp_${size}.png" -s format png >/dev/null 2>&1
done

cp "$ICONSET_DIR/tmp_16.png"   "$ICONSET_DIR/icon_16x16.png"
cp "$ICONSET_DIR/tmp_32.png"   "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICONSET_DIR/tmp_32.png"   "$ICONSET_DIR/icon_32x32.png"
cp "$ICONSET_DIR/tmp_64.png"   "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICONSET_DIR/tmp_128.png"  "$ICONSET_DIR/icon_128x128.png"
cp "$ICONSET_DIR/tmp_256.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICONSET_DIR/tmp_256.png"  "$ICONSET_DIR/icon_256x256.png"
cp "$ICONSET_DIR/tmp_512.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICONSET_DIR/tmp_512.png"  "$ICONSET_DIR/icon_512x512.png"
cp "$ICONSET_DIR/tmp_1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

# Clean up temp files
rm -f "$ICONSET_DIR"/tmp_*.png

echo "==> Converting to .icns..."
iconutil -c icns -o "Resources/AppIcon.icns" "$ICONSET_DIR"
rm -rf "$ICONSET_DIR"

echo "==> Done! Resources/AppIcon.icns created from $SOURCE"
