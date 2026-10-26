import AppKit
import AVFoundation
import SwiftUI

/// The windows a recording puts on screen: a dim around the recorded area, the countdown,
/// the camera preview, and a copy of the wallpaper that covers the desktop icons. All but
/// the cover are left out of the recording.
final class RecorderOverlays {
    private var highlight: [OverlayWindow] = []
    private var covers: [OverlayWindow] = []
    private var countdown: OverlayWindow?
    private var camera: OverlayWindow?
    private weak var cameraSession: AVCaptureSession?

    /// Window numbers of the covers, which must stay in the recording.
    var coverWindowNumbers: Set<Int> { Set(covers.map(\.windowNumber)) }

    /// Dims everything outside `rect` (global points, top-left origin).
    func showHighlight(_ rect: CGRect) {
        hideHighlight()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let local = CGRect(x: rect.minX - screen.frame.minX, y: rect.minY - (primaryHeight - screen.frame.maxY), width: rect.width, height: rect.height)
            let window = OverlayWindow(frame: screen.frame, level: .floating, ignoresMouse: true, content: HighlightView(hole: local))
            window.orderFrontRegardless()
            highlight.append(window)
        }
    }

    func hideHighlight() {
        highlight.forEach { $0.orderOut(nil) }
        highlight = []
    }

    /// The wallpaper laid over the desktop icons, one level above them.
    func coverDesktopIcons() {
        uncoverDesktopIcons()
        for screen in NSScreen.screens {
            guard let url = NSWorkspace.shared.desktopImageURL(for: screen), let image = NSImage(contentsOf: url) else { continue }
            let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            let window = OverlayWindow(frame: screen.frame, level: level, ignoresMouse: true, content: Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).ignoresSafeArea())
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.orderFrontRegardless()
            covers.append(window)
        }
    }

    func uncoverDesktopIcons() {
        covers.forEach { $0.orderOut(nil) }
        covers = []
    }

    /// 3, 2, 1 in the middle of `screen`.
    func showCountdown(_ value: Int, on screen: NSScreen) {
        if countdown == nil {
            let size = CGSize(width: 180, height: 180)
            let frame = CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2, width: size.width, height: size.height)
            countdown = OverlayWindow(frame: frame, level: .screenSaver, ignoresMouse: true, content: CountdownView(value: value))
            countdown?.orderFrontRegardless()
        } else {
            countdown?.contentView = NSHostingView.filling(CountdownView(value: value))
        }
    }

    func hideCountdown() {
        countdown?.orderOut(nil)
        countdown = nil
    }

    /// The camera in a round window at the bottom right of `screen`, to check framing.
    func showCamera(session: AVCaptureSession, on screen: NSScreen) {
        // Already up for this camera: left where the person dragged it.
        if camera != nil, cameraSession === session { return }
        hideCamera()
        cameraSession = session
        let side = 180.0
        let frame = CGRect(x: screen.visibleFrame.maxX - side - 24, y: screen.visibleFrame.minY + 24, width: side, height: side)
        let window = OverlayWindow(frame: frame, level: .floating, ignoresMouse: false, content: RecorderCameraPreview(session: session))
        window.isMovableByWindowBackground = true
        window.isMovable = true
        window.orderFrontRegardless()
        camera = window
    }

    func hideCamera() {
        camera?.orderOut(nil)
        camera = nil
        cameraSession = nil
    }

    func hideAll() {
        hideHighlight()
        uncoverDesktopIcons()
        hideCountdown()
        hideCamera()
    }
}

private struct HighlightView: View {
    let hole: CGRect

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: 4, height: 4))
            }
            .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
        }
        .ignoresSafeArea()
    }
}

private struct CountdownView: View {
    let value: Int

    var body: some View {
        Text(verbatim: "\(value)")
            .font(.system(size: 96, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 180, height: 180)
            .background(.black.opacity(0.72), in: .rect(cornerRadius: 40, style: .continuous))
            .contentTransition(.numericText(countsDown: true))
    }
}

private struct RecorderCameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        // A mirror, like the camera on a call.
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        view.layer = CALayer()
        view.layer?.addSublayer(layer)
        view.layer?.cornerRadius = 90
        view.layer?.masksToBounds = true
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        view.layer?.borderWidth = 2
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
