import AppKit
import Foundation

/// Collects the machine facts shown on the dashboard and embedded in the
/// exported report.
enum SystemInfo {
    static func current() -> MachineInfo {
        let process = ProcessInfo.processInfo
        return MachineInfo(
            model: sysctlString("hw.model") ?? fallbackModel(),
            chip: sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon",
            osVersion: osVersionString(process),
            memory: formatBytes(Int64(process.physicalMemory)),
            processorCount: process.processorCount,
            displaySummary: displaySummary()
        )
    }

    static func summaryLines() -> [(String, String)] {
        let info = current()
        return [
            ("Model", info.model),
            ("Chip", info.chip),
            ("macOS", info.osVersion),
            ("Memory", info.memory),
            ("CPU cores", "\(info.processorCount)"),
            ("Display", info.displaySummary),
            ("Thermal state", thermalState()),
        ]
    }

    static func thermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    static func displaySummary() -> String {
        guard let screen = NSScreen.main else { return "No display detected" }
        let frame = screen.frame
        let backing = screen.backingScaleFactor
        let pixelsWide = Int(frame.width * backing)
        let pixelsHigh = Int(frame.height * backing)
        let refresh = screen.maximumFramesPerSecond
        return "\(pixelsWide) × \(pixelsHigh) @ \(refresh) Hz (\(Int(backing * 100))% scale)"
    }

    /// Localised macOS version, e.g. "macOS 26.5 (build 25F79)".
    static func osVersionString(_ process: ProcessInfo = .processInfo) -> String {
        let v = process.operatingSystemVersion
        var text = "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        if let build = sysctlString("kern.osversion") {
            text += " (build \(build))"
        }
        return text
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }

    private static func fallbackModel() -> String {
        // hw.model is always present on macOS, but keep a sane fallback so the
        // report never shows an empty field.
        sysctlString("hw.machine") ?? "Mac"
    }

    /// Reads a `sysctl` string by name, returning nil when the key is absent.
    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
