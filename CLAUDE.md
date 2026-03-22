# Mister Mirror

Single-file macOS app (Sources/main.swift) that mirrors an iPhone screen over USB using AVFoundation/CoreMediaIO.

## Build

- `swift build` / `swift run` for development
- `./build-dmg.sh` for release — outputs to `build/release/`
- The app icon is generated programmatically at build time (no asset files)

## Architecture

Everything is in `Sources/main.swift`. No external dependencies. Uses:
- CoreMediaIO: `kCMIOHardwarePropertyAllowScreenCaptureDevices` to expose iOS devices
- AVFoundation: `AVCaptureSession` + `AVCaptureVideoPreviewLayer` for capture and display
- AppKit: `NSWindow` + `NSApplication` for the window

## Key constraints

- macOS only (Apple frameworks)
- Requires Xcode CLI tools to build
- iPhone must be USB-connected, unlocked, and trusted
- The CoreMediaIO property activation takes 2-5 seconds and is rate-limited (~1 min cooldown)
