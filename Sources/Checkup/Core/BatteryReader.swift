import Foundation
import IOKit

/// Reads the `AppleSmartBattery` IORegistry node. The node uses slightly
/// different keys across generations, so each field falls back through the
/// names Apple has used.
enum BatteryReader {
    static func read() -> BatterySnapshot? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }

        return parse(dictionary)
    }

    /// Split out from the IOKit call so the mapping can be tested directly.
    static func parse(_ dictionary: [String: Any]) -> BatterySnapshot {
        let batteryData = dictionary["BatteryData"] as? [String: Any] ?? [:]
        var snapshot = BatterySnapshot()
        snapshot.cycleCount = integer(dictionary["CycleCount"])
        snapshot.currentCapacityPercent = integer(dictionary["CurrentCapacity"]) ?? integer(dictionary["StateOfCharge"])
        snapshot.designCapacity = integer(batteryData["DesignCapacity"]) ?? integer(batteryData["NominalChargeCapacity"])
        snapshot.fullChargeCapacity = integer(batteryData["FullChargeCapacity"])
        if let raw = integer(dictionary["Temperature"]) {
            // The SMC reports temperature in hundredths of a degree Celsius.
            snapshot.temperatureCelsius = Double(raw) / 100
        }
        snapshot.isCharging = boolean(dictionary["IsCharging"])
        snapshot.isPluggedIn = boolean(dictionary["ExternalConnected"])
        snapshot.timeRemainingMinutes = integer(dictionary["TimeRemaining"]) ?? integer(dictionary["AvgTimeToEmpty"])
        return snapshot
    }

    static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    static func boolean(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }
}
