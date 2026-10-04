// Writes a complete macOS .iconset from the artwork in IconArt.swift.
// Run via `make icon`; `iconutil` turns the iconset into .icns.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The ten files `iconutil` expects, including the 2x variants.
let entries: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

/// Samples the rendered pixels in the same design space as the drawing, so each
/// check reads like the coordinate it describes. The image buffer's origin is
/// the top-left, hence the flip. These are assertions, not a printout: a sample
/// that does not match fails the run, which is the only way to check the
/// artwork on a machine with no way to look at it.
func probe(_ image: CGImage) {
    guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
        print("FAIL probe: no pixel data"); exit(1)
    }
    let perRow = image.bytesPerRow
    let perPixel = image.bitsPerPixel / 8
    let scale = CGFloat(image.width) / design

    func sample(designX: CGFloat, designY: CGFloat) -> (r: Int, g: Int, b: Int, a: Int) {
        let px = min(max(Int(designX * scale), 0), image.width - 1)
        let py = min(max(Int((design - designY) * scale), 0), image.height - 1)
        let offset = py * perRow + px * perPixel
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]), Int(bytes[offset + 3]))
    }

    let transparent: (Int, Int, Int, Int) -> Bool = { _, _, _, a in a == 0 }
    let white: (Int, Int, Int, Int) -> Bool = { r, g, b, a in r > 230 && g > 230 && b > 230 && a > 230 }
    let blue: (Int, Int, Int, Int) -> Bool = { r, g, b, a in b > r && b > 150 && a > 230 }

    var failures = 0
    func expect(_ label: String, _ x: CGFloat, _ y: CGFloat, _ test: (Int, Int, Int, Int) -> Bool) {
        let v = sample(designX: x, designY: y)
        let ok = test(v.r, v.g, v.b, v.a)
        if !ok { failures += 1 }
        print(String(format: "  %@ %-18@ rgba(%3d,%3d,%3d,%3d)",
                     ok ? "ok  " : "FAIL", label as NSString, v.r, v.g, v.b, v.a))
    }

    print("probe (\(image.width)px):")
    expect("corner", 2, 1022, transparent)
    expect("gradient field", 512, 150, blue)
    expect("display stroke", 212, 542, white)
    expect("display interior", 512, 400, blue)
    expect("check mark", 470, 444, white)
    expect("stand", 512, 320, white)
    expect("base bar", 512, 272, white)

    if failures > 0 {
        print("FAIL \(failures) probe sample(s) did not match the intended drawing")
        exit(1)
    }
    print("  all 7 probe samples match the intended drawing")
}

@main
struct IconMaker {
    static func main() {
        let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset"
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        var failures = 0
        for entry in entries {
            guard let image = drawIcon(size: entry.size) else {
                print("FAIL could not render \(entry.size)px"); failures += 1; continue
            }
            guard writePNG(image, to: outputURL.appendingPathComponent(entry.name)) else {
                print("FAIL could not write \(entry.name)"); failures += 1; continue
            }
            print(String(format: "  wrote %-22s %4dpx", (entry.name as NSString).utf8String!, entry.size))
        }

        if let largest = drawIcon(size: 1024) { probe(largest) }

        if failures > 0 { print("\(failures) icon(s) failed"); exit(1) }
        print("wrote \(entries.count) icons to \(outputPath)")
    }
}
