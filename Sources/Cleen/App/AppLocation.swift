import AppKit

/// Makes sure Cleen runs from Aplicativos. Opened straight from the DMG, or from
/// Downloads while still quarantined, macOS runs it from a read-only copy at a random
/// path (App Translocation): the login item would point at a path that's gone after a
/// restart, and the disk would stay mounted. So the first thing it does is offer to
/// move itself.
enum AppLocation {
    static let destination = URL(filePath: "/Applications/Cleen.app")

    static var needsMove: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/AppTranslocation/") || path.hasPrefix("/Volumes/")
    }

    /// Asks once, then copies the app to Aplicativos and reopens it from there. Returns
    /// false when the person chose to keep running it where it is.
    @discardableResult
    static func offerMove() -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Mover o Cleen para Aplicativos?"
        alert.informativeText = "Aberto daqui, o Cleen some quando o disco for ejetado e não consegue abrir junto com o Mac."
        alert.addButton(withTitle: "Mover para Aplicativos")
        alert.addButton(withTitle: "Agora não")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        do {
            try move()
        } catch {
            let failure = NSAlert()
            failure.messageText = "Não deu para mover o Cleen"
            failure.informativeText = "Arraste o Cleen para a pasta Aplicativos e abra por lá. (\(error.localizedDescription))"
            failure.runModal()
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    private static func move() throws {
        let files = FileManager.default
        // An older Cleen goes to the Lixo rather than being overwritten in place.
        if files.fileExists(atPath: destination.path) {
            try files.trashItem(at: destination, resultingItemURL: nil)
        }
        try files.copyItem(at: Bundle.main.bundleURL, to: destination)
        // The person already chose to open this copy; without the quarantine flag the
        // one in Aplicativos isn't translocated all over again.
        let xattr = Process()
        xattr.executableURL = URL(filePath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", destination.path]
        try xattr.run()
        xattr.waitUntilExit()
    }
}
