import CoreGraphics
import Foundation

/// Which of the files one screenshot made belongs to a given display.
///
/// ⌘⇧3 with two displays writes one file per display, a second apart at most. The screenshot
/// service tags each with `kMDItemScreenCaptureGlobalRect`: the area it covers, in global
/// display coordinates (origin at the top-left of the main display, y growing down). The
/// notch opens on one display; the capture of that display is the one to show there.
public enum ScreenCapturePicker {
    /// The xattr's value: a binary property list holding `[x, y, width, height]`.
    public static func globalRect(fromAttribute data: Data) -> CGRect? {
        guard let values = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [NSNumber],
              values.count == 4
        else { return nil }
        let rect = CGRect(x: values[0].doubleValue, y: values[1].doubleValue, width: values[2].doubleValue, height: values[3].doubleValue)
        return rect.width > 0 && rect.height > 0 ? rect : nil
    }

    /// A screen's AppKit frame (origin bottom-left of the main display, y up) in global
    /// display coordinates.
    public static func globalRect(ofScreenFrame frame: CGRect, mainScreenHeight: Double) -> CGRect {
        CGRect(x: frame.minX, y: mainScreenHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// The index of the capture that covers most of `display`, or nil when none touches it
    /// (or a capture has no rect to tell).
    public static func index(for display: CGRect, among rects: [CGRect?]) -> Int? {
        var best: (index: Int, area: Double)?
        for (index, rect) in rects.enumerated() {
            guard let rect else { continue }
            let overlap = rect.intersection(display)
            guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { continue }
            let area = Double(overlap.width * overlap.height)
            if area > best?.area ?? 0 { best = (index, area) }
        }
        return best?.index
    }
}
