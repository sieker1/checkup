import AppKit
import SwiftUI

@MainActor
final class KeyTestModel: ObservableObject {
    @Published private(set) var pressed: Set<UInt16> = []
    @Published private(set) var tested: Set<UInt16> = []
    @Published private(set) var lastKey = "—"

    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            Task { @MainActor in self.handle(event) }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func reset() {
        pressed = []
        tested = []
        lastKey = "—"
    }

    private func handle(_ event: NSEvent) {
        let code = event.keyCode
        switch event.type {
        case .keyUp:
            pressed.remove(code)
        case .flagsChanged:
            // Modifier keys have no down/up pair, so light them and fade them.
            pressed.insert(code)
            tested.insert(code)
            lastKey = KeyboardLayout.label(for: code) ?? "code \(code)"
            let captured = code
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                self?.pressed.remove(captured)
            }
        default:
            pressed.insert(code)
            tested.insert(code)
            lastKey = KeyboardLayout.label(for: code) ?? "code \(code)"
        }
    }

    var untested: [String] {
        KeyboardLayout.uniqueCodes
            .filter { !tested.contains($0) }
            .compactMap { KeyboardLayout.label(for: $0) }
    }

    var progress: Double {
        let total = KeyboardLayout.uniqueCodes.count
        guard total > 0 else { return 0 }
        return Double(tested.intersection(KeyboardLayout.uniqueCodes).count) / Double(total)
    }
}

struct KeyboardCheckView: View {
    @StateObject private var model = KeyTestModel()
    private let unit: CGFloat = 34

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Press every key") {
                    Text("Press each key in turn. Every key you have pressed turns green, so whatever "
                         + "stays grey is a dead key. Modifier keys light up while held.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 4) {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                                    KeyCap(key: key, unit: unit,
                                           isPressed: model.pressed.contains(key.code),
                                           isTested: model.tested.contains(key.code))
                                }
                            }
                        }
                    }
                    .padding(8)

                    HStack(spacing: 16) {
                        Text("Last key: \(model.lastKey)").font(.callout)
                        ProgressView(value: model.progress)
                            .frame(maxWidth: 240)
                        Text("\(Int(model.progress * 100))%")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Reset") { model.reset() }
                    }

                    if !model.untested.isEmpty {
                        Text("Not yet pressed: \(model.untested.joined(separator: "  "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("Every key on the layout has been pressed.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }

                CheckOutcomeControls(module: .keyboard)
            }
            .padding(20)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct KeyCap: View {
    let key: KeyDefinition
    let unit: CGFloat
    let isPressed: Bool
    let isTested: Bool

    var body: some View {
        Text(key.label)
            .font(.system(size: key.label.count > 1 ? 11 : 13))
            .frame(width: unit * key.width, height: unit)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.quaternary))
    }

    private var background: Color {
        if isPressed { return .accentColor }
        if isTested { return Color.green.opacity(0.35) }
        return Color.gray.opacity(0.15)
    }

    private var foreground: Color {
        isPressed ? .white : .primary
    }
}
