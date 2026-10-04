// Draws the macOS installer window background for the disk image, at 1x and 2x.
//
// It is deliberately plain: Finder draws the real app and Applications icons on
// top at the coordinates `scripts/layout-dmg.applescript` sets, so this image
// only supplies what Finder cannot - a soft field, the arrow between the two
// icons, and the caption. Drawing it in code keeps it in step with the icon.
//
// Text is drawn with CoreText rather than AppKit text so the tool needs no
// running NSApplication.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width: CGFloat = 660
let height: CGFloat = 420

/// Finder places icons by their centre in a top-left-origin space; CoreGraphics
/// draws from the bottom-left, so every y below is a Finder y and gets flipped.
func flip(_ y: CGFloat, _ h: CGFloat = 0) -> CGFloat { height - y - h }

func makeBackground(scale: Int) -> CGImage? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(width) * scale,
        height: Int(height) * scale,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    // Soft field.
    if let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(srgbRed: 0.976, green: 0.980, blue: 0.988, alpha: 1),
            CGColor(srgbRed: 0.914, green: 0.925, blue: 0.945, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: height),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }

    // The mark, watermarked behind the icons so the window is recognisably ours.
    if let mark = drawIcon(size: 340) {
        ctx.setAlpha(0.06)
        ctx.draw(mark, in: CGRect(x: width / 2 - 170, y: flip(120, 340), width: 340, height: 340))
        ctx.setAlpha(1)
    }

    // Arrow between the app icon and the Applications shortcut, which the
    // layout script places at x=150 and x=510 on the same row.
    let rowY = flip(200)
    let grey = CGColor(srgbRed: 0.60, green: 0.63, blue: 0.68, alpha: 1)
    ctx.setStrokeColor(grey)
    ctx.setFillColor(grey)
    ctx.setLineCap(.round)
    let shaft = CGMutablePath()
    shaft.move(to: CGPoint(x: 250, y: rowY))
    shaft.addLine(to: CGPoint(x: 398, y: rowY))
    ctx.addPath(shaft)
    ctx.setLineWidth(7)
    ctx.strokePath()

    let head = CGMutablePath()
    head.move(to: CGPoint(x: 392, y: rowY + 16))
    head.addLine(to: CGPoint(x: 422, y: rowY))
    head.addLine(to: CGPoint(x: 392, y: rowY - 16))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()

    // Caption.
    func caption(_ text: String, y: CGFloat, size: CGFloat, emphasized: Bool, color: CGColor) {
        let font = CTFontCreateUIFontForLanguage(emphasized ? .emphasizedSystem : .system, size, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: color,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        ctx.textPosition = CGPoint(x: (width - bounds.width) / 2, y: flip(y, bounds.height))
        CTLineDraw(line, ctx)
    }

    caption("Drag Checkup to Applications", y: 302, size: 15, emphasized: true,
            color: CGColor(srgbRed: 0.24, green: 0.27, blue: 0.32, alpha: 1))
    caption("then open it from Launchpad or Spotlight", y: 328, size: 12, emphasized: false,
            color: CGColor(srgbRed: 0.48, green: 0.52, blue: 0.58, alpha: 1))

    return ctx.makeImage()
}

@main
struct DmgBackground {
    static func main() {
        let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var failures = 0
        for (name, scale) in [("dmg-background.png", 1), ("dmg-background@2x.png", 2)] {
            guard let image = makeBackground(scale: scale),
                  writePNG(image, to: directory.appendingPathComponent(name)) else {
                print("FAIL could not render \(name)"); failures += 1; continue
            }
            print("  wrote \(name) \(Int(width) * scale)x\(Int(height) * scale)")
        }
        if failures > 0 { exit(1) }
        print("wrote installer background to \(directory.path)")
    }
}
