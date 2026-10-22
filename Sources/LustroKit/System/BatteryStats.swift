import Foundation
import IOKit
import IOKit.ps

public struct BatteryStats: Sendable, Equatable {
    /// 0...1
    public let level: Double
    public let isCharging: Bool
    public let isPluggedIn: Bool
    /// Minutes until empty while discharging; nil while macOS is still estimating.
    public let minutesRemaining: Int?
    public let cycleCount: Int?
    /// Current full-charge capacity relative to the design capacity, 0...1.
    public let health: Double?
    public let temperatureCelsius: Double?

    /// nil on Macs without a battery.
    public static func read() -> BatteryStats? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }

            let pluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let minutes = description[kIOPSTimeToEmptyKey] as? Int
            let registry = smartBatteryProperties()

            let health: Double? = {
                guard let design = registry["DesignCapacity"] as? Int, design > 0,
                      let full = (registry["AppleRawMaxCapacity"] as? Int) ?? (registry["NominalChargeCapacity"] as? Int)
                else { return nil }
                return min(1, Double(full) / Double(design))
            }()

            return BatteryStats(
                level: Double(current) / Double(maximum),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: pluggedIn,
                minutesRemaining: (minutes ?? -1) > 0 && !pluggedIn ? minutes : nil,
                cycleCount: registry["CycleCount"] as? Int,
                health: health,
                // Reported in hundredths of a degree.
                temperatureCelsius: (registry["Temperature"] as? Int).map { Double($0) / 100 }
            )
        }
        return nil
    }

    private static func smartBatteryProperties() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return [:] }
        return properties?.takeRetainedValue() as? [String: Any] ?? [:]
    }
}
