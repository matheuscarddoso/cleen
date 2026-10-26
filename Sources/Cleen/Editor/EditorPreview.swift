import AVFoundation
import SwiftUI

/// The player's picture, fitted to its box.
struct EditorPreview: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerHost {
        PlayerHost(player: player)
    }

    func updateNSView(_ view: PlayerHost, context: Context) {}

    final class PlayerHost: NSView {
        private let playerLayer: AVPlayerLayer

        init(player: AVPlayer) {
            playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            wantsLayer = true
            layer = CALayer()
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
