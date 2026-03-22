#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Mister Mirror"
BUNDLE_NAME="Mister Mirror.app"
OUTPUT_DIR="build/release"
SWIFT_BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"

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

# Generate app icon: a friendly top-hat-wearing mirror
echo "==> Generating app icon..."
swift -e '
import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background: rounded rect with warm gradient
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 180, yRadius: 180)

let gradient = NSGradient(colors: [
    NSColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0),
    NSColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 1.0)
])!
gradient.draw(in: path, angle: -45)

// Mirror (oval)
let mirrorW: CGFloat = 420
let mirrorH: CGFloat = 540
let mirrorX = (CGFloat(size) - mirrorW) / 2
let mirrorY: CGFloat = 100
let mirrorRect = NSRect(x: mirrorX, y: mirrorY, width: mirrorW, height: mirrorH)
let mirrorPath = NSBezierPath(ovalIn: mirrorRect)

// Mirror fill - lighter reflective look
NSColor(white: 0.92, alpha: 0.9).setFill()
mirrorPath.fill()
NSColor.white.setStroke()
mirrorPath.lineWidth = 16
mirrorPath.stroke()

// Shine on mirror
let shinePath = NSBezierPath(ovalIn: NSRect(x: mirrorX + 60, y: mirrorY + mirrorH - 200, width: 100, height: 140))
NSColor(white: 1.0, alpha: 0.5).setFill()
shinePath.fill()

// Handle
let handlePath = NSBezierPath()
handlePath.move(to: NSPoint(x: CGFloat(size)/2 - 30, y: mirrorY))
handlePath.line(to: NSPoint(x: CGFloat(size)/2 - 20, y: mirrorY - 60))
handlePath.line(to: NSPoint(x: CGFloat(size)/2 + 20, y: mirrorY - 60))
handlePath.line(to: NSPoint(x: CGFloat(size)/2 + 30, y: mirrorY))
handlePath.close()
NSColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0).setFill()
handlePath.fill()
NSColor.white.setStroke()
handlePath.lineWidth = 8
handlePath.stroke()

// Top hat on top of mirror
let hatBrimY = mirrorY + mirrorH - 80
let hatCenterX = CGFloat(size) / 2

// Hat brim
let brimPath = NSBezierPath(ovalIn: NSRect(x: hatCenterX - 160, y: hatBrimY - 20, width: 320, height: 50))
NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).setFill()
brimPath.fill()

// Hat top
let hatTopPath = NSBezierPath(roundedRect: NSRect(x: hatCenterX - 100, y: hatBrimY, width: 200, height: 200), xRadius: 15, yRadius: 15)
NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).setFill()
hatTopPath.fill()

// Hat band
let bandPath = NSBezierPath(rect: NSRect(x: hatCenterX - 100, y: hatBrimY + 15, width: 200, height: 25))
NSColor(red: 0.75, green: 0.25, blue: 0.25, alpha: 1.0).setFill()
bandPath.fill()

// Eyes on mirror (friendly face!)
let eyeY = mirrorY + mirrorH / 2 + 40
let eyeSize: CGFloat = 32
// Left eye
let leftEye = NSBezierPath(ovalIn: NSRect(x: hatCenterX - 80 - eyeSize/2, y: eyeY, width: eyeSize, height: eyeSize + 8))
NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.85).setFill()
leftEye.fill()
// Right eye
let rightEye = NSBezierPath(ovalIn: NSRect(x: hatCenterX + 80 - eyeSize/2, y: eyeY, width: eyeSize, height: eyeSize + 8))
rightEye.fill()

// Smile
let smilePath = NSBezierPath()
smilePath.appendArc(withCenter: NSPoint(x: hatCenterX, y: eyeY - 50),
                    radius: 70, startAngle: 200, endAngle: 340)
NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.85).setStroke()
smilePath.lineWidth = 10
smilePath.lineCapStyle = .round
smilePath.stroke()

image.unlockFocus()

// Write multiple sizes for iconutil
let iconsetPath = ".build/dmg-staging/AppIcon.iconset"
let fm = FileManager.default
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, sz) in sizes {
    let resized = NSImage(size: NSSize(width: sz, height: sz))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: sz, height: sz))
    resized.unlockFocus()
    let tiff = resized.tiffRepresentation!
    let bmp = NSBitmapImageRep(data: tiff)!
    let png = bmp.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}
print("Icon images generated.")
'

# Convert iconset to icns
if command -v iconutil &>/dev/null; then
    iconutil -c icns -o "$STAGING_DIR/$BUNDLE_NAME/Contents/Resources/AppIcon.icns" \
        "$STAGING_DIR/AppIcon.iconset"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "$STAGING_DIR/$BUNDLE_NAME/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" \
        "$STAGING_DIR/$BUNDLE_NAME/Contents/Info.plist"
    echo "==> App icon created."
else
    echo "==> iconutil not found, skipping icon (app will use default icon)"
fi

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
