import SwiftUI

struct SpeakerCheckView: View {
    @StateObject private var tones = ToneGenerator()
    @State private var channel: SpeakerChannel = .both
    @State private var volume: Double = 0.35

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Channel isolation") {
                    Text("Turn the volume down first. Play the tone on each side: it should come "
                         + "only from that speaker. Silence, crackle or bleed means a bad speaker.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Channel", selection: $channel) {
                        ForEach(SpeakerChannel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)

                    HStack(spacing: 10) {
                        Button("Play 440 Hz tone") { tones.playTone(frequency: 440, channel: channel) }
                            .buttonStyle(.borderedProminent)
                        Button("Play 1 kHz tone") { tones.playTone(frequency: 1000, channel: channel) }
                        Button("Stop") { tones.stop() }
                            .disabled(!tones.isPlaying)
                    }

                    HStack(spacing: 10) {
                        Text("Volume").frame(width: 60, alignment: .leading)
                        Slider(value: $volume, in: 0...1)
                            .frame(maxWidth: 260)
                            .onChange(of: volume) { _, newValue in tones.setVolume(newValue) }
                    }
                }

                CheckSection(title: "Full-range tests") {
                    HStack(spacing: 10) {
                        Button("Sweep 20 Hz → 20 kHz") { tones.playSweep(channel: channel) }
                        Button("White noise") { tones.playNoise(channel: channel) }
                    }
                    Text("Now playing: \(tones.lastSignal)")
                        .font(.callout)
                        .foregroundStyle(tones.isPlaying ? .primary : .secondary)
                }

                CheckSection(title: "What to listen for") {
                    bullet("Rattles or buzzing on the sweep usually mean a loose speaker or a resonance in the chassis.")
                    bullet("The sweep should be audible down to roughly 60 Hz and up to about 18 kHz.")
                    bullet("The two sides should sound equally loud on the same tone; a quieter side is a hardware fault.")
                }

                CheckOutcomeControls(module: .speakers)
            }
            .padding(20)
        }
        .onDisappear { tones.stop() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
