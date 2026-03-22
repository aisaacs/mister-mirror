# Mister Mirror

A dapper little macOS app that mirrors your iPhone's screen over USB — no QuickTime needed.

Mister Mirror uses the same CoreMediaIO/AVFoundation mechanism that QuickTime Player uses internally: he tells macOS to expose connected iOS devices as capture sources, then displays the live H.264 stream in a window. He even comes with his own top hat.

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)
- iPhone connected via USB, unlocked, and trusted

## Quick Start

```bash
./build-dmg.sh
open build/release/MisterMirror.dmg
```

Drag **Mister Mirror** to Applications. Launch him. He'll find your iPhone.

## Development

```bash
swift build
swift run
```

## How It Works

1. Sets the `kCMIOHardwarePropertyAllowScreenCaptureDevices` CoreMediaIO property — this triggers macOS to activate a hidden USB configuration on the iPhone that exposes screen capture endpoints
2. Discovers the iPhone via `AVCaptureDevice.DiscoverySession` (it appears as an external muxed audio/video device)
3. Displays the live capture stream using `AVCaptureVideoPreviewLayer` in a native AppKit window

The entire app is a single Swift file (~150 lines) with no dependencies beyond Apple's frameworks.

## Build Output

Running `./build-dmg.sh` produces:

```
build/release/
├── Mister Mirror.app    # The app bundle
└── MisterMirror.dmg     # Distributable disk image
```

The DMG includes an Applications shortcut for drag-to-install.

## Notes

- First launch takes a few seconds while macOS activates the USB screen capture subsystem
- macOS will prompt for Camera permission on first run — Mister Mirror needs it, don't be shy
- The app icon (a top-hat-wearing mirror with a friendly face) is generated at build time — no external assets needed
- Not code-signed — macOS may require you to right-click > Open on first launch, or allow it in System Settings > Privacy & Security

## License

MIT
