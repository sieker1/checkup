import Foundation
import SwiftUI

@main
struct SiekerCheckApp: App {
    @StateObject private var progress = ProgressStore()
    @StateObject private var guided = GuidedSession()

    init() {
        // `--list-checks` prints the report for this machine and exits, so the
        // checklist can be produced from a script or CI without opening a window.
        if CommandLine.arguments.contains("--list-checks") {
            let results = CheckModule.reportable.map(\.initialCheckResult)
            print(ReportBuilder.markdown(machine: SystemInfo.current(), results: results))
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .environmentObject(guided)
        }
        .commands {
            // SiekerCheck is a single-purpose test tool; a "New window" item would
            // only spawn a second copy of the checklist.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
