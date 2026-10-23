import CoreGraphics
import Foundation

/// The Mac's own screen, through DisplayServices (the framework behind the brightness
/// keys). It's private, so it's looked up at run time and simply absent if it moves.
public enum BuiltInBrightness {
    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getter = framework.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: Getter.self) }
    private static let setter = framework.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: Setter.self) }

    /// 0...1, or nil when the display has no adjustable backlight.
    public static func get(_ display: CGDirectDisplayID) -> Double? {
        guard let getter else { return nil }
        var value: Float = 0
        return getter(display, &value) == 0 ? Double(value) : nil
    }

    @discardableResult
    public static func set(_ value: Double, for display: CGDirectDisplayID) -> Bool {
        setter?(display, Float(min(1, max(0, value)))) == 0
    }
}
