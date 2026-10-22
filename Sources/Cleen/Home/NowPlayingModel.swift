import AppKit
import CoreImage
import Observation

/// Whatever the Mac is playing — a YouTube tab, Spotify, Music, a podcast — read from
/// the system's Now Playing through `NowPlayingBridge`.
@Observable
final class NowPlayingModel {
    private(set) var track: NowPlayingTrack?
    private(set) var artwork: NSImage?
    /// Dark tint pulled from the artwork for the card's background.
    private(set) var tint: NSColor?
    /// The app playing it, for its name and icon.
    private(set) var appName: String?
    private(set) var appURL: URL?

    @ObservationIgnored private let bridge = NowPlayingBridge()
    @ObservationIgnored private var isStreaming = false

    /// Starts listening the first time someone shows Now Playing; the helper is
    /// event-driven and nearly free, so it then keeps running.
    func watch() async {
        guard !isStreaming else { return }
        isStreaming = true
        bridge.start { [weak self] json in
            let reading = NowPlayingTrack(json: json)
            let artworkData = (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
            Task { @MainActor in self?.apply(reading, artworkData: artworkData) }
        }
    }

    func position(at date: Date) -> TimeInterval {
        track?.position(at: date) ?? 0
    }

    func send(_ command: NowPlayingCommand) async {
        // Flip the button right away; the stream confirms (or corrects) a moment later.
        if command == .playPause, let track {
            self.track = track.toggled()
        }
        await NowPlayingBridge.send(command)
    }

    private func apply(_ reading: NowPlayingTrack?, artworkData: Data?) {
        guard let reading else {
            track = nil
            artwork = nil
            tint = nil
            appName = nil
            appURL = nil
            return
        }
        if reading.pid != track?.pid {
            let app = NSRunningApplication(processIdentifier: reading.pid)
            appName = app?.localizedName
            appURL = app?.bundleURL
        }
        if let artworkData, let image = NSImage(data: artworkData) {
            artwork = image
            tint = Self.averageColor(of: image)
        } else if reading.artworkKey == nil, reading.identity != track?.identity {
            // A new item without artwork; an update of the same item without it
            // (players omit it while paused) keeps the one already shown.
            artwork = nil
            tint = nil
        }
        track = reading
    }

    private static func averageColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation, let input = CIImage(data: tiff) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ])
        guard let output = filter?.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return NSColor(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255, alpha: 1)
    }
}
