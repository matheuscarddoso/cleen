import AVFoundation
import SwiftUI

/// Hosts the mirror's shared preview layer, mirrored like a real mirror.
struct CameraPreview: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(preview: layer)
    }

    func updateNSView(_ view: CameraPreviewView, context: Context) {
        view.claim()
    }
}

final class CameraPreviewView: NSView {
    private let preview: AVCaptureVideoPreviewLayer

    init(preview: AVCaptureVideoPreviewLayer) {
        self.preview = preview
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Clicks go to the SwiftUI button around the preview, not to this layer host.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { claim() }
    }

    override func layout() {
        super.layout()
        claim()
    }

    /// Moves the shared layer into this view (the newest view on screen wins).
    func claim() {
        guard let host = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if preview.superlayer !== host { host.addSublayer(preview) }
        preview.frame = bounds
        if let connection = preview.connection, connection.isVideoMirroringSupported, !connection.isVideoMirrored {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        CATransaction.commit()
    }
}
