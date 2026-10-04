// The Fettle mark, drawn with CoreGraphics.
//
// A rounded-square "squircle" in the Big Sur idiom: a blue gradient field
// carrying a white display outline with a check mark inside it, which is the
// app's whole job in one glyph. Because the drawing is code it renders
// identically at every size, and the icon and the installer background stay in
// step instead of drifting apart as two hand-exported files.
//
// Every coordinate is in a 1024x1024 design space and scaled to the target, so
// 16px and 1024px are the same picture.
//
// This file has no main; `make-icon.swift` and `make-dmg-background.swift` each
// compile against it.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let design: CGFloat = 1024
let cornerRatio: CGFloat = 0.2245

func drawIcon(size: Int) -> CGImage? {
    let scale = CGFloat(size) / design
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: scale, y: scale)

    // Clip to the squircle so the gradient cannot spill into the corners.
    let squircle = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: design, height: design),
        cornerWidth: design * cornerRatio,
        cornerHeight: design * cornerRatio,
        transform: nil
    )
    ctx.addPath(squircle)
    ctx.clip()

    // Blue field, lit from the top-left.
    let top = CGColor(srgbRed: 0.11, green: 0.25, blue: 0.58, alpha: 1)
    let bottom = CGColor(srgbRed: 0.05, green: 0.63, blue: 0.86, alpha: 1)
    if let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: design * 0.12, y: design * 0.98),
            end: CGPoint(x: design * 0.88, y: design * 0.02),
            options: []
        )
    }

    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.97)
    ctx.setStrokeColor(white)
    ctx.setFillColor(white)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Display outline.
    let screen = CGRect(x: 212, y: 352, width: 600, height: 380)
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.setLineWidth(34)
    ctx.strokePath()

    // Stand: a short neck under the display.
    let stand = CGMutablePath()
    stand.move(to: CGPoint(x: 432, y: 300))
    stand.addLine(to: CGPoint(x: 592, y: 300))
    stand.addLine(to: CGPoint(x: 620, y: 352))
    stand.addLine(to: CGPoint(x: 404, y: 352))
    stand.closeSubpath()
    ctx.addPath(stand)
    ctx.fillPath()

    // Base bar.
    ctx.addPath(CGPath(
        roundedRect: CGRect(x: 336, y: 252, width: 352, height: 40),
        cornerWidth: 20,
        cornerHeight: 20,
        transform: nil
    ))
    ctx.fillPath()

    // Check mark inside the display.
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 350, y: 556))
    check.addLine(to: CGPoint(x: 466, y: 440))
    check.addLine(to: CGPoint(x: 686, y: 654))
    ctx.addPath(check)
    ctx.setLineWidth(62)
    ctx.strokePath()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
