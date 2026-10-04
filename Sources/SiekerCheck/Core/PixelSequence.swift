import Foundation

/// One full-screen colour used by the dead-pixel / stuck-pixel test.
struct PixelTestColor: Equatable {
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

/// The canonical order of solid colours shown by the display test.
///
/// The order matters: primaries first so a single dead sub-pixel is easiest to
/// spot, then the two greys that expose backlight bleed and banding, then black
/// last so a bright rectangle of unmasked pixels is obvious against nothing.
enum PixelSequence {
    static let standard: [PixelTestColor] = [
        PixelTestColor(name: "Red", red: 1, green: 0, blue: 0),
        PixelTestColor(name: "Green", red: 0, green: 1, blue: 0),
        PixelTestColor(name: "Blue", red: 0, green: 0, blue: 1),
        PixelTestColor(name: "Cyan", red: 0, green: 1, blue: 1),
        PixelTestColor(name: "Magenta", red: 1, green: 0, blue: 1),
        PixelTestColor(name: "Yellow", red: 1, green: 1, blue: 0),
        PixelTestColor(name: "White", red: 1, green: 1, blue: 1),
        PixelTestColor(name: "50% Grey", red: 0.5, green: 0.5, blue: 0.5),
        PixelTestColor(name: "Black", red: 0, green: 0, blue: 0),
    ]

    /// Wraps around so the test can be cycled indefinitely with one key.
    static func color(at index: Int) -> PixelTestColor {
        guard !standard.isEmpty else { return PixelTestColor(name: "Black", red: 0, green: 0, blue: 0) }
        let wrapped = ((index % standard.count) + standard.count) % standard.count
        return standard[wrapped]
    }

    static func nextIndex(after index: Int) -> Int {
        guard !standard.isEmpty else { return 0 }
        return (index + 1) % standard.count
    }
}
