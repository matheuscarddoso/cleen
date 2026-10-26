import CoreGraphics
import Foundation

/// How a recording is dressed in the editor: what's behind it, how much room it gets,
/// its corners and shadow, the canvas shape, the cursor, the camera bubble and the zoom.
public struct EditorStyle: Codable, Sendable, Equatable {
    public enum Background: Codable, Sendable, Equatable {
        /// One of the editor's gradients, by index.
        case gradient(Int)
        /// A flat color, "#RRGGBB".
        case color(String)
        /// The Mac's own wallpaper at the time of the recording.
        case wallpaper
        /// A picture on disk: one of macOS's wallpapers or the person's own image.
        case picture(String)
        /// No background and no padding: the recording alone.
        case none
    }

    /// Where the screen and the camera go, Screen Studio's layouts.
    public enum Layout: String, Codable, Sendable, CaseIterable {
        /// The screen, with the camera in a corner.
        case standard
        /// The screen and the camera next to each other.
        case sideBySide
        /// Only the camera.
        case cameraOnly
    }

    public enum Aspect: String, Codable, Sendable, CaseIterable {
        /// The recording's own shape.
        case source
        case wide = "16:9"
        case vertical = "9:16"
        case square = "1:1"
        case classic = "4:3"

        /// Width over height; nil keeps the source's.
        public var ratio: Double? {
            switch self {
            case .source: nil
            case .wide: 16.0 / 9
            case .vertical: 9.0 / 16
            case .square: 1
            case .classic: 4.0 / 3
            }
        }
    }

    public struct Camera: Codable, Sendable, Equatable {
        public enum Corner: String, Codable, Sendable, CaseIterable {
            case topLeft, topRight, bottomLeft, bottomRight
        }

        public enum Shape: String, Codable, Sendable, CaseIterable {
            /// A square with Screen Studio's squircle corners (see `Squircle`).
            case rounded
            case circle
            /// The camera's own shape, barely rounded.
            case square
        }

        public var isVisible = true
        public var corner = Corner.bottomRight
        /// The bubble's height as a share of the canvas height.
        public var size = 0.26
        public var shape = Shape.rounded

        public init() {}
    }

    public var background = Background.gradient(0)
    /// 0 is sharp; 1 the softest.
    public var backgroundBlur = 0.0
    public var layout = Layout.standard
    /// Room around the recording, as a share of the canvas's shorter side.
    public var padding = 0.07
    /// Corner radius as a share of the recording's shorter side on the canvas.
    public var roundness = 0.025
    /// 0 is flat; 1 the deepest shadow.
    public var shadow = 0.6
    public var aspect = Aspect.wide
    public var showsCursor = true
    /// The drawn cursor's size against the real one.
    public var cursorSize = 1.6
    /// 0 follows the pointer exactly; 1 glides the most.
    public var cursorSmoothing = 0.65
    /// A soft ring where the pointer clicked.
    public var showsClicks = true
    public var camera = Camera()
    /// Zoom in where the person clicked; segments can still be edited by hand.
    public var autoZoom = true
    public var zoomScale = 2.0
    public var mutesMicrophone = false
    public var mutesSystemAudio = false

    public init() {}

    /// A style saved by an earlier version opens too: what it lacks takes its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = EditorStyle()
        background = try c.decodeIfPresent(Background.self, forKey: .background) ?? d.background
        backgroundBlur = try c.decodeIfPresent(Double.self, forKey: .backgroundBlur) ?? d.backgroundBlur
        layout = try c.decodeIfPresent(Layout.self, forKey: .layout) ?? d.layout
        padding = try c.decodeIfPresent(Double.self, forKey: .padding) ?? d.padding
        roundness = try c.decodeIfPresent(Double.self, forKey: .roundness) ?? d.roundness
        shadow = try c.decodeIfPresent(Double.self, forKey: .shadow) ?? d.shadow
        aspect = try c.decodeIfPresent(Aspect.self, forKey: .aspect) ?? d.aspect
        showsCursor = try c.decodeIfPresent(Bool.self, forKey: .showsCursor) ?? d.showsCursor
        cursorSize = try c.decodeIfPresent(Double.self, forKey: .cursorSize) ?? d.cursorSize
        cursorSmoothing = try c.decodeIfPresent(Double.self, forKey: .cursorSmoothing) ?? d.cursorSmoothing
        showsClicks = try c.decodeIfPresent(Bool.self, forKey: .showsClicks) ?? d.showsClicks
        camera = try c.decodeIfPresent(Camera.self, forKey: .camera) ?? d.camera
        autoZoom = try c.decodeIfPresent(Bool.self, forKey: .autoZoom) ?? d.autoZoom
        zoomScale = try c.decodeIfPresent(Double.self, forKey: .zoomScale) ?? d.zoomScale
        mutesMicrophone = try c.decodeIfPresent(Bool.self, forKey: .mutesMicrophone) ?? d.mutesMicrophone
        mutesSystemAudio = try c.decodeIfPresent(Bool.self, forKey: .mutesSystemAudio) ?? d.mutesSystemAudio
    }

    /// No background means no padding either: the recording is the whole frame.
    public var effectivePadding: Double {
        if case .none = background { return 0 }
        return padding
    }
}

public struct ExportOptions: Codable, Sendable, Equatable {
    public enum Resolution: String, Codable, Sendable, CaseIterable {
        case hd = "720p"
        case fullHD = "1080p"
        case ultraHD = "4K"

        /// The canvas's longer side.
        public var longSide: Double {
            switch self {
            case .hd: 1280
            case .fullHD: 1920
            case .ultraHD: 3840
            }
        }
    }

    public var resolution = Resolution.fullHD
    public var framesPerSecond = 60

    public init() {}
}
