import SwiftUI

struct StorageCheckView: View {
    @State private var volumes: [MountedVolume] = []
    @State private var result: StorageBenchmark.Result?
    @State private var running = false
    @State private var message = "Write a temporary file to measure read/write speed, then delete it."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CheckSection(title: "Mounted volumes") {
                    Text("Plug in a USB stick or SD card and press Refresh — it should appear here. "
                         + "That confirms the port, the reader and the cable all work.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if volumes.isEmpty {
                        Text("No volumes reported.").foregroundStyle(.secondary)
                    } else {
                        ForEach(volumes) { volume in
                            HStack {
                                Image(systemName: volume.isRemovable ? "sdcard" : "internaldrive")
                                    .foregroundStyle(volume.isRemovable ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(volume.name).fontWeight(.medium)
                                    Text(volume.path).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(SystemInfo.formatBytes(volume.freeBytes)) free of \(SystemInfo.formatBytes(volume.totalBytes))")
                                        .font(.caption)
                                    Text(volume.isReadOnly ? "read-only" : "read/write")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button("Refresh volumes") { refresh() }
                }

                CheckSection(title: "Storage speed") {
                    HStack(spacing: 10) {
                        Button(running ? "Testing…" : "Run 64 MB test") { run() }
                            .buttonStyle(.borderedProminent)
                            .disabled(running)
                        if running { ProgressView().controlSize(.small) }
                    }

                    if let result {
                        LabeledContent("Write", value: String(format: "%.0f MB/s", result.writeMBps))
                        LabeledContent("Read", value: String(format: "%.0f MB/s", result.readMBps))
                        LabeledContent("File size", value: "\(result.megabytes) MB")
                        Label("Data verified byte-for-byte on read-back", systemImage: result.verified ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(result.verified ? .green : .red)
                            .font(.caption)
                    }

                    Text(message).font(.caption).foregroundStyle(.secondary)
                }

                CheckOutcomeControls(module: .storage)
            }
            .padding(20)
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        volumes = VolumeLister.mounted()
    }

    private func run() {
        running = true
        message = "Writing and reading 64 MB…"
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                StorageBenchmark.run(megabytes: 64)
            }.value
            result = outcome
            running = false
            message = outcome == nil
                ? "The test file could not be written to the temporary directory."
                : "Done. The temporary file was removed."
        }
    }
}
