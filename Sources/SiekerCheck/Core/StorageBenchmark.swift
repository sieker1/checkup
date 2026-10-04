import Foundation

/// Measures sequential write/read throughput by creating a temporary file,
/// writing a pattern into it, reading it back, then removing it.
enum StorageBenchmark {
    struct Result: Equatable {
        let megabytes: Int
        let writeMBps: Double
        let readMBps: Double
        let verified: Bool
    }

    /// Runs the benchmark in `directory`, defaulting to a SiekerCheck folder in
    /// the temporary directory. Returns nil if the file could not be written.
    static func run(megabytes: Int = 64, in directory: URL? = nil) -> Result? {
        let target = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("SiekerCheck", isDirectory: true)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let file = target.appendingPathComponent("speedtest.bin")
        let byteCount = max(1, megabytes) * 1_000_000

        // A repeating pattern (not all zeros) makes the read-back verification
        // meaningful and avoids a degenerate file that compresses trivially.
        var payload = Data(count: byteCount)
        payload.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for index in 0..<byteCount { base[index] = UInt8(index & 0xFF) }
        }

        let writeStart = Date()
        do {
            try payload.write(to: file)
        } catch {
            return nil
        }
        let writeSeconds = max(Date().timeIntervalSince(writeStart), 0.000_001)

        let readStart = Date()
        let readBack = (try? Data(contentsOf: file)) ?? Data()
        let readSeconds = max(Date().timeIntervalSince(readStart), 0.000_001)

        try? FileManager.default.removeItem(at: file)

        let size = Double(megabytes)
        return Result(
            megabytes: megabytes,
            writeMBps: size / writeSeconds,
            readMBps: size / readSeconds,
            verified: readBack.count == byteCount && readBack == payload
        )
    }
}
