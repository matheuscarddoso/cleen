import AppKit

/// Decides which screens get a notch (the built-in one, or every screen when the
/// person asks for it), rebuilds them when displays change, and owns the shortcut.
final class NotchCoordinator {
    private unowned let app: AppModel
    private(set) var controllers: [NotchController] = []
    private var hotKey: GlobalHotKey?
    private var observers: [NSObjectProtocol] = []
    private var showsOnAllScreens = NotchSettings.showsOnAllScreens

    init(app: AppModel) {
        self.app = app
        NotchSettings.register()
    }

    /// The notch on the built-in display (or the main screen when there is none).
    var primary: NotchController? { controllers.first }

    func install() {
        guard hotKey == nil else { return }
        rebuild()
        hotKey = GlobalHotKey.standard { [weak self] in self?.toggleUnderPointer() }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsChanged() }
        })
    }

    func open(tab: NotchTab? = nil) {
        (controllerUnderPointer ?? primary)?.open(tab: tab)
    }

    func openSettings() {
        (controllerUnderPointer ?? primary)?.openSettings()
    }

    func toggleUnderPointer() {
        (controllerUnderPointer ?? primary)?.toggle()
    }

    // MARK: Screens

    private var controllerUnderPointer: NotchController? {
        let location = NSEvent.mouseLocation
        return controllers.first { $0.screen.frame.contains(location) }
    }

    private func settingsChanged() {
        let wanted = NotchSettings.showsOnAllScreens
        guard wanted != showsOnAllScreens else { return }
        showsOnAllScreens = wanted
        rebuild()
    }

    private func rebuild() {
        controllers.forEach { $0.uninstall() }
        controllers = Self.screens(all: showsOnAllScreens).map { screen in
            let controller = NotchController(app: app, screen: screen)
            controller.install()
            return controller
        }
    }

    /// The display with a camera notch first (it hosts the real one), then the rest.
    static func screens(all: Bool) -> [NSScreen] {
        let notched = NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
        let others = NSScreen.screens.filter { $0.safeAreaInsets.top == 0 }
        if all { return notched + others }
        if let first = notched.first { return [first] }
        return [NSScreen.main ?? NSScreen.screens[0]]
    }
}
