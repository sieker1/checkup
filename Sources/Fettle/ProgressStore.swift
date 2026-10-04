import Combine
import Foundation

/// Holds the live checklist, keeps it in sync with the module catalog, and
/// persists it so a half-finished test survives quitting the app.
@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var results: [CheckResult]

    private let defaults: UserDefaults
    private let storageKey = "Fettle.results.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let catalog = CheckModule.reportable.map(\.initialCheckResult)
        if let data = defaults.data(forKey: storageKey) {
            results = ProgressCodec.merge(stored: ProgressCodec.decode(data), catalog: catalog)
        } else {
            results = catalog
        }
    }

    func status(for module: CheckModule) -> CheckStatus {
        results.first { $0.id == module.id }?.status ?? .untested
    }

    func note(for module: CheckModule) -> String {
        results.first { $0.id == module.id }?.note ?? ""
    }

    func setStatus(_ status: CheckStatus, for module: CheckModule) {
        update(module) { $0.status = status }
    }

    func cycleStatus(for module: CheckModule) {
        let order: [CheckStatus] = [.untested, .pass, .fail, .notApplicable]
        let current = status(for: module)
        let next = order[(order.firstIndex(of: current).map { $0 + 1 } ?? 0) % order.count]
        setStatus(next, for: module)
    }

    func setNote(_ note: String, for module: CheckModule) {
        update(module) { $0.note = note }
    }

    func reset() {
        results = CheckModule.reportable.map(\.initialCheckResult)
        persist()
    }

    func markdownReport(machine: MachineInfo = SystemInfo.current()) -> String {
        ReportBuilder.markdown(machine: machine, results: results)
    }

    private func update(_ module: CheckModule, _ mutate: (inout CheckResult) -> Void) {
        guard let index = results.firstIndex(where: { $0.id == module.id }) else { return }
        mutate(&results[index])
        persist()
    }

    private func persist() {
        defaults.set(ProgressCodec.encode(results), forKey: storageKey)
    }
}
