import Combine
import Foundation

/// Drives "Run all checks" mode: a single ordered pass through every check, with
/// the sidebar selection kept in step so the walkthrough and the sidebar can
/// never disagree about where you are.
@MainActor
final class GuidedSession: ObservableObject {
    /// The order the walkthrough visits, which is the sidebar order minus the
    /// dashboard.
    let order = CheckModule.reportable

    /// The one source of truth for what the window is showing.
    @Published var selection: CheckModule? = .dashboard
    @Published private(set) var isActive = false
    @Published private(set) var index = 0

    var current: CheckModule { order[min(max(index, 0), order.count - 1)] }
    var stepNumber: Int { index + 1 }
    var total: Int { order.count }
    var isLastStep: Bool { index >= order.count - 1 }

    func start() {
        index = 0
        isActive = true
        selection = order.first
    }

    func advance() {
        guard index < order.count - 1 else { return }
        index += 1
        selection = order[index]
    }

    func back() {
        guard index > 0 else { return }
        index -= 1
        selection = order[index]
    }

    /// Finishing keeps the index where it is so the window does not jump.
    func finish() {
        isActive = false
        selection = .dashboard
    }

    func exit() {
        isActive = false
        selection = .dashboard
    }

    /// Keeps the walkthrough in step when the sidebar is clicked directly.
    func sync(with module: CheckModule?) {
        guard isActive, let module, let position = order.firstIndex(of: module) else { return }
        index = position
    }
}
