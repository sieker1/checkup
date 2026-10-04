import SwiftUI

struct MicrophoneCheckView: View {
    @StateObject private var mic = MicRecorder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Record and play back") {
                    Text("Record a few seconds, then play it back. The meter should jump as you speak "
                         + "and fall silent when you stop — if it never moves, the mic is dead or muted.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LevelMeter(history: mic.history, level: mic.level, peak: mic.peak)

                    HStack(spacing: 10) {
                        Button(mic.isRecording ? "Stop recording" : "Start recording") {
                            if mic.isRecording { mic.stopRecording() } else { mic.startRecording() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Play back") { mic.playRecording() }
                            .disabled(!mic.hasRecording || mic.isRecording)

                        Button("Stop playback") { mic.stopPlayback() }
                            .disabled(!mic.isPlaying)

                        Button("Request access") { mic.requestPermission() }
                    }

                    Text(mic.statusText).font(.callout).foregroundStyle(.secondary)

                    if let granted = mic.permissionGranted, !granted {
                        Label("Microphone access is denied. Open System Settings › Privacy & Security › Microphone and enable SiekerCheck.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                CheckSection(title: "What to listen for") {
                    bullet("Your voice should be clear, not crackly or muffled, and not clipping (distorted).")
                    bullet("Recording should sound roughly the same as your own voice in the room.")
                    bullet("Background hiss that gets louder over time can point to a failing input board.")
                }

                CheckOutcomeControls(module: .microphone)
            }
            .padding(20)
        }
        .onAppear { mic.requestPermission() }
        .onDisappear { mic.stopRecording(); mic.stopPlayback() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A scrolling bar meter plus a peak-hold marker.
private struct LevelMeter: View {
    let history: [Double]
    let level: Double
    let peak: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(history.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color(for: value))
                        .frame(width: 5, height: max(2, value * 72))
                }
            }
            .frame(height: 74, alignment: .bottom)

            HStack {
                Text("Level").font(.caption).foregroundStyle(.secondary)
                ProgressView(value: level)
                    .frame(maxWidth: 240)
                Text("Peak \(Int(peak * 100))%").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func color(for value: Double) -> Color {
        if value > 0.9 { return .red }
        if value > 0.7 { return .orange }
        return .green
    }
}
