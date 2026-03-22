import AppKit
import AVFoundation
import CoreMediaIO

// MARK: - Enable iOS Screen Capture Devices

func enableScreenCaptureDevices() {
    var property = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var allow: UInt32 = 1
    let status = CMIOObjectSetPropertyData(
        CMIOObjectID(kCMIOObjectSystemObject),
        &property,
        0, nil,
        UInt32(MemoryLayout<UInt32>.size),
        &allow
    )
    if status != noErr {
        print("Warning: Failed to enable screen capture devices (error \(status))")
    }
}

// MARK: - Find iPhone Device

func findiPhoneDevice() -> AVCaptureDevice? {
    let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.externalUnknown],
        mediaType: .muxed,
        position: .unspecified
    )
    let devices = discovery.devices
    if devices.isEmpty {
        return nil
    }
    return devices.first { $0.localizedName.localizedCaseInsensitiveContains("iPhone") }
        ?? devices.first
}

// MARK: - Preview View

class PreviewView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            wantsLayer = true
            if let layer = previewLayer {
                layer.videoGravity = .resizeAspect
                self.layer = layer
            }
        }
    }

    override func makeBackingLayer() -> CALayer {
        return previewLayer ?? CALayer()
    }
}

// MARK: - Frame Grabber (for screenshots + recording)

class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var latestBuffer: CMSampleBuffer?
    var assetWriter: AVAssetWriter?
    var writerInput: AVAssetWriterInput?
    var isRecording = false
    var recordingStartTime: CMTime?
    var recordingURL: URL?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestBuffer = sampleBuffer

        if isRecording, let writer = assetWriter, let input = writerInput {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: timestamp)
                recordingStartTime = timestamp
            }

            if writer.status == .writing, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }

    func takeScreenshot() -> NSImage? {
        guard let buffer = latestBuffer,
              let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return nil
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    func startRecording() -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "MisterMirror-\(timestamp).mp4"

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let url = desktopURL.appendingPathComponent(filename)

        guard let writer = try? AVAssetWriter(url: url, fileType: .mp4) else {
            return false
        }

        // Get dimensions from the latest frame, or use defaults
        var width = 1170
        var height = 2532
        if let buffer = latestBuffer, let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
            width = CVPixelBufferGetWidth(imageBuffer)
            height = CVPixelBufferGetHeight(imageBuffer)
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        writer.add(input)
        assetWriter = writer
        writerInput = input
        recordingURL = url
        recordingStartTime = nil
        isRecording = true

        return true
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        isRecording = false
        guard let writer = assetWriter else {
            completion(nil)
            return
        }
        let url = recordingURL
        writerInput?.markAsFinished()
        writer.finishWriting {
            self.assetWriter = nil
            self.writerInput = nil
            self.recordingURL = nil
            self.recordingStartTime = nil
            completion(url)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var captureSession: AVCaptureSession?
    var frameGrabber = FrameGrabber()
    var recordMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        print("Mister Mirror is getting ready... (this may take a few seconds)")
        enableScreenCaptureDevices()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startCapture()
        }
    }

    func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Mister Mirror", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Mister Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "s")
        fileMenu.addItem(NSMenuItem.separator())
        let recordItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "r")
        recordMenuItem = recordItem
        fileMenu.addItem(recordItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mister Mirror"
        alert.informativeText = "A dapper little app that mirrors your iPhone screen over USB.\n\nNo QuickTime needed \u{2014} just plug in and enjoy the show!"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func takeScreenshot() {
        guard let image = frameGrabber.takeScreenshot() else {
            let alert = NSAlert()
            alert.messageText = "No frame available"
            alert.informativeText = "Mister Mirror doesn't have a frame to capture yet. Is the iPhone connected?"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "MisterMirror-\(timestamp).png"

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let url = desktopURL.appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Failed to encode screenshot")
            return
        }

        do {
            try pngData.write(to: url)
            print("Screenshot saved: \(url.path)")
            // Brief flash effect on the window
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                self.window.animator().alphaValue = 0.5
            }, completionHandler: {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    self.window.animator().alphaValue = 1.0
                })
            })
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }

    @objc func toggleRecording() {
        if frameGrabber.isRecording {
            recordMenuItem?.title = "Start Recording"
            window.title = window.title.replacingOccurrences(of: " [REC]", with: "")
            frameGrabber.stopRecording { url in
                DispatchQueue.main.async {
                    if let url = url {
                        print("Recording saved: \(url.path)")
                    }
                }
            }
        } else {
            if frameGrabber.startRecording() {
                recordMenuItem?.title = "Stop Recording"
                window.title += " [REC]"
                print("Recording started...")
            } else {
                let alert = NSAlert()
                alert.messageText = "Recording failed"
                alert.informativeText = "Mister Mirror couldn't start recording. Is the iPhone connected?"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    func startCapture() {
        guard let device = findiPhoneDevice() else {
            let alert = NSAlert()
            alert.messageText = "Mister Mirror can't find your iPhone!"
            alert.informativeText = """
                I looked everywhere, but no iPhone in sight. Make sure:

                \u{2022} Your iPhone is connected via USB
                \u{2022} The iPhone is unlocked
                \u{2022} You have trusted this computer on the iPhone

                I'll keep looking if you'd like!
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Look Again")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.startCapture()
                }
            } else {
                NSApplication.shared.terminate(nil)
            }
            return
        }

        print("Mister Mirror found: \(device.localizedName)")

        let session = AVCaptureSession()
        session.sessionPreset = .high

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                fatalError("Cannot add iPhone as capture input")
            }
        } catch {
            fatalError("Failed to create capture input: \(error)")
        }

        // Video data output for screenshots and recording
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let queue = DispatchQueue(label: "com.mister-mirror.video", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(frameGrabber, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Preview layer for live display
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        let previewView = PreviewView()
        previewView.previewLayer = previewLayer

        let windowWidth: CGFloat = 390
        let windowHeight: CGFloat = 844

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mister Mirror \u{1F3A9} \(device.localizedName)"
        window.contentView = previewView
        window.contentAspectRatio = NSSize(width: windowWidth, height: windowHeight)
        window.center()
        window.makeKeyAndOrderFront(nil)

        session.startRunning()
        captureSession = session

        print("Mister Mirror is live! Enjoy the show.")
        print("  Cmd+S  Take screenshot")
        print("  Cmd+R  Start/stop recording")
        print("  Files saved to Desktop")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if frameGrabber.isRecording {
            frameGrabber.stopRecording { url in
                if let url = url {
                    print("Recording saved: \(url.path)")
                }
            }
        }
        captureSession?.stopRunning()
        print("Mister Mirror tips his hat goodbye.")
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
