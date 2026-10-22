import Foundation
import Testing
@testable import LustroKit

@Suite(.enabled(if: ProcessInfo.processInfo.environment["LUSTRO_PROBE"] != nil))
struct TimingProbe {
    @Test func probe() async {
        let clock = ContinuousClock()
        var t = clock.now
        func lap(_ label: String) { print("PROBE \(label): \(clock.now - t)"); t = clock.now }
        for category in JunkCatalog.all {
            let results = await JunkScanner(catalog: [category]).scan()
            lap("junk \(category.id) \(results.first?.totalSize ?? 0)")
        }
        _ = await DockerCleaner.inspect(); lap("docker")
        _ = await SimulatorCleaner.inspect(); lap("simulators")
        _ = await LaunchItemScanner.loadedLabels(domain: "gui/\(getuid())"); lap("launchctl gui")
        _ = await LaunchItemScanner.loadedLabels(domain: "system"); lap("launchctl system")
        _ = await LaunchControl.disabledLabels(scope: .user); lap("disabled user")
        _ = await LaunchControl.disabledLabels(scope: .system); lap("disabled system")
        let items = await LaunchItemScanner().scan(); lap("launch items \(items.count)")
    }
}
