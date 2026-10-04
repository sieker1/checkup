import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var guided: GuidedSession
    @State private var machine = SystemInfo.current()
    @State private var savedPath: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "This Mac") {
                    ForEach(SystemInfo.summaryLines(), id: \.0) { pair in
                        LabeledContent(pair.0, value: pair.1)
                    }
                    Button("Refresh") { machine = SystemInfo.current() }
                }

                CheckSection(title: "Checklist — \(ReportBuilder.headline(progress.results))") {
                    HStack(spacing: 10) {
                        Button("Run all checks") { guided.start() }
                            .buttonStyle(.borderedProminent)
                        Text("Walks every check in order, one screen at a time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    ForEach(CheckModule.reportable) { module in
                        HStack {
                            Image(systemName: module.symbol).foregroundStyle(.secondary).frame(width: 22)
                            Text(module.title)
                            Spacer()
                            Picker("", selection: statusBinding(for: module)) {
                                ForEach(CheckStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 320)
                        }
                    }

                    Text("Mark every check, then export the report. The checklist is saved automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                CheckSection(title: "Export") {
                    HStack(spacing: 10) {
                        Button("Copy report") { copyReport() }
                            .buttonStyle(.borderedProminent)
                        Button("Save report…") { saveReport() }
                        Button("Reset checklist") { progress.reset() }
                        if copied {
                            Label("Copied", systemImage: "checkmark").foregroundStyle(.green).font(.caption)
                        }
                    }
                    if let savedPath {
                        Text("Saved to \(savedPath)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private func statusBinding(for module: CheckModule) -> Binding<CheckStatus> {
        Binding(
            get: { progress.status(for: module) },
            set: { progress.setStatus($0, for: module) }
        )
    }

    private func copyReport() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(progress.markdownReport(machine: machine), forType: .string)
        copied = true
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Checkup-report.md"
        panel.allowedContentTypes = [.plainText]
        panel.title = "Save Checkup report"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try progress.markdownReport(machine: machine).write(to: url, atomically: true, encoding: .utf8)
            savedPath = url.path
        } catch {
            savedPath = "failed: \(error.localizedDescription)"
        }
    }
}
