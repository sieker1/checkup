import AVFoundation
import Foundation

/// Records a short clip from the built-in microphone while publishing a live
/// level for the meter, then plays the clip back so you can hear what it caught.
@MainActor
final class MicRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var hasRecording = false
    @Published private(set) var level: Double = 0
    @Published private(set) var peak: Double = 0
    @Published private(set) var history: [Double] = Array(repeating: 0, count: 48)
    @Published private(set) var statusText = "Idle"
    @Published var permissionGranted: Bool?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?

    private var fileURL: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Fettle", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mic-test.m4a")
    }

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    self?.statusText = granted ? "Microphone access granted" : "Microphone access denied"
                }
            }
        default:
            permissionGranted = false
            statusText = "Microphone access denied — enable it in System Settings › Privacy & Security › Microphone"
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        stopPlayback()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            self.recorder = recorder
            peak = 0
            history = Array(repeating: 0, count: history.count)
            isRecording = true
            statusText = "Recording — say something"
            startMetering()
        } catch {
            statusText = "Could not start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        recorder?.stop()
        recorder = nil
        stopMetering()
        isRecording = false
        hasRecording = FileManager.default.fileExists(atPath: fileURL.path)
        statusText = hasRecording ? "Recorded — play it back" : "Nothing was recorded"
    }

    func playRecording() {
        guard hasRecording else { return }
        stopPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.play()
            self.player = player
            isPlaying = true
            statusText = "Playing back"
        } catch {
            statusText = "Could not play back: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private func startMetering() {
        stopMetering()
        let timer = Timer(timeInterval: 1.0 / 25.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        meterTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let decibels = Double(recorder.averagePower(forChannel: 0))
        // Map the useful -60…0 dB range onto 0…1.
        let normalized = max(0, min(1, (decibels + 60) / 60))
        level = normalized
        peak = max(peak, normalized)
        history.removeFirst()
        history.append(normalized)
    }
}
