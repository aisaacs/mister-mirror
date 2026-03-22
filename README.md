<p align="center">
  <img src="Resources/AppIcon.jpg" width="200" alt="Mister Mirror icon — a friendly hand mirror wearing a top hat">
</p>

<h1 align="center">Mister Mirror</h1>

<p align="center">
  <em>A dapper little macOS app that mirrors your iPhone screen over USB.</em>
  <br>
  No QuickTime. No Reflector. No subscriptions. Just plug in and go.
  <br><br>
  <a href="https://aisaacs.github.io/mister-mirror/">Website</a> &middot;
  <a href="https://github.com/aisaacs/mister-mirror/releases/latest/download/MisterMirror.dmg">Download DMG</a>
</p>

---

Mister Mirror uses the same native Apple protocol that QuickTime Player uses under the hood — CoreMediaIO and AVFoundation — to display your iPhone's screen in a clean, resizable window. He tips his hat on the way out.

## Features

- **Live mirroring** — your iPhone screen in a native macOS window
- **Screenshots** — Cmd+S saves a full-resolution PNG to your Desktop
- **Video recording** — Cmd+R starts/stops H.264 recording, saved as .mp4 to Desktop
- **Zero dependencies** — built entirely on Apple frameworks, no third-party libraries
- **Single file** — the entire app is ~300 lines of Swift

## Requirements

- macOS 13 (Ventura) or later
- iPhone connected via USB cable
- iPhone must be unlocked and trusted
- Xcode Command Line Tools (`xcode-select --install`)

## Install

### Option A: Build the DMG

```bash
./build-dmg.sh
open build/release/MisterMirror.dmg
```

Drag **Mister Mirror** to Applications. Done.

> First launch: macOS may say the app is from an unidentified developer. Right-click the app > Open, or allow it in System Settings > Privacy & Security.

### Option B: Open in Xcode

```bash
open MisterMirror.xcodeproj
```

Hit Cmd+R to build and run.

### Option C: Command line

```bash
swift build
swift run
```

## Usage

1. Connect your iPhone via USB
2. Unlock the iPhone (and trust this computer if prompted)
3. Launch Mister Mirror
4. Wait a few seconds — he's activating the screen capture subsystem

| Shortcut | Action |
|----------|--------|
| Cmd+S | Take screenshot (saved to Desktop) |
| Cmd+R | Start / stop video recording |
| Cmd+Q | Quit |

Screenshots are saved as `MisterMirror-YYYY-MM-DD-HHmmss.png` and recordings as `.mp4`, both on your Desktop.

## How It Works

QuickTime Player can display a connected iPhone's screen. Mister Mirror does the same thing, minus QuickTime:

1. **Activates screen capture** — sets the `kCMIOHardwarePropertyAllowScreenCaptureDevices` CoreMediaIO property, which tells macOS to send a special USB control request to the iPhone. The iPhone disconnects and reconnects with a hidden USB configuration exposing screen capture endpoints.

2. **Discovers the device** — the iPhone appears as an `AVCaptureDevice` (type `.externalUnknown`, media type `.muxed`) via `AVCaptureDevice.DiscoverySession`.

3. **Captures and displays** — an `AVCaptureSession` pipes the live H.264 video stream through an `AVCaptureVideoPreviewLayer` into an AppKit window. A parallel `AVCaptureVideoDataOutput` taps the raw frames for screenshots and recording.

All of this uses public Apple frameworks. No private APIs, no USB hacking, no reverse engineering needed.

## Project Structure

```
MisterMirror/
├── Sources/main.swift             # The entire app
├── MisterMirror.xcodeproj/        # Xcode project
├── Package.swift                  # Swift package (for CLI builds)
├── Info.plist                     # App bundle metadata + camera usage description
├── Assets.xcassets/               # Asset catalog with app icon (for Xcode)
├── Resources/
│   ├── AppIcon.jpg                # Source icon image
│   └── AppIcon.icns               # Compiled icon (for DMG builds)
├── build-dmg.sh                   # Build script -> build/release/MisterMirror.dmg
└── scripts/generate-icon.sh       # Regenerate .icns from source image
```

## Notes

- **First launch is slow** — the CoreMediaIO property activation takes 2-5 seconds. If QuickTime is already running, it's instant (QuickTime keeps the property set).
- **Camera permission** — macOS will prompt for Camera access on first run. Mister Mirror needs this to see the iPhone as a capture device.
- **Rate limiting** — there's a ~1 minute cooldown between app restarts for the CoreMediaIO activation. If the app doesn't find your device, wait a moment and try again.
- **Not code-signed** — unless you sign it yourself, macOS Gatekeeper will block it. Right-click > Open to bypass.

## License

MIT
