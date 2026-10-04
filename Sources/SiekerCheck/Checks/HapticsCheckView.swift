import AppKit
import SwiftUI

struct HapticsCheckView: View {
    @State private var lastFired = "—"

    private let patterns: [(String, NSHapticFeedbackManager.FeedbackPattern)] = [
        ("Alignment", .alignment),
        ("Level change", .levelChange),
        ("Generic", .generic),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Force Touch feedback") {
                    Text("Rest a finger on the trackpad and click a pattern below. You should feel a small tap. "
                         + "macOS only produces it on a Force Touch trackpad with a finger on the surface, so a "
                         + "mouse or a lifted finger means no feedback — that is expected, not a fault.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ForEach(patterns, id: \.0) { name, pattern in
                            Button(name) { fire(pattern, name: name) }
                                .buttonStyle(.borderedProminent)
                        }
                    }

                    Text("Last fired: \(lastFired)").font(.callout).foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Fire 6 in a row") { fireSequence() }
                        Text("Confirms the actuator is not intermittent.").font(.caption).foregroundStyle(.secondary)
                    }
                }

                CheckSection(title: "What to check") {
                    bullet("Each pattern should feel like a crisp tap, not a buzzing or grinding sensation.")
                    bullet("If you feel nothing at all while a finger is on the trackpad, the Taptic Engine may be faulty.")
                    bullet("“Level change” is the strongest of the three; “Alignment” is the subtlest.")
                }

                CheckOutcomeControls(module: .haptics)
            }
            .padding(20)
        }
    }

    private func fire(_ pattern: NSHapticFeedbackManager.FeedbackPattern, name: String) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        lastFired = name
    }

    private func fireSequence() {
        for step in 0..<6 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(step) * 220_000_000)
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        }
        lastFired = "6 × level change"
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
