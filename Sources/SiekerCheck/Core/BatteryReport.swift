import Foundation

/// Raw battery figures read out of the `AppleSmartBattery` IORegistry node,
/// normalised so they can be formatted and tested without IOKit present.
struct BatterySnapshot: Equatable {
    var cycleCount: Int?
    var designCapacity: Int?
    var fullChargeCapacity: Int?
    var currentCapacityPercent: Int?
    var temperatureCelsius: Double?
    var isCharging: Bool?
    var isPluggedIn: Bool?
    var timeRemainingMinutes: Int?

    var healthPercent: Double? {
        guard let design = designCapacity, design > 0,
              let full = fullChargeCapacity else { return nil }
        return Double(full) / Double(design) * 100
    }

    /// Apple's own service threshold is 80% of design capacity.
    var healthVerdict: String {
        guard let health = healthPercent else { return "Unknown" }
        if health >= 90 { return "Excellent" }
        if health >= 80 { return "Serviceable" }
        return "Service recommended"
    }
}

enum BatteryReport {
    static func lines(for snapshot: BatterySnapshot) -> [String] {
        var lines: [String] = []
        if let cycles = snapshot.cycleCount {
            lines.append("Cycle count: \(cycles)")
        }
        if let health = snapshot.healthPercent {
            lines.append(String(format: "Health: %.1f%% (%@)", health, snapshot.healthVerdict))
        }
        if let design = snapshot.designCapacity, let full = snapshot.fullChargeCapacity {
            lines.append("Capacity: \(full) mAh of \(design) mAh design")
        }
        if let charge = snapshot.currentCapacityPercent {
            lines.append("Current charge: \(charge)%")
        }
        if let temperature = snapshot.temperatureCelsius {
            lines.append(String(format: "Battery temperature: %.1f °C", temperature))
        }
        if let plugged = snapshot.isPluggedIn {
            lines.append("Power: \(plugged ? "connected to power" : "on battery")")
        }
        if let charging = snapshot.isCharging, snapshot.isPluggedIn == true {
            lines.append("Charging: \(charging ? "yes" : "no (held at limit)" )")
        }
        if let minutes = snapshot.timeRemainingMinutes, minutes > 0 {
            lines.append("Time remaining: \(minutes / 60)h \(minutes % 60)m")
        }
        return lines
    }

    /// Cycle count at which Apple considers a MacBook battery consumed.
    static let designCycleCount = 1000

    static func cycleVerdict(cycleCount: Int) -> String {
        let used = Double(cycleCount) / Double(designCycleCount) * 100
        return String(format: "%.0f%% of the 1000-cycle design life used", used)
    }
}
