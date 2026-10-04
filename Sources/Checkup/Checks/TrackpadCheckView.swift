import AppKit
import SwiftUI

/// Captures clicks, drags, force pressure, pinch/rotate and multi-finger touches
/// so the trackpad's input paths can be exercised by hand.
final class TrackpadCanvasView: NSView {
    var onStatus: ((String) -> Void)?

    private var points: [CGPoint] = []

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryGeneric)
    }

    required init?(coder: NSCoder) { fatalError("Checkup builds its views in code") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setStroke()
        let grid = NSBezierPath()
        grid.lineWidth = 1
        stride(from: 0, to: bounds.width, by: 40).forEach { x in
            grid.move(to: CGPoint(x: x, y: 0)); grid.line(to: CGPoint(x: x, y: bounds.height))
        }
        stride(from: 0, to: bounds.height, by: 40).forEach { y in
            grid.move(to: CGPoint(x: 0, y: y)); grid.line(to: CGPoint(x: bounds.width, y: y))
        }
        grid.stroke()

        guard points.count > 1 else { return }
        let path = NSBezierPath()
        path.lineWidth = 3
        path.lineJoinStyle = .round
        NSColor.controlAccentColor.setStroke()
        path.move(to: points[0])
        for point in points.dropFirst() { path.line(to: point) }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        points = [convert(event.locationInWindow, from: nil)]
        needsDisplay = true
        onStatus?("Click detected — the button works")
    }

    override func mouseDragged(with event: NSEvent) {
        points.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
        onStatus?("Dragging — \(points.count) points tracked")
    }

    override func mouseUp(with event: NSEvent) {
        onStatus?("Release detected — drag path kept for inspection")
    }

    override func pressureChange(with event: NSEvent) {
        onStatus?(String(format: "Force: %.2f (stage %d) — Force Touch is responding", event.pressure, event.stage))
    }

    override func magnify(with event: NSEvent) {
        onStatus?(String(format: "Pinch: %.0f%%", event.magnification * 100))
    }

    override func rotate(with event: NSEvent) {
        onStatus?(String(format: "Rotate: %.1f°", event.rotation))
    }

    override func swipe(with event: NSEvent) {
        onStatus?("Swipe detected")
    }

    override func touchesBegan(with event: NSEvent) { reportTouches(event) }
    override func touchesMoved(with event: NSEvent) { reportTouches(event) }
    override func touchesEnded(with event: NSEvent) { reportTouches(event) }

    private func reportTouches(_ event: NSEvent) {
        let count = event.touches(matching: .touching, in: self).count
        onStatus?("\(count) finger\(count == 1 ? "" : "s") on the trackpad")
    }
}

struct TrackpadCanvasRepresentable: NSViewRepresentable {
    let onStatus: (String) -> Void

    func makeNSView(context: Context) -> TrackpadCanvasView {
        let view = TrackpadCanvasView(frame: .zero)
        view.onStatus = onStatus
        return view
    }

    func updateNSView(_ nsView: TrackpadCanvasView, context: Context) {
        nsView.onStatus = onStatus
    }
}

struct TrackpadCheckView: View {
    @State private var status = "Click, drag, pinch and rest 2–4 fingers on the trackpad."
    @State private var statusLog: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Try everything") {
                    TrackpadCanvasRepresentable { message in
                        status = message
                        statusLog.insert(message, at: 0)
                        if statusLog.count > 12 { statusLog.removeLast() }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))

                    Text(status).font(.callout)

                    HStack {
                        Button("Clear log") { statusLog.removeAll() }
                        Spacer()
                    }

                    if !statusLog.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(statusLog.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                CheckSection(title: "What to check") {
                    bullet("The pointer should track smoothly with no jumps — a jumpy cursor points to a failing trackpad or swollen battery.")
                    bullet("Press and hold: the click should feel even across the whole surface.")
                    bullet("Force press firmly to see the pressure stage change for the haptic “deep click”.")
                    bullet("Two fingers should scroll, pinch should zoom, and the drag path above should follow your finger exactly.")
                }

                CheckOutcomeControls(module: .trackpad)
            }
            .padding(20)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
