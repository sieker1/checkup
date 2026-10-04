import Foundation

/// A mounted volume that could be a USB stick, SD card, disk image or the
/// internal SSD.
struct MountedVolume: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let totalBytes: Int64
    let freeBytes: Int64
    let isRemovable: Bool
    let isInternal: Bool
    let isReadOnly: Bool
}

enum VolumeLister {
    static func mounted() -> [MountedVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return MountedVolume(
                id: url.path,
                name: values.volumeName ?? url.lastPathComponent,
                path: url.path,
                totalBytes: Int64(values.volumeTotalCapacity ?? 0),
                freeBytes: Int64(values.volumeAvailableCapacity ?? 0),
                isRemovable: values.volumeIsRemovable ?? false,
                isInternal: values.volumeIsInternal ?? false,
                isReadOnly: values.volumeIsReadOnly ?? false
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
