import Foundation

/// A key drawn on the on-screen keyboard. `width` is in key units, where 1 is
/// a normal alphanumeric key, so the layout can stretch modifiers and space.
struct KeyDefinition: Equatable {
    let code: UInt16
    let label: String
    let width: Double
}

/// The US-layout ANSI keyboard, grouped into rows for drawing and for the
/// "which keys have you not pressed yet" test.
enum KeyboardLayout {
    static let rows: [[KeyDefinition]] = [
        [
            key(50, "`"), key(18, "1"), key(19, "2"), key(20, "3"), key(21, "4"),
            key(23, "5"), key(22, "6"), key(26, "7"), key(28, "8"), key(25, "9"),
            key(29, "0"), key(27, "-"), key(24, "="), key(51, "⌫", 1.5),
        ],
        [
            key(48, "⇥", 1.5), key(12, "Q"), key(13, "W"), key(14, "E"), key(15, "R"),
            key(17, "T"), key(16, "Y"), key(32, "U"), key(34, "I"), key(31, "O"),
            key(35, "P"), key(33, "["), key(30, "]"), key(42, "\\", 1.5),
        ],
        [
            key(57, "⇪", 1.75), key(0, "A"), key(1, "S"), key(2, "D"), key(3, "F"),
            key(5, "G"), key(4, "H"), key(38, "J"), key(40, "K"), key(37, "L"),
            key(41, ";"), key(39, "'"), key(36, "⏎", 1.75),
        ],
        [
            key(56, "⇧", 2.25), key(6, "Z"), key(7, "X"), key(8, "C"), key(9, "V"),
            key(11, "B"), key(45, "N"), key(46, "M"), key(43, ","), key(47, "."),
            key(44, "/"), key(60, "⇧", 2.25),
        ],
        [
            key(63, "fn", 1.2), key(59, "⌃", 1.2), key(58, "⌥", 1.2), key(55, "⌘", 1.4),
            key(49, "space", 5.0), key(55, "⌘", 1.4), key(58, "⌥", 1.2),
            key(123, "←"), key(124, "→"), key(125, "↓"), key(126, "↑"),
        ],
    ]

    /// Every key that the test expects you to press, in reading order.
    static var allKeys: [KeyDefinition] { rows.flatMap { $0 } }

    /// Duplicate codes (left/right Command, Shift, Option) collapse to one
    /// entry so progress is not double-counted.
    static var uniqueCodes: [UInt16] {
        var seen = Set<UInt16>()
        return allKeys.map(\.code).filter { seen.insert($0).inserted }
    }

    static func label(for code: UInt16) -> String? {
        allKeys.first { $0.code == code }?.label
    }

    private static func key(_ code: UInt16, _ label: String, _ width: Double = 1) -> KeyDefinition {
        KeyDefinition(code: code, label: label, width: width)
    }
}
