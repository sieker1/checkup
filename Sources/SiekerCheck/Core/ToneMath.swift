import Foundation

/// Which speaker/output path a test tone should exercise.
enum SpeakerChannel: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case both = "Both"

    var id: String { rawValue }
}

/// Pure maths for the speaker tests. Kept free of AVFoundation so it can be
/// exercised by the headless test target with exact expected values.
enum ToneMath {
    static let sweepStart: Double = 20
    static let sweepEnd: Double = 20_000

    /// Linearly distributed log-scale frequencies from 20 Hz to 20 kHz.
    ///
    /// `steps` includes both endpoints, so `steps >= 2` is required for a
    /// meaningful sweep; smaller requests are clamped to 2.
    static func sweepFrequencies(steps: Int) -> [Double] {
        let count = max(steps, 2)
        let ratio = sweepEnd / sweepStart
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return sweepStart * pow(ratio, t)
        }
    }

    /// Constant-power-ish pan gains for a channel: 1 means "this side is fully
    /// driven", 0 means "silent". Both returns 1 on each side.
    static func gains(for channel: SpeakerChannel) -> (left: Double, right: Double) {
        switch channel {
        case .left: return (1, 0)
        case .right: return (0, 1)
        case .both: return (1, 1)
        }
    }

    /// A gentle amplitude ramp so a tone starts and stops without a click.
    static func edgeEnvelope(sampleIndex: Int, totalSamples: Int, fadeSamples: Int) -> Double {
        guard fadeSamples > 0, totalSamples > 2 * fadeSamples else { return 1 }
        if sampleIndex < fadeSamples {
            return Double(sampleIndex) / Double(fadeSamples)
        }
        if sampleIndex >= totalSamples - fadeSamples {
            return Double(totalSamples - sampleIndex) / Double(fadeSamples)
        }
        return 1
    }

    static func decibelsToGain(_ db: Double) -> Double {
        pow(10, db / 20)
    }

    static func gainToDecibels(_ gain: Double) -> Double {
        gain <= 0 ? -.infinity : 20 * log10(gain)
    }
}
