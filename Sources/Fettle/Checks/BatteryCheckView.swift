import SwiftUI

struct BatteryCheckView: View {
    @State private var snapshot: BatterySnapshot?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Battery health") {
                    if let snapshot {
                        ForEach(BatteryReport.lines(for: snapshot), id: \.self) { line in
                            Text(line)
                        }
                        if let cycles = snapshot.cycleCount {
                            Text(BatteryReport.cycleVerdict(cycleCount: cycles))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if loaded {
                        Text("This Mac reports no battery — it may be a desktop or running on AC with the battery removed.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Reading…").foregroundStyle(.secondary)
                    }

                    Button("Refresh") { load() }
                }

                CheckSection(title: "What to look for") {
                    bullet("Health below 80% is Apple's own “service recommended” threshold.")
                    bullet("A cycle count far above 1000 means the battery is beyond its design life.")
                    bullet("The charge percentage should rise when plugged in and fall when unplugged.")
                }

                CheckOutcomeControls(module: .battery)
            }
            .padding(20)
        }
        .onAppear { load() }
    }

    private func load() {
        snapshot = BatteryReader.read()
        loaded = true
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 8)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
