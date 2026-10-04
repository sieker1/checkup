import Foundation

/// Dependency-free checks for Fettle's pure logic. These compile against the
/// Core slice alone (no AppKit, no IOKit), so they run anywhere.
@main
struct LogicTests {
    static var failures = 0

    static func main() {
        pixelSequence()
        toneMath()
        keyboardLayout()
        batteryReport()
        reportBuilder()

        if failures == 0 {
            print("All logic checks passed.")
        } else {
            print("\(failures) check(s) FAILED.")
            exit(1)
        }
    }

    // MARK: - Pixel sequence

    static func pixelSequence() {
        check("nine standard colours", PixelSequence.standard.count == 9)
        check("first colour is red", PixelSequence.color(at: 0).name == "Red")
        check("last colour is black", PixelSequence.color(at: 8).name == "Black")
        check("wraps forward", PixelSequence.color(at: 9).name == "Red")
        check("wraps backward", PixelSequence.color(at: -1).name == "Black")
        check("nextIndex wraps", PixelSequence.nextIndex(after: 8) == 0)
        check("nextIndex advances", PixelSequence.nextIndex(after: 0) == 1)

        let white = PixelSequence.standard.first { $0.name == "White" }!
        check("white is (1,1,1)", white.red == 1 && white.green == 1 && white.blue == 1)
    }

    // MARK: - Tone maths

    static func toneMath() {
        let sweep = ToneMath.sweepFrequencies(steps: 3)
        check("sweep has three points", sweep.count == 3)
        check("sweep starts at 20 Hz", nearly(sweep.first!, 20))
        check("sweep ends at 20 kHz", nearly(sweep.last!, 20_000))
        check("sweep midpoint is geometric", nearly(sweep[1], 20 * pow(1000, 0.5)))

        check("sweep clamps below two points", ToneMath.sweepFrequencies(steps: 1).count == 2)

        let left = ToneMath.gains(for: .left)
        check("left channel silences right", left.left == 1 && left.right == 0)
        let both = ToneMath.gains(for: .both)
        check("both channels equal", both.left == 1 && both.right == 1)

        check("envelope starts silent", ToneMath.edgeEnvelope(sampleIndex: 0, totalSamples: 100, fadeSamples: 10) == 0)
        check("envelope body is full", ToneMath.edgeEnvelope(sampleIndex: 50, totalSamples: 100, fadeSamples: 10) == 1)
        check("envelope ends silent", ToneMath.edgeEnvelope(sampleIndex: 100, totalSamples: 100, fadeSamples: 10) == 0)

        check("0 dB is unity gain", nearly(ToneMath.decibelsToGain(0), 1))
        check("unity gain is 0 dB", nearly(ToneMath.gainToDecibels(1), 0))
        check("6 dB is about 2x", nearly(ToneMath.decibelsToGain(6), 1.9953, tolerance: 0.001))
    }

    // MARK: - Keyboard layout

    static func keyboardLayout() {
        let rowsTotal = KeyboardLayout.rows.reduce(0) { $0 + $1.count }
        check("allKeys matches the rows", KeyboardLayout.allKeys.count == rowsTotal)
        check("five rows", KeyboardLayout.rows.count == 5)
        check("space is labelled", KeyboardLayout.label(for: 49) == "space")
        check("return is labelled", KeyboardLayout.label(for: 36) == "⏎")
        check("unknown code has no label", KeyboardLayout.label(for: 500) == nil)

        let codes = KeyboardLayout.uniqueCodes
        check("unique codes are de-duplicated", Set(codes).count == codes.count)
        check("command appears once despite two caps", codes.filter { $0 == 55 }.count == 1)
        check("shift appears once despite two caps", codes.filter { $0 == 56 }.count == 1)
        check("every key has a width", KeyboardLayout.allKeys.allSatisfy { $0.width > 0 })
    }

    // MARK: - Battery report

