import AppKit
import CleenKit

/// The icon of the browser tab that's playing, for media pages that send no artwork of
/// their own (a WhatsApp Web voice note, a podcast player). Browsers fill that gap
/// with a generic engine logo, which says nothing about what's playing.
///
/// Finds the tab by its title through the browser's AppleScript dictionary, then asks
/// that same site for its icon. Nothing goes to a third party.
enum BrowserTabIcon {
    /// Browsers whose tabs expose a title (`name` in Safari) and a URL to AppleScript.
    static let browsers: [String: String] = [
        "company.thebrowser.dia": "title",
        "company.thebrowser.Browser": "title",
        "com.google.Chrome": "title",
        "com.brave.Browser": "title",
        "com.microsoft.edgemac": "title",
        "com.vivaldi.Vivaldi": "title",
        "com.operasoftware.Opera": "title",
        "com.apple.Safari": "name",
    ]

    static func isBrowser(_ bundleID: String?) -> Bool {
        bundleID.map { browsers[$0] != nil } ?? false
    }

    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor
    static func icon(bundleID: String, tabTitle: String) async -> NSImage? {
        guard let titleProperty = browsers[bundleID],
              let host = await tabHost(bundleID: bundleID, titleProperty: titleProperty, title: tabTitle)
        else { return nil }
        if let cached = cache[host] { return cached }
        for path in ["/apple-touch-icon.png", "/apple-touch-icon-precomposed.png", "/favicon.ico"] {
            guard let url = URL(string: "https://\(host)\(path)"),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = NSImage(data: data), image.isValid
            else { continue }
            cache[host] = image
            return image
        }
        return nil
    }

    /// `web.whatsapp.com` for the tab titled "(1) WhatsApp".
    private static func tabHost(bundleID: String, titleProperty: String, title: String) async -> String? {
        let escaped = title.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
        let script = """
        tell application id "\(bundleID)"
            repeat with w in windows
                repeat with t in tabs of w
                    if \(titleProperty) of t is "\(escaped)" then return URL of t
                end repeat
            end repeat
        end tell
        return ""
        """
        guard let result = try? await Shell.run("/usr/bin/osascript", ["-e", script]), result.succeeded else { return nil }
        let link = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: link)?.host()
    }
}
