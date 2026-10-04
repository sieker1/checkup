import SwiftUI

/// Sidebar + detail shell. The sidebar is the module catalog; the detail is the
/// selected check.
struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var guided: GuidedSession

    var body: some View {
        NavigationSplitView {
            List(CheckModule.allCases, selection: $guided.selection) { module in
                Label {
                    HStack(spacing: 6) {
                        Text(module.title)
                        Spacer(minLength: 4)
                        StatusDot(status: progress.status(for: module))
                    }
                } icon: {
                    Image(systemName: module.symbol)
                }
                .tag(module)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
            .navigationTitle("SiekerCheck")
        } detail: {
            VStack(spacing: 0) {
                if guided.isActive {
                    GuidedBar()
                    Divider()
                }
                detail
                    .navigationTitle(guided.selection?.title ?? "SiekerCheck")
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onChange(of: guided.selection) { _, newValue in
            // Clicking the sidebar mid-walkthrough keeps the step counter honest.
            guided.sync(with: newValue)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch guided.selection ?? .dashboard {
        case .dashboard: DashboardView()
        case .display: DisplayCheckView()
        case .speakers: SpeakerCheckView()
        case .microphone: MicrophoneCheckView()
        case .camera: CameraCheckView()
        case .keyboard: KeyboardCheckView()
        case .trackpad: TrackpadCheckView()
        case .battery: BatteryCheckView()
        case .storage: StorageCheckView()
        case .haptics: HapticsCheckView()
        case .connectivity: ConnectivityCheckView()
        }
    }
}

/// The banner shown during "Run all checks" mode.
struct GuidedBar: View {
    @EnvironmentObject private var guided: GuidedSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Guided check \(guided.stepNumber) of \(guided.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(guided.current.title).font(.headline)
            }
            ProgressView(value: Double(guided.stepNumber), total: Double(guided.total))
                .frame(maxWidth: 160)
            Spacer()
            Button("Back") { guided.back() }
                .disabled(guided.index == 0)
            if guided.isLastStep {
                Button("Finish") { guided.finish() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Next check") { guided.advance() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Exit") { guided.exit() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

/// Small coloured dot shown next to each sidebar row.
struct StatusDot: View {
    let status: CheckStatus

    var body: some View {
        Image(systemName: status.symbol)
            .foregroundStyle(color)
            .imageScale(.small)
            .help(status.rawValue)
    }

    private var color: Color {
        switch status {
        case .untested: .secondary
        case .pass: .green
        case .fail: .red
        case .notApplicable: .orange
        }
    }
}

/// Shared "mark this check" control used at the foot of every check screen.
struct CheckOutcomeControls: View {
    @EnvironmentObject private var progress: ProgressStore
    let module: CheckModule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.headline)
                Spacer()
                Picker("", selection: statusBinding) {
                    ForEach(CheckStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
            }
            TextField(
                "Notes for the report (optional)",
                text: Binding(
                    get: { progress.note(for: module) },
                    set: { progress.setNote($0, for: module) }
                ),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...3)
        }
    }

    private var statusBinding: Binding<CheckStatus> {
        Binding(
            get: { progress.status(for: module) },
            set: { progress.setStatus($0, for: module) }
        )
    }
}

/// A titled panel used to group content on each check screen.
struct CheckSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text(title).font(.headline)
        }
    }
}
