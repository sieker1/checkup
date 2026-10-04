import Foundation

/// Result of running one hardware check.
enum CheckStatus: String, Codable, CaseIterable {
    case untested = "Untested"
    case pass = "Pass"
    case fail = "Fail"
    case notApplicable = "N/A"

    var symbol: String {
        switch self {
        case .untested: "questionmark.circle"
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .notApplicable: "minus.circle"
        }
    }
}

/// One row of the report: which check, how it went, and any free-text note.
struct CheckResult: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    var status: CheckStatus
    var note: String

    init(id: String, title: String, status: CheckStatus = .untested, note: String = "") {
        self.id = id
        self.title = title
        self.status = status
        self.note = note
    }
}

/// Machine facts printed at the top of the report.
struct MachineInfo: Equatable {
    var model: String
    var chip: String
    var osVersion: String
    var memory: String
    var processorCount: Int
    var displaySummary: String

    static let unknown = MachineInfo(
        model: "Unknown Mac",
        chip: "Unknown",
        osVersion: "Unknown",
        memory: "Unknown",
        processorCount: 0,
        displaySummary: "Unknown"
    )
}

enum ReportBuilder {
    static func counts(_ results: [CheckResult]) -> (passed: Int, failed: Int, untested: Int) {
        var passed = 0, failed = 0, untested = 0
        for result in results {
            switch result.status {
            case .pass: passed += 1
            case .fail: failed += 1
            case .untested, .notApplicable: untested += 1
            }
        }
        return (passed, failed, untested)
    }

    static func headline(_ results: [CheckResult]) -> String {
        let tally = counts(results)
        if tally.failed > 0 { return "\(tally.failed) check\(tally.failed == 1 ? "" : "s") failed" }
        if tally.untested == 0 { return "All checks passed" }
        return "\(tally.passed) passed, \(tally.untested) untested"
    }

    static func markdown(machine: MachineInfo, results: [CheckResult], date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        var out = "# Checkup report\n\n"
        out += "- **Model:** \(machine.model)\n"
        out += "- **Chip:** \(machine.chip)\n"
        out += "- **macOS:** \(machine.osVersion)\n"
        out += "- **Memory:** \(machine.memory)\n"
        out += "- **CPU cores:** \(machine.processorCount)\n"
        out += "- **Display:** \(machine.displaySummary)\n"
        out += "- **Generated:** \(formatter.string(from: date))\n\n"
        out += "**\(headline(results))**\n\n"
        out += "| Check | Result | Notes |\n"
        out += "| --- | --- | --- |\n"
        for result in results {
            let note = result.note.replacingOccurrences(of: "|", with: "\\|")
            out += "| \(result.title) | \(result.status.rawValue) | \(note) |\n"
        }
        return out
    }
}

/// Persists and restores the checklist. Kept separate from `UserDefaults` so
/// the round-trip can be tested headlessly.
enum ProgressCodec {
    static func encode(_ results: [CheckResult]) -> Data {
        (try? JSONEncoder().encode(results)) ?? Data()
    }

    static func decode(_ data: Data) -> [CheckResult] {
        (try? JSONDecoder().decode([CheckResult].self, from: data)) ?? []
    }

    /// Reconciles stored results with the current catalog: keeps known statuses,
    /// appends newly added checks, and drops rows that no longer exist.
    static func merge(stored: [CheckResult], catalog: [CheckResult]) -> [CheckResult] {
        let byID = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        return catalog.map { entry in
            guard let existing = byID[entry.id] else { return entry }
            var merged = entry
            merged.status = existing.status
            merged.note = existing.note
            return merged
        }
    }
}
