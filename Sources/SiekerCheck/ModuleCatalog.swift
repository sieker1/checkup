import Foundation

/// Every screen in the sidebar. `id` doubles as the stable key used to persist
/// that check's pass/fail result.
enum CheckModule: String, CaseIterable, Identifiable {
    case dashboard
    case display
    case speakers
    case microphone
    case camera
    case keyboard
    case trackpad
    case battery
    case storage
    case haptics
    case connectivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Overview"
        case .display: "Display & pixels"
        case .speakers: "Speakers"
        case .microphone: "Microphone"
        case .camera: "Camera"
        case .keyboard: "Keyboard"
        case .trackpad: "Trackpad & Force Touch"
        case .battery: "Battery & power"
        case .storage: "Ports & storage"
        case .haptics: "Haptics"
        case .connectivity: "Connectivity"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .display: "display"
        case .speakers: "speaker.wave.2"
        case .microphone: "mic"
        case .camera: "camera"
        case .keyboard: "keyboard"
        case .trackpad: "rectangle.and.hand.point.up.left.filled"
        case .battery: "battery.100"
        case .storage: "externaldrive"
        case .haptics: "hand.tap"
        case .connectivity: "wifi"
        }
    }

    var blurb: String {
        switch self {
        case .dashboard: "Machine summary, the pass/fail checklist, and export."
        case .display: "Dead and stuck pixels, backlight bleed and banding."
        case .speakers: "Channel separation, frequency sweep and balance."
        case .microphone: "Live level meter, record and play back."
        case .camera: "Live preview and capture-device readout."
        case .keyboard: "Light up every key and find dead ones."
        case .trackpad: "Touch count, pressure and drag tracking."
        case .battery: "Cycle count, health and charge state."
        case .storage: "Mounted volumes and a read/write speed test."
        case .haptics: "Fire the Force Touch feedback patterns."
        case .connectivity: "Network interfaces and their addresses."
        }
    }

    /// The checks that make it onto the exported report, in sidebar order.
    static var reportable: [CheckModule] {
        allCases.filter { $0 != .dashboard }
    }

    var initialCheckResult: CheckResult {
        CheckResult(id: id, title: title)
    }
}
