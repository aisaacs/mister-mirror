# Mister Mirror

Native macOS app that mirrors an iPhone screen over USB using AVFoundation/CoreMediaIO. Single-file app at `Sources/main.swift` (~300 lines).

## Build

- **Xcode**: `open MisterMirror.xcodeproj` — Cmd+R
- **CLI dev**: `swift build && swift run`
- **Release DMG**: `./build-dmg.sh` — outputs to `build/release/`
- **Regenerate icon**: `./scripts/generate-icon.sh` (converts `Resources/AppIcon.jpg` to `.icns`)

## Architecture

Everything lives in `Sources/main.swift`. No external dependencies.

### Key components

- `enableScreenCaptureDevices()` — sets `kCMIOHardwarePropertyAllowScreenCaptureDevices` via CoreMediaIO to expose iOS devices as capture sources
- `findiPhoneDevice()` — discovers iPhone via `AVCaptureDevice.DiscoverySession` with type `.externalUnknown` and media type `.muxed`
- `PreviewView` — NSView backed by `AVCaptureVideoPreviewLayer` for live display
- `FrameGrabber` — `AVCaptureVideoDataOutputSampleBufferDelegate` that holds the latest frame for screenshots and drives `AVAssetWriter` for video recording
- `AppDelegate` — sets up the capture session, window, menu bar (File > Screenshot / Record), and keyboard shortcuts

### Frameworks used

- **CoreMediaIO** — property to activate screen capture device exposure
- **AVFoundation** — `AVCaptureSession`, `AVCaptureDeviceInput`, `AVCaptureVideoDataOutput`, `AVCaptureVideoPreviewLayer`, `AVAssetWriter`
- **AppKit** — `NSWindow`, `NSApplication`, `NSMenu`
- **CoreImage** — frame-to-CGImage conversion for screenshots

## Project layout

- `Sources/main.swift` — the entire app
- `MisterMirror.xcodeproj/` — Xcode project (references Sources/ and Assets.xcassets/)
- `Package.swift` — Swift package manifest (for CLI builds)
- `Info.plist` — shared by both Xcode and DMG builds; contains `NSCameraUsageDescription`
- `Assets.xcassets/` — asset catalog with app icon (used by Xcode builds)
- `Resources/AppIcon.icns` — compiled icon (used by DMG builds)
- `build-dmg.sh` — assembles .app bundle and creates DMG in `build/release/`
- `scripts/generate-icon.sh` — converts `Resources/AppIcon.jpg` → `Resources/AppIcon.icns` via sips + iconutil

## Key constraints

- macOS 13+ only (Apple frameworks)
- iPhone must be USB-connected, unlocked, and trusted
- CoreMediaIO activation takes 2-5 seconds, rate-limited to ~1 min between app restarts
- Camera permission required (configured via `NSCameraUsageDescription` in Info.plist)
- Screenshots and recordings save to `~/Desktop/` with timestamp filenames
