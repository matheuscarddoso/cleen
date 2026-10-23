import AppKit
import CleenKit
import Observation

/// Every screen's brightness, set from Ajustes › Telas: the Mac's own through
/// DisplayServices, external monitors over the cable (DDC), and, for monitors that
/// don't answer, by dimming the picture.
@Observable
final class DisplaysModel {
    struct Item: Identifiable, Equatable {
        enum Control: Equatable {
            case builtIn
            case cable(maximum: Int)
            case dimming
        }

        let id: CGDirectDisplayID
        let name: String
        let control: Control
        var brightness: Double
    }

    private(set) var items: [Item] = []
    private(set) var isLoading = false

    @ObservationIgnored private var ports: [CGDirectDisplayID: DDC.Port] = [:]
    @ObservationIgnored private let writer = BrightnessWriter()
    private static let dimmingKey = "displayDimming"

    /// Puts back the dimming chosen for monitors without DDC (the gamma resets when
    /// Cleen quits).
    func restoreDimming() {
        let saved = UserDefaults.standard.dictionary(forKey: Self.dimmingKey) as? [String: Double] ?? [:]
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let level = saved[screen.localizedName], level < 1 else { continue }
            ScreenDimming.apply(level, to: id)
        }
    }

    /// Reads every screen. External monitors take ~100 ms to answer, so it runs off the
    /// main thread and the rows show up together.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let screens = NSScreen.screens.compactMap { screen in screen.displayID.map { (id: $0, name: screen.localizedName) } }
        let saved = UserDefaults.standard.dictionary(forKey: Self.dimmingKey) as? [String: Double] ?? [:]

        let found = await offMain { () -> [(Item, DDC.Port?)] in
            let ports = DDC.ports()
            let externals = screens.filter { CGDisplayIsBuiltin($0.id) == 0 }
            return screens.map { screen in
                if CGDisplayIsBuiltin(screen.id) != 0 {
                    let level = BuiltInBrightness.get(screen.id) ?? 1
                    return (Item(id: screen.id, name: screen.name, control: .builtIn, brightness: level), nil)
                }
                // Matched by the name the monitor reports; with a single monitor and a
                // single port they're each other's even if the names differ.
                let port = ports.first { $0.productName == screen.name }
                    ?? (externals.count == 1 && ports.count == 1 ? ports.first : nil)
                if let port, let reading = DDC.read(DDC.brightness, from: port) {
                    let level = Double(reading.current) / Double(reading.maximum)
                    return (Item(id: screen.id, name: screen.name, control: .cable(maximum: reading.maximum), brightness: level), port)
                }
                return (Item(id: screen.id, name: screen.name, control: .dimming, brightness: saved[screen.name] ?? 1), nil)
            }
        }
        ports = Dictionary(uniqueKeysWithValues: found.compactMap { item, port in port.map { (item.id, $0) } })
        items = found.map(\.0)
    }

    func setBrightness(_ level: Double, for id: CGDirectDisplayID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        let level = item.control == .dimming ? max(ScreenDimming.minimum, min(1, level)) : min(1, max(0, level))
        items[index].brightness = level
        switch item.control {
        case .builtIn:
            writer.submit(id) { BuiltInBrightness.set(level, for: id) }
        case .cable(let maximum):
            guard let port = ports[id] else { return }
            let value = Int((level * Double(maximum)).rounded())
            writer.submit(id) { DDC.write(DDC.brightness, value: value, to: port) }
        case .dimming:
            ScreenDimming.apply(level, to: id)
            var saved = UserDefaults.standard.dictionary(forKey: Self.dimmingKey) as? [String: Double] ?? [:]
            saved[item.name] = level
            UserDefaults.standard.set(saved, forKey: Self.dimmingKey)
        }
    }
}
