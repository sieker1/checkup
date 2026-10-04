import AVFoundation
import Foundation

/// Plays the speaker test signals: a steady sine tone, a logged frequency
/// sweep, and white noise, each routed to a chosen channel.
@MainActor
final class ToneGenerator: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var lastSignal = "—"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let stereo: AVAudioFormat

    init() {
        stereo = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: stereo)
    }

    func setVolume(_ volume: Double) {
        engine.mainMixerNode.outputVolume = Float(max(0, min(1, volume)))
    }

    func playTone(frequency: Double, channel: SpeakerChannel) {
        let gains = ToneMath.gains(for: channel)
        let buffer = makeBuffer(seconds: 1.0) { index, total in
            let amplitude = 0.28 * ToneMath.edgeEnvelope(
                sampleIndex: index, totalSamples: total, fadeSamples: Int(self.sampleRate * 0.01)
            )
            let phase = 2 * Double.pi * frequency * Double(index) / self.sampleRate
            let sample = sin(phase) * amplitude
            return (sample * gains.left, sample * gains.right)
        }
        lastSignal = String(format: "%.0f Hz — %@", frequency, channel.rawValue)
        play(buffer)
    }

    func playSweep(channel: SpeakerChannel) {
        let gains = ToneMath.gains(for: channel)
        let seconds = 3.0
        let buffer = makeBuffer(seconds: seconds) { index, total in
            let t = Double(index) / Double(total)
            let frequency = ToneMath.sweepStart * pow(ToneMath.sweepEnd / ToneMath.sweepStart, t)
            let amplitude = 0.22 * ToneMath.edgeEnvelope(
                sampleIndex: index, totalSamples: total, fadeSamples: Int(self.sampleRate * 0.05)
            )
            let phase = 2 * Double.pi * frequency * Double(index) / self.sampleRate
            let sample = sin(phase) * amplitude
            return (sample * gains.left, sample * gains.right)
        }
        lastSignal = "Sweep \(Int(ToneMath.sweepStart))–\(Int(ToneMath.sweepEnd)) Hz — \(channel.rawValue)"
        play(buffer)
    }

    func playNoise(channel: SpeakerChannel) {
        let gains = ToneMath.gains(for: channel)
        var generator = SystemRandomNumberGenerator()
        let buffer = makeBuffer(seconds: 1.5) { _, _ in
            let sample = Double.random(in: -1...1, using: &generator) * 0.2
            return (sample * gains.left, sample * gains.right)
        }
        lastSignal = "White noise — \(channel.rawValue)"
        play(buffer)
    }

    func stop() {
        player.stop()
        if engine.isRunning { engine.pause() }
        isPlaying = false
        lastSignal = "—"
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            isPlaying = false
            return
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        isPlaying = true
    }

    /// Renders `seconds` of stereo audio using `sample`, which returns the left
    /// and right values for one frame.
    private func makeBuffer(seconds: Double, sample: (Int, Int) -> (Double, Double)) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(seconds * sampleRate)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: frameCount),
            let channels = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = frameCount
        let total = Int(frameCount)
        for index in 0..<total {
            let (left, right) = sample(index, total)
            channels[0][index] = Float(left)
            channels[1][index] = Float(right)
        }
        return buffer
    }
}
