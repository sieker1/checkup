// AVCaptureSession is not Sendable; we hand it to a background queue to keep
// start/stop off the main thread, which the compiler flags without this.
@preconcurrency import AVFoundation
import AppKit
import SwiftUI

@MainActor
final class CameraController: ObservableObject {
    @Published private(set) var devices: [String] = []
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "Idle"
    @Published private(set) var resolution = "—"

    let session = AVCaptureSession()
    private var input: AVCaptureDeviceInput?

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices.map { "\($0.localizedName) (\($0.uniqueID.prefix(8)))" }
    }

    func start() {
        guard !isRunning else { return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.statusText = "Camera access denied — enable it in System Settings › Privacy & Security › Camera"
                    return
                }
                self.configureAndStart()
            }
        }
    }

    private func configureAndStart() {
        refreshDevices()
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first else {
            statusText = "No camera found"
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let existing = self.input { session.removeInput(existing) }
            if session.canAddInput(input) {
                session.addInput(input)
                self.input = input
            }
            session.commitConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            resolution = "\(dimensions.width) × \(dimensions.height)"
            statusText = "Showing \(device.localizedName)"
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
            isRunning = true
        } catch {
            statusText = "Could not open camera: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
        isRunning = false
        statusText = "Stopped"
        resolution = "—"
    }
}

/// Hosts an `AVCaptureVideoPreviewLayer` and keeps it sized to the view.
final class CameraPreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("Fettle builds its views in code") }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(session: session)
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {}
}

struct CameraCheckView: View {
    @StateObject private var camera = CameraController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Live preview") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.black)
                        CameraPreviewRepresentable(session: camera.session)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        if !camera.isRunning {
                            Text("Preview stopped")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(height: 300)

                    HStack(spacing: 10) {
                        Button("Start camera") { camera.start() }
                            .buttonStyle(.borderedProminent)
                            .disabled(camera.isRunning)
                        Button("Stop") { camera.stop() }
                            .disabled(!camera.isRunning)
                        Button("Rescan devices") { camera.refreshDevices() }
                    }

                    Text(camera.statusText).font(.callout).foregroundStyle(.secondary)
                    LabeledContent("Active resolution", value: camera.resolution)
                }

                CheckSection(title: "Cameras detected") {
                    if camera.devices.isEmpty {
                        Text("Press “Rescan devices” or “Start camera”.").foregroundStyle(.secondary)
                    } else {
                        ForEach(camera.devices, id: \.self) { device in
                            Label(device, systemImage: "video")
                        }
                    }
                }

                CheckSection(title: "What to look for") {
                    bullet("The image should be sharp and evenly lit, with no coloured bands or a frozen frame.")
                    bullet("Cover the lens with a finger: the picture should go black, not stay bright.")
                }

                CheckOutcomeControls(module: .camera)
            }
            .padding(20)
        }
        .onAppear { camera.refreshDevices() }
        .onDisappear { camera.stop() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
