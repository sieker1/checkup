import AppKit
import SwiftUI

/// Drives the borderless full-screen window that cycles solid colours.
@MainActor
final class PixelTestController: ObservableObject {
    @Published private(set) var isRunning = false
    private var window: NSWindow?
    private var canvas: PixelCanvasView?

    func start(on screen: NSScreen?) {
        guard !isRunning, let screen = screen ?? NSScreen.main else { return }
        let canvas = PixelCanvasView()
        canvas.onClose = { [weak self] in self?.stop() }
        // A plain borderless NSWindow refuses key status, so keyDown would never
        // arrive and Escape would do nothing; this subclass opts in.
        let window = PixelTestWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas
        // NSWindow releases itself on close by default; under ARC that double
        // release of the window we also hold segfaults at the run loop's pool
        // drain, so hand ownership to Swift alone.
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.hide()

        self.canvas = canvas
        self.window = window
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        window?.orderOut(nil)
        window?.close()
        window = nil
        canvas = nil
        NSCursor.unhide()
        isRunning = false
    }
}

/// Borderless window that is still allowed to become key, so the canvas
/// receives Escape and the advance keys.
final class PixelTestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Fills itself with the current test colour and advances on click / any key.
final class PixelCanvasView: NSView {
    private(set) var index = 0
    var onClose: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Name the first colour straight away so the very first frame is
        // labelled too, not only the ones reached by advancing.
        window?.title = "Checkup pixel test — \(PixelSequence.color(at: index).name)"
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = PixelSequence.color(at: index)
        NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) { advance() }

    override func keyDown(with event: NSEvent) {
        // 53 is Escape.
        if event.keyCode == 53 {
            onClose?()
        } else {
            advance()
        }
    }

    func advance() {
        index = PixelSequence.nextIndex(after: index)
        window?.title = "Checkup pixel test — \(PixelSequence.color(at: index).name)"
        needsDisplay = true
    }
}

struct DisplayCheckView: View {
    @StateObject private var controller = PixelTestController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Dead and stuck pixels") {
                    Text("A full-screen window fills the display with each solid colour in turn. "
                         + "Click or press any key to advance; press Escape to stop.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(controller.isRunning ? "Testing…" : "Start pixel test") {
                            controller.start(on: NSScreen.main)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isRunning)

                        Button("Stop") { controller.stop() }
                            .disabled(!controller.isRunning)
                    }

                    Text("Colours: " + PixelSequence.standard.map(\.name).joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CheckSection(title: "What to look for") {
                    bullet("Any pixel that stays the wrong colour against a flat fill is dead (black) or stuck (a fixed colour).")
                    bullet("Before \"Start\", clean the screen — dust reads as a dead pixel.")
                    bullet("On the black frame, look at the corners by eye in a dark room for backlight bleed.")
                    bullet("On the 50% grey frame, look for faint vertical or horizontal banding.")
                }

                CheckSection(title: "This display") {
                    ForEach(SystemInfo.summaryLines(), id: \.0) { pair in
                        LabeledContent(pair.0, value: pair.1)
                    }
                }

                CheckOutcomeControls(module: .display)
            }
            .padding(20)
        }
        .onDisappear { controller.stop() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
