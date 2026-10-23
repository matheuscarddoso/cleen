import AppKit
import Observation

/// Knows which screens have an app in full screen, so the closed notch can step aside
/// during a film or a presentation. Checked when the frontmost app or the Space
/// changes, never polled.
@Observable
final class FullscreenWatcher {
    private(set) var screens: Set<CGDirectDisplayID> = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // The Space animation finishes after the notification; look once it has.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    self?.check()
                }
            })
        }
        check()
    }

    func isFullscreen(_ screen: NSScreen) -> Bool {
        screen.displayID.map(screens.contains) ?? false
    }

    private func check() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let mainHeight = NSScreen.screens.first?.frame.height
        else {
            if !screens.isEmpty { screens = [] }
            return
        }
        // A zoomed window covers as much as a full-screen one on a notched display; what
        // tells them apart is the menu bar, which full screen takes away.
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        let menuBars = windows.compactMap { window -> CGRect? in
            guard window[kCGWindowLayer as String] as? Int == menuLevel,
                  let bounds = window[kCGWindowBounds as String] as? [String: Double]
            else { return nil }
            return CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
        }
        var found = Set<CGDirectDisplayID>()
        for window in windows {
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Double]
            else { continue }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            for screen in NSScreen.screens {
                // Window bounds are top-left based; a full-screen window spans the whole
                // width and everything under the camera housing.
                let frame = screen.frame
                let top = mainHeight - frame.maxY
                let covers = abs(rect.minX - frame.minX) < 1 && abs(rect.width - frame.width) < 1
                    && rect.minY <= top + screen.safeAreaInsets.top + 1
                    && rect.height >= frame.height - screen.safeAreaInsets.top - 1
                let strip = CGRect(x: frame.minX, y: top, width: frame.width, height: 4)
                let hasMenuBar = menuBars.contains { $0.intersects(strip) }
                if covers, !hasMenuBar, let id = screen.displayID { found.insert(id) }
            }
        }
        if found != screens { screens = found }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