    static func batteryReport() {
        var snapshot = BatterySnapshot()
        snapshot.cycleCount = 241
        snapshot.designCapacity = 4629
        snapshot.fullChargeCapacity = 4184
        snapshot.currentCapacityPercent = 27
        snapshot.temperatureCelsius = 31.5
        snapshot.isPluggedIn = false
        snapshot.isCharging = false
        snapshot.timeRemainingMinutes = 119

        let health = snapshot.healthPercent!
        check("health is about 90.4%", nearly(health, 90.4, tolerance: 0.1))
        check("90%+ reads Excellent", snapshot.healthVerdict == "Excellent")

        check("80% reads Serviceable", BatterySnapshot(designCapacity: 100, fullChargeCapacity: 85).healthVerdict == "Serviceable")
        check("below 80% recommends service", BatterySnapshot(designCapacity: 100, fullChargeCapacity: 70).healthVerdict == "Service recommended")
        check("no capacity means unknown health", BatterySnapshot().healthPercent == nil)
        check("zero design capacity is guarded", BatterySnapshot(designCapacity: 0, fullChargeCapacity: 100).healthPercent == nil)

        let lines = BatteryReport.lines(for: snapshot)
        check("report shows cycle count", lines.contains("Cycle count: 241"))
        check("report shows health", lines.contains { $0.hasPrefix("Health: 90.4%") })
        check("report shows capacity", lines.contains("Capacity: 4184 mAh of 4629 mAh design"))
        check("report shows charge", lines.contains("Current charge: 27%"))
        check("report shows power state", lines.contains("Power: on battery"))
        check("report shows time", lines.contains("Time remaining: 1h 59m"))

        check("cycle verdict text", BatteryReport.cycleVerdict(cycleCount: 241).hasPrefix("24%"))
    }

    // MARK: - Report builder and progress codec

    static func reportBuilder() {
        let results = [
            CheckResult(id: "display", title: "Display", status: .pass, note: "clean"),
            CheckResult(id: "speakers", title: "Speakers", status: .fail, note: "buzz | rattle"),
            CheckResult(id: "camera", title: "Camera"),
        ]
        let tally = ReportBuilder.counts(results)
        check("counts passes", tally.passed == 1)
        check("counts failures", tally.failed == 1)
        check("counts untested", tally.untested == 1)
        check("headline names failures", ReportBuilder.headline(results) == "1 check failed")
        check("all-pass headline", ReportBuilder.headline([CheckResult(id: "a", title: "A", status: .pass)]) == "All checks passed")

        let markdown = ReportBuilder.markdown(machine: .unknown, results: results, date: Date(timeIntervalSince1970: 0))
        check("markdown has a table", markdown.contains("| Check | Result | Notes |"))
        check("markdown escapes pipes", markdown.contains("buzz \\| rattle"))
        check("markdown lists a row", markdown.contains("| Speakers | Fail |"))
        check("markdown includes the model", markdown.contains("Unknown Mac"))
        check("markdown includes the date", markdown.contains("1970-01-01"))

        let data = ProgressCodec.encode(results)
        let decoded = ProgressCodec.decode(data)
        check("codec round-trips", decoded == results)

        let catalog = [
            CheckResult(id: "display", title: "Display"),
            CheckResult(id: "newcheck", title: "New check"),
        ]
        let merged = ProgressCodec.merge(stored: results, catalog: catalog)
        check("merge keeps known status", merged.first?.status == .pass)
        check("merge keeps known note", merged.first?.note == "clean")
        check("merge drops removed checks", merged.count == 2)
        check("merge appends new checks", merged.last?.status == .untested)
    }

    // MARK: - Helpers

    static func nearly(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
        abs(a - b) <= tolerance
    }

    static func check(_ name: String, _ condition: Bool) {
        if condition {
            print("  ok  \(name)")
        } else {
            print("FAIL  \(name)")
            failures += 1
        }
    }
}
